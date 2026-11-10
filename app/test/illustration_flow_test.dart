import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_client.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_cue.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_job.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_prompt.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_worker.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/companion_album.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/companion_album_storage.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:archive/archive.dart';
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

const _plan = IllustrationPlan(
  style: 'cute',
  scene: 'at a rainy window, holding a cup',
  outfit: 'yellow raincoat',
  camera: 'medium shot, from above',
  description: '雨天窗边的插画',
);

Future<void> _expectAgentCanInspect(
  AppDatabase db,
  CompanionAlbumItem album,
) async {
  final sql = await db.database;
  final savedAt = album.savedAt!.millisecondsSinceEpoch;
  for (final fixture in [
    ('older-generated', 'saved', 0, -1000, 'generated'),
    ('newer-unrelated', 'saved', 0, 1000, 'landscape'),
    ('recent-deleted', 'soft_deleted', 0, 2000, 'generated'),
    ('recent-hidden', 'saved', 1, 3000, 'generated'),
  ]) {
    await sql.insert('companion_album_candidates', {
      'id': fixture.$1,
      'source_kind': 'fixture',
      'source_id': fixture.$1,
      'title': fixture.$1,
      'lifecycle_state': fixture.$2,
      'nsfw': fixture.$3,
      'created_at': savedAt + fixture.$4,
      'saved_at': savedAt + fixture.$4,
      'updated_at': savedAt + fixture.$4,
      'user_tags_json': jsonEncode([fixture.$5]),
    });
  }
  final runner = AgentToolRunner(db: db, android: AndroidBridge.instance);
  Future<AgentToolResult> run(String id, Map<String, String> arguments) async =>
      (await runner.runPlan(
        AgentToolPlan(
          calls: [
            AgentToolCall(
              toolId: id,
              arguments: arguments,
              reasonTag: 'model_selected',
            ),
          ],
        ),
      )).single;
  final listed = await run('album.search', {
    'order': 'latest',
    'tag': 'generated',
  });
  final handle = 'phone:album:${album.id}';
  expect(listed.resultCount, 2);
  expect(listed.promptData, contains('creation_intent'));
  expect(listed.promptData, isNot(contains('recent-deleted')));
  expect(listed.promptData.indexOf(handle), greaterThanOrEqualTo(0));
  expect(
    listed.promptData.indexOf(handle),
    lessThan(listed.promptData.indexOf('older-generated')),
  );
  final thumbnail = await CompanionAlbumStorage(
    db: db,
  ).fileFor(album.thumbnailPath);
  final thumbnailBytes = await thumbnail.readAsBytes();
  var calls = 0;
  await http.runWithClient(
    () async {
      for (final target in [
        {'selection': 'latest', 'tag': 'generated'},
        {'handle': handle},
      ]) {
        final observed = await run('album.inspect', target);
        expect(
          observed.status,
          AgentToolStatus.succeeded,
          reason: observed.errorCode,
        );
        expect(observed.promptData, contains(handle));
        expect(observed.promptData, contains('白色方块'));
        expect(observed.promptData, isNot(contains(_plan.description)));
        expect(observed.attachments, isEmpty);
      }
      for (final id in ['recent-deleted', 'recent-hidden', 'older-generated']) {
        final unavailable = await run('album.inspect', {
          'handle': 'phone:album:$id',
        });
        expect(unavailable.status, AgentToolStatus.noResult);
      }
    },
    () => MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map;
      final user = (body['messages'] as List).last as Map;
      final image = (user['content'] as List).first as Map;
      expect(
        (image['image_url'] as Map)['url'],
        'data:image/png;base64,${base64Encode(thumbnailBytes)}',
      );
      expect(request.body, isNot(contains(_plan.description)));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({'summary': '画面里是白色方块'}),
              },
              'finish_reason': 'stop',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  expect(calls, 2);
  expect(await db.allMediaBlobs(), hasLength(1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('free camera and outfit override old framing without losing style', () {
    final prompt = IllustrationPrompt.compose(_plan);
    expect(prompt.positive, contains('artist:fuzichoco'));
    expect(prompt.positive, contains('1.5::artist:chen_bin::'));
    expect(prompt.positive, contains('yellow raincoat'));
    expect(prompt.positive, endsWith('medium shot, from above'));
    expect(prompt.positive, isNot(contains('close-up')));
    expect(prompt.positive, isNot(contains('full body')));
    expect(prompt.positive, isNot(contains('maid dress')));
    expect(prompt.positive, contains('cetacean tail'));
    expect(prompt.negative, contains('nsfw'));
    expect(IllustrationCue.visible('好呀<illust'), '好呀');
    expect(IllustrationCue.visible('好呀<illustrate>一杯茶</illustrate>'), '好呀');
    expect(IllustrationCue.explicitRequest('别画一张了'), isFalse);
    expect(IllustrationCue.explicitRequest('给我画一张海边'), isTrue);
  });

  test(
    'explicit album visit exposes inspection if semantic routing missed it',
    () {
      final definitions = AgentToolPlanner.nativeToolDefinitionsFor(
        '笨，去相册看嘛',
        semanticReadAuthoritative: true,
      );
      final names = definitions.map(
        (entry) => (entry['function'] as Map)['name'],
      );
      expect(names, containsAll(['album_search', 'album_inspect']));
      expect(names, isNot(contains('album_image_send')));
      expect(AgentToolPlanner.nativeToolDefinitionsFor('抱抱我'), isEmpty);
      expect(AgentToolPlanner.nativeToolDefinitionsFor('不要去相册看'), isEmpty);
    },
  );

  test(
    'self-image tag depends on identity independently of style or outfit',
    () {
      expect(_plan.depictsCompanion, isTrue);
      final data = _plan.toJson();
      for (final (fields, expected) in [
        ({'style': 'free', 'subject': 'self'}, true),
        ({'style': 'free', 'subject': 'other'}, false),
        ({'subject': 'unknown'}, false),
        ({'appearance': 'red hair'}, false),
      ]) {
        expect(
          IllustrationPlan.fromJson({...data, ...fields})!.depictsCompanion,
          expected,
        );
      }
    },
  );

  test(
    'chat and diary share bytes after one retry, and diary pins them',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'illustration-flow-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'vision-fixture',
      });
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      try {
        await SecureConfig.instance.writeIllustration(
          const IllustrationConnection(
            baseUrl: 'https://illustration.invalid',
            apiKey: 'fixture',
            enabled: true,
            diary: true,
          ),
        );
        final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8//8/AwMDEwMDAwMDAwAkBgMB/DXemwAAAABJRU5ErkJggg==',
        );
        final archive = Archive()
          ..addFile(ArchiveFile('picture.png', png.length, png));
        final zipped = ZipEncoder().encode(archive);
        final seeds = <Object?>[];
        var alwaysFail = false;
        final worker = IllustrationWorker(
          db,
          client: IllustrationClient(
            clientFactory: () => MockClient((request) async {
              expect(request.url.path, '/ai/generate-image');
              expect(request.headers['authorization'], 'Bearer fixture');
              final body = jsonDecode(request.body) as Map;
              final parameters = body['parameters'] as Map;
              expect(parameters['n_samples'], 1);
              expect(body['input'], contains('medium shot, from above'));
              seeds.add(parameters['seed']);
              if (alwaysFail || seeds.length == 1)
                return http.Response('unavailable', 503);
              return http.Response.bytes(zipped, 200);
            }),
          ),
        );

        final now = DateTime.now();
        final turn = await db.createGenerationTurn(
          user: ChatMessage(
            id: 'u',
            role: 'user',
            content: '画一张图',
            createdAt: now,
          ),
          assistantMessageId: 'reply',
          model: 'deepseek-flash',
          reasoningEffort: 'high',
        );
        final claimed = (await db.claimGenerationJob(turn.id))!;
        const chat = IllustrationJob(
          source: IllustrationSource.chat,
          ownerId: 'reply',
          intent: '画插画',
          plan: _plan,
        );
        expect(
          await db.completeGenerationJobIfCurrent(
            jobId: claimed.id,
            runToken: claimed.runToken,
            assistant: ChatMessage(
              id: 'reply',
              role: 'assistant',
              content: '我来画',
              createdAt: now,
            ),
            illustration: chat,
          ),
          isTrue,
        );
        expect((await db.messageById('reply'))!.attachments, isEmpty);
        await worker.drainOne();
        final attachment = (await db.messageAttachmentsFor('reply')).single;
        expect(seeds, hasLength(2));
        expect(seeds[0], seeds[1]);
        expect(attachment.visionCompleted, isFalse);
        expect((await db.messageById('reply'))!.content, '我来画');
        expect(
          (await db.companionAlbumItems()).single.tags,
          containsAll(['generated', 'anime', 'self_image']),
        );
        await db.setCompanionAlbumTags(
          chat.key,
          tags: ['generated', 'self_image'],
        );

        const diary = IllustrationJob(
          source: IllustrationSource.diary,
          ownerId: 'diary:today',
          intent: '日记插画',
          plan: _plan,
        );
        await db.setSetting(
          IllustrationJob.diaryEntriesKey,
          jsonEncode([
            {'id': diary.ownerId, 'body': '我的日记'},
            {'id': 'diary:next', 'body': '下一篇日记'},
          ]),
        );
        await diary.admit(await db.database);
        await worker.drainOne();
        final blobs = await db.allMediaBlobs();
        expect(blobs, hasLength(1));
        expect(blobs.single.albumRefCount, 1);
        final album = (await db.companionAlbumItems()).single;
        expect(album.id, chat.key);
        expect(album.blobId, attachment.blobId);
        expect(album.categorySource, 'user');
        expect(
          album.tags,
          containsAll(['generated', 'diary', 'anime', 'self_image']),
        );
        await _expectAgentCanInspect(db, album);
        expect(
          await db.getSetting(
            '${IllustrationJob.diaryMediaPrefix}${diary.ownerId}',
          ),
          attachment.blobId,
        );
        await db.deleteCompanionAlbumItem(album.id);
        await db.deleteAttachmentMessage('reply');
        expect(await db.takeUnreferencedMediaBlobs(), isEmpty);

        const failing = IllustrationJob(
          source: IllustrationSource.diary,
          ownerId: 'diary:next',
          intent: '另一张',
          plan: _plan,
        );
        alwaysFail = true;
        await failing.admit(await db.database);
        await worker.drainOne();
        await worker.drainOne();
        final failed = IllustrationJob.decode(await db.getSetting(failing.key));
        expect(failed?['state'], 'failed');
        expect(failed?['attempts'], 2);
        expect(seeds, hasLength(5));
        expect(
          await db.getSetting(IllustrationJob.diaryEntriesKey),
          contains('下一篇日记'),
        );
      } finally {
        await db.closeForTesting();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      }
    },
  );
}
