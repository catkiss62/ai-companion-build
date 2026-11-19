import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_client.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_job.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_prompt.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_worker.dart';
import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await (await db.database).execute('PRAGMA foreign_keys = ON');
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture'});
  });
  tearDown(() => db.closeForTesting());

  ChatMessage message(String role, String text) => ChatMessage(
    id: role == 'user' ? 'user' : 'reply',
    role: role,
    content: text,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      role == 'user' ? 1000 : 2000,
    ),
  );
  Future<String> start() async => (await db.createGenerationTurn(
    user: message('user', '测试'),
    assistantMessageId: 'reply',
    model: 'deepseek-flash',
    reasoningEffort: 'high',
  )).id;
  Future<ChatMessage> complete(
    String jobId,
    String text, {
    IllustrationJob? illustration,
  }) async {
    final job = (await db.claimGenerationJob(jobId))!;
    expect(
      await db.completeGenerationJobIfCurrent(
        jobId: jobId,
        runToken: job.runToken,
        assistant: message('assistant', text),
        illustration: illustration,
      ),
      isTrue,
    );
    return (await db.messageById('reply'))!;
  }

  http.Response translation(String text) => http.Response(
    jsonEncode({
      'choices': [
        {
          'finish_reason': 'stop',
          'message': {
            'content': jsonEncode({
              'segments': [
                {'kind': 'dialogue', 'text': text},
              ],
            }),
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'old vision success and failure cannot change a restored or reclaimed analyzing row',
    () async {
      final user = message('user', '图片');
      final image = MessageAttachment(
        id: 'image',
        messageId: user.id,
        kind: 'image',
        originalPath: 'original.png',
        thumbnailPath: 'thumb.png',
        mimeType: 'image/png',
        byteSize: 4,
        width: 1,
        height: 1,
        source: 'gallery',
        createdAt: user.createdAt,
      );
      await db.insertMessageWithAttachments(user, [image]);
      const lease = 'image_vision_lease';
      Future<BrainWorkFence> claim() async {
        expect(await db.tryAcquireLocalLease(lease), isTrue);
        final fence = (await db.captureBrainWorkFence(leaseKey: lease))!;
        expect(
          await db.markAttachmentVisionAnalyzing('image', fence: fence),
          isTrue,
        );
        return fence;
      }

      final old = await claim();
      await db.setSetting('runtime_state_epoch_v1', 'restored');
      await db.failAttachmentVision('image', 'old epoch', fence: old);
      expect(
        (await db.messageById(user.id))!.attachments.single.visionStatus,
        'analyzing',
      );
      await db.releaseLocalLease(lease);
      final next = await claim();
      await db.releaseLocalLease(lease);
      final current = await claim();
      await db.failAttachmentVision('image', 'old attempt', fence: next);
      await expectLater(
        db.completeAttachmentVisionAndCreateGeneration(
          attachmentId: 'image',
          summary: 'stale',
          visionModel: 'fixture',
          assistantMessageId: 'reply',
          model: 'fixture',
          reasoningEffort: 'high',
          visionFence: next,
        ),
        throwsA(isA<BrainWorkInvalidated>()),
      );
      expect(
        (await db.messageById(user.id))!.attachments.single.visionStatus,
        'analyzing',
      );
      await db.failAttachmentVision('image', 'current failure', fence: current);
      expect(
        (await db.messageById(user.id))!.attachments.single.visionError,
        'current failure',
      );
      await db.releaseLocalLease(lease);
    },
  );

  test('temporary regenerate hint expires without clearing an important notice', () async {
    final chat = ChatController(db:db);
    addTearDown(chat.dispose);
    chat.notice = '第三通道错误';
    await chat.regenerateLatestReply(message('assistant','旧回复'));
    expect(chat.temporaryHint, contains('只能重新生成'));
    await Future<void>.delayed(const Duration(milliseconds:2100));
    await chat.regenerateLatestReply(message('assistant','旧回复'));
    chat.error = 'API Key 已失效';
    await Future<void>.delayed(const Duration(milliseconds:2100));
    expect(chat.temporaryHint,isNotNull);
    await Future<void>.delayed(const Duration(milliseconds:2100));
    expect(chat.temporaryHint,isNull);
    expect(chat.error,'API Key 已失效');
    expect(chat.notice,'第三通道错误');
  });

  for (final restore in [false, true]) {
    test(
      'out-of-order translations preserve the current bubble and database (restore=$restore)',
      () async {
        final job = await start();
        final old = await complete(job, '「旧正文」');
        final began = Completer<void>(), finish = Completer<void>();
        var calls = 0;
        final client = DeepSeekClient(
          client: MockClient((_) async {
            if (++calls == 1) {
              began.complete();
              await finish.future;
              return translation('Old wording.');
            }
            return translation('Current wording.');
          }),
        );
        final chat = ChatController(db: db, client: client);
        addTearDown(chat.dispose);
        chat.messages = [old];
        final lateResult = expectLater(
          chat.ensureLanguageVariant(old, ChatLanguage.english),
          throwsA(isA<BrainWorkInvalidated>()),
        );
        await began.future;
        if (restore) {
          await db.setSetting('runtime_state_epoch_v1', 'restored');
        } else {
          expect(await db.restartLatestCompletedReply(old.id), isNotNull);
          await complete(job, '「新正文」');
        }
        final current = (await db.messageById(old.id))!;
        chat.messages = [current];
        final result = await chat.ensureLanguageVariant(
          current,
          ChatLanguage.english,
        );
        finish.complete();
        await lateResult;
        expect(calls, 2);
        for (final m in [
          result,
          chat.messages.single,
          (await db.messageById(old.id))!,
        ]) {
          expect(m.content, current.content);
          expect(
            m.contentFor(ChatLanguage.english),
            contains('Current wording.'),
          );
        }
      },
    );
  }

  test('an empty overlay replay releases its claim and preserves the preferred language', () async {
    const channel = MethodChannel('ai_companion/tts');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'claimPlayback' ? 7 : null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await db.setSetting('tts_language', 'en');
    final chat = ChatController(db: db);
    addTearDown(chat.dispose);
    final before = chat.ttsPlayback.generation;
    await chat.speakMessage(ChatMessage(id:'empty',role:'assistant',content:'',createdAt:DateTime.now()),
      rememberLanguage: false);
    // One generation for the claim, one to release it without playing.
    expect(chat.ttsPlayback.generation, before + 2);
    expect(await db.getSetting('tts_language'), 'en');
  });

  test('cached foreign speech cannot replay a superseded reply', () async {
    final id = await start();
    final old = await complete(id, '「旧正文」');
    var calls = 0;
    final chat = ChatController(
      db: db,
      client: DeepSeekClient(
        client: MockClient((_) async {
          calls++;
          return translation('Old wording.');
        }),
      ),
    );
    addTearDown(chat.dispose);
    final cached = await chat.ensureLanguageVariant(old, ChatLanguage.english);
    expect(await db.restartLatestCompletedReply(old.id), isNotNull);
    await complete(id, '「新正文」');
    final active = chat.ttsPlayback.createIntent(ownerId: 'new-reply');
    await chat.speakMessage(cached, language: ChatLanguage.english);
    expect(active.valid, isTrue);
    expect(await db.getSetting('tts_language'), isNot('en'));
    expect(calls, 1);
  });

  test(
    'current draft keeps its translation across refresh and drops it on restore',
    () async {
      const channel = MethodChannel('ai_companion/tts');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var claims = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'claimPlayback') return ++claims;
        if (call.method == 'generate') return Uint8List.fromList([1, 2, 3]);
        if (const {
          'initialize',
          'prepareLanguage',
          'configureAutoAffinity',
          'status',
        }.contains(call.method)) {
          return {
            'available': true,
            'initialized': true,
            'autoAffinityEnabled': true,
          };
        }
        if (const {
          'beginAudioStream',
          'enqueueAudio',
          'finishAudioStream',
        }.contains(call.method))
          return true;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final id = await start();
      await complete(id, '「上一版」');
      final reopened = (await db.restartLatestCompletedReply('reply'))!;
      final job = (await db.claimGenerationJob(reopened.id))!;
      await db.holdGenerationJobForUserDecision(
        id,
        runToken: job.runToken,
        partialReasoning: '',
        partialContent: '「新版草稿」',
      );
      var translations = 0;
      final chat = ChatController(
        db: db,
        client: DeepSeekClient(
          client: MockClient((_) async {
            translations++;
            return translation('Current draft.');
          }),
        ),
      );
      addTearDown(chat.dispose);
      await chat.syncExternalMessages();
      final draft = chat.incompleteReplyDraft!;
      expect(draft.sourceRevision, job.assistantSourceRevision);
      expect(draft.sourceRevision, greaterThan(0));
      await chat.speakMessage(draft, language: ChatLanguage.english);
      await chat.syncExternalMessages();
      expect(
        chat.incompleteReplyDraft!.contentFor(ChatLanguage.english),
        contains('Current draft.'),
      );
      await chat.speakMessage(
        chat.incompleteReplyDraft!,
        language: ChatLanguage.english,
      );
      expect(translations, 1);
      expect(await db.messageById(draft.id), isNull);
      await chat.ttsPlayback.stop();
      await db.setSetting('runtime_state_epoch_v1', 'restored');
      await chat.syncExternalMessages();
      expect(chat.incompleteReplyDraft!.languageVariants, isEmpty);
    },
  );

  test(
    'a discarded draft cannot be restored by its late spoken translation',
    () async {
      final job = (await db.claimGenerationJob(await start()))!;
      await db.holdGenerationJobForUserDecision(
        job.id,
        runToken: job.runToken,
        partialReasoning: '',
        partialContent: '「等待确认」',
      );
      final began = Completer<void>(), finish = Completer<void>();
      final chat = ChatController(
        db: db,
        client: DeepSeekClient(
          client: MockClient((_) async {
            began.complete();
            await finish.future;
            return translation('Late draft.');
          }),
        ),
      );
      addTearDown(chat.dispose);
      final draft = message('assistant', '「等待确认」');
      chat.incompleteReplyDraft = draft;
      chat.incompleteReplyJobId = job.id;
      final pending = chat.speakMessage(draft, language: ChatLanguage.english);
      await began.future;
      expect(await db.restartGenerationDraft(job.id), isTrue);
      chat.incompleteReplyDraft = null;
      chat.incompleteReplyJobId = null;
      finish.complete();
      await pending;
      expect(chat.incompleteReplyDraft, isNull);
      expect(await db.messageById(draft.id), isNull);
      expect(await db.getSetting('tts_language'), isNot('en'));
    },
  );

  test(
    'regeneration fences a dispatched image and preserves completed album owners',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'reply-revision-image-',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(temp.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previous;
        await temp.delete(recursive: true);
      });
      await SecureConfig.instance.writeIllustration(
        const IllustrationConnection(
          enabled: true,
          baseUrl: 'https://fixture.invalid',
          apiKey: 'fixture',
        ),
      );
      final started = Completer<void>(), finish = Completer<void>();
      var calls = 0;
      final worker = IllustrationWorker(
        db,
        client: IllustrationClient(
          clientFactory: () => MockClient((_) async {
            final n = ++calls;
            if (n == 1) {
              started.complete();
              await finish.future;
            }
            // Two valid solid-color images give each committed revision its own blob.
            final png = base64Decode(
              n == 3
                  ? 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAFElEQVR4nGNkYPjPAANMDEgANwcAMdMBB1sLEtoAAAAASUVORK5CYII='
                  : 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGP8z4AATAxEcQAz0QEHOoQ+uAAAAABJRU5ErkJggg==',
            );
            final archive = Archive()
              ..addFile(ArchiveFile('image.png', png.length, png));
            return http.Response.bytes(ZipEncoder().encode(archive), 200);
          }),
        ),
      );
      const draw = IllustrationJob(
        source: IllustrationSource.chat,
        ownerId: 'reply',
        intent: '测试',
        plan: IllustrationPlan(
          style: 'cute',
          scene: 'window',
          outfit: 'coat',
          camera: 'wide',
          description: '图',
        ),
      );
      final id = await start();
      await complete(id, '「第一版」', illustration: draw);
      final old = worker.drainOne();
      await started.future;
      expect(await db.restartLatestCompletedReply('reply'), isNotNull);
      expect(await db.getSetting(draw.key), isNull);
      await complete(id, '「第二版」', illustration: draw);
      final admission = await db.getSetting(draw.key);
      finish.complete();
      await old;
      expect(await db.getSetting(draw.key), admission);
      expect(await db.companionAlbumItems(), isEmpty);
      await worker.drainOne();
      final second = (await db.companionAlbumItems()).single;
      expect(
        (await db.messageById('reply'))!.attachments.single.blobId,
        second.blobId,
      );
      expect(await db.restartLatestCompletedReply('reply'), isNotNull);
      await complete(id, '「第三版」', illustration: draw);
      await worker.drainOne();
      final third = (await db.messageById('reply'))!.attachments.single.blobId;
      expect(third, isNot(second.blobId));
      expect(
        (await db.companionAlbumItems()).map((i) => i.blobId),
        unorderedEquals([second.blobId, third]),
      );
      expect(await db.restartLatestCompletedReply('reply'), isNotNull);
      await complete(id, '「这次不用配图」');
      expect(await db.getSetting(draw.key), isNull);
      expect((await db.messageById('reply'))!.attachments, isEmpty);
      expect(calls, 3);
    },
  );
}
