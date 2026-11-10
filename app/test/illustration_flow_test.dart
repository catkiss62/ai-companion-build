import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_client.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_cue.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_job.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_prompt.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_worker.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
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
    'chat and diary share bytes after one retry, and diary pins them',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'illustration-flow-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      FlutterSecureStorage.setMockInitialValues({});
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
        expect(await db.allMediaBlobs(), hasLength(1));
        final album = await db.companionAlbumItems();
        expect(album, hasLength(2));
        expect(album.map((item) => item.blobId).toSet(), {attachment.blobId});
        expect(
          album.singleWhere((item) => item.sourceId == diary.ownerId).tags,
          containsAll(['generated', 'diary']),
        );
        expect(
          await db.getSetting(
            '${IllustrationJob.diaryMediaPrefix}${diary.ownerId}',
          ),
          attachment.blobId,
        );
        for (final item in album) {
          await db.deleteCompanionAlbumItem(item.id);
        }
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
