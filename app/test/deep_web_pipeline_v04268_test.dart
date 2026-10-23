import 'package:ai_companion_localfirst/core/stickers/sticker_expression_service.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_reply_choice.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/storage/media_storage_optimizer.dart';
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
  for (final scenario in ['none', 'with_text', 'only', 'failed_asset']) {
  for (final deep in [false, true]) {
    final realMedia = scenario == 'with_text' && !deep;
    test(
      'real reply pipeline: deep=$deep expression=$scenario realMedia=$realMedia plans only when enabled, Gemini writes once',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'deep-web-pipeline-',
        );
        final paths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(root.path);
        final db = await AppDatabase.createForTesting(databaseFactoryFfi);
        FlutterSecureStorage.setMockInitialValues({
          'deepseek_api_key': 'test',
          'chat_api_provider': 'aiwangyou_gemini',
          'aiwangyou_gemini_api_key': 'test-final',
          'aiwangyou_final_reply_endpoint':
              'https://relay.invalid/v1/chat/completions',
        });
        final secure = SecureConfig.forTesting(const FlutterSecureStorage());
        final cancellation = GenerationCancellationToken();
        var plans = 0;
        var finals = 0;
        http.Response sse(String text) => http.Response.bytes(
          utf8.encode(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': text},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\ndata: [DONE]\n\n',
          ),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
        final client = DeepSeekClient(
          streamClientFactory: () => MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            if ((body['tools'] as List?)?.any((t) => ((t as Map)['function'] as Map)['name'] != 'agent_request') == true) {
              plans++;
              expect(request.url.host, isNot('relay.invalid'));
              return sse('现有上下文足够，无需工具。');
            }
            if (request.url.host == 'relay.invalid') {
              finals++;
              return sse('「嗯，我在听。」\n<sticker_choice>${scenario == 'none' ? 'none' : '${scenario == 'failed_asset' ? 'only' : scenario}:s1'}</sticker_choice>');
            }
            return sse('{}');
          }),
          jsonClientFactory: () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '{}'},
                  },
                ],
              }),
              200,
            ),
          ),
        );
        try {
          await db.setSetting('nsfw_route_turn_id', 'user');
          await db.tryAcquireLocalLease('chat_turn_lease');
          final job = await db.createGenerationTurn(
            user: ChatMessage(
              id: 'user',
              role: 'user',
              content: '今天心情不错',
              createdAt: DateTime.now(),
            ),
            assistantMessageId: 'reply',
            model: 'deepseek-flash',
            reasoningEffort: 'high',
            deepThinking: deep,
          );
          final result =
              await DurableGenerationRunner(
                    db: db,
                    client: client,
                    secureConfig: secure,
                    stickerService: _Stickers(db, scenario, preparedRoot: realMedia ? root : null),
                  )
                  .run(job, cancellationToken: cancellation)
                  .timeout(const Duration(seconds: 20));
          expect(result.status, 'completed', reason: '${result.error}');
          final reply = (await db.messageById('reply'))!;
          expect(reply.content, scenario == 'only' ? '' : '「嗯，我在听。」');
          expect(reply.attachments.length, ['only', 'with_text'].contains(scenario) ? 1 : 0);
          expect(plans, deep ? 1 : 0);
          expect(finals, 1);
          if (realMedia) {
            final attachment = reply.attachments.single;
            expect(attachment.blobId, isNotEmpty);
            expect((await (await db.database).query('pending_media_owners')), isEmpty);
            expect((await db.mediaBlobById(attachment.blobId))!.messageRefCount, 1);
            await MediaStorageOptimizer(db: db).optimize();
            expect(await (await MessageAttachmentStorage(db: db)
              .fileFor(attachment.originalPath)).exists(), isTrue);
          }
          expect(
            (await db.messageById('reply'))!.content,
            isNot(contains('无需工具')),
          );
        } finally {
          cancellation.cancel();
          client.close();
          await db.releaseLocalLease('chat_turn_lease');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await db.closeForTesting();
          PathProviderPlatform.instance = paths;
          await root.delete(recursive: true);
        }
      },
    );
  }
}
}

class _Stickers extends StickerExpressionService {
  _Stickers(AppDatabase db, this.scenario, {this.preparedRoot}) : super(db: db);
  final String scenario;
  final Directory? preparedRoot;
  static const pack = StickerPackMeta(id: 'test', name: 'test', description: '', license: '', rootPath: '', count: 1);
  static const record = StickerRecord(packId: 'test', path: 'smile.png', tag: 'happy', caption: '微笑着听对方说话', keywords: '听 开心', toneScope: 'general', intensity: 1, enabled: true);
  @override
  Future<List<StickerReplyCandidate>> replyCandidates({required String seed, required String context,
    bool eligible = true, bool allowBold = false, DateTime? now}) async => [const StickerReplyCandidate('s1', pack, record)];
  @override
  Future<SelectedStickerAttachment?> prepareReplyChoice({required String messageId,
    required StickerReplyChoice choice, required List<StickerReplyCandidate> candidates,
    PendingMediaOwner? pendingOwner}) async {
    if (scenario == 'failed_asset') throw const FileSystemException('missing asset');
    if (choice.mode == 'none') return null;
    final root = preparedRoot;
    if (root != null) {
      // Only asset selection/preprocessing is faked. The real runner supplies
      // the original attempt, and production storage + GC + terminal commit
      // must transfer its pending pin into the saved message reference.
      expect(pendingOwner, isNotNull);
      final dir = await Directory('${root.path}/prepared-sticker').create();
      final original = await File('${dir.path}/original.png').writeAsString('prepared-original');
      final thumbnail = await File('${dir.path}/thumbnail.png').writeAsString('prepared-thumbnail');
      final attachment = await attachmentStorage.commitDraft(PreparedImageAttachment(
        id: 'prepared-sticker', originalFile: original, thumbnailFile: thumbnail,
        originalExtension: '.png', mimeType: 'image/png', byteSize: 17, width: 1, height: 1,
        source: 'assistant_sticker:test', createdAt: DateTime.now()),
        messageId: messageId, pendingOwner: pendingOwner);
      expect((await (await db.database).query('pending_media_owners')).length, 1);
      await MediaStorageOptimizer(db: db).optimize();
      expect(await (await attachmentStorage.fileFor(attachment.originalPath)).exists(), isTrue);
      return SelectedStickerAttachment(record: record, attachment: attachment);
    }
    return SelectedStickerAttachment(record: record, attachment: MessageAttachment(
      id: 'a', messageId: messageId, kind: 'image', originalPath: '', thumbnailPath: '',
      mimeType: 'image/png', byteSize: 1, width: 1, height: 1, createdAt: DateTime.now(), source: 'assistant_sticker:test'));
  }
}
