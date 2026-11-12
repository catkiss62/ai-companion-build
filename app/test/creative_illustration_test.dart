import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_illustration.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/illustration/illustration_client.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'creative_agent_test.dart' as fixture;

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
  const png = 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAK0lEQVR42u3NQQEAQAQAMC6hYNJJdCX4bQWW1ROXXhwTCAQCgUAgEAgEWz7rPQHu8hmbmAAAAABJRU5ErkJggg==';
  final bytes = base64Decode(png);
  final blob = sha256.convert(bytes).toString();
  final url = CreativeIllustration.url(blob);

  for (final scenario in ['success', 'failure', 'disabled']) {
    test('creative illustration $scenario keeps the work completable', () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      final store = CreativeStore(db);
      final directory = await Directory.systemTemp.createTemp('creative-image-');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final success = scenario == 'success';
      final html = fixture.repaired + (success ? '<img src="$url" alt="一盏灯">' : '');
      var plans = 0, generations = 0, turns = 0;
      try {
        FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture'});
        await SecureConfig.instance.writeIllustration(const IllustrationConnection(
          baseUrl: 'https://illustration.invalid', apiKey: 'fixture', enabled: true,
        ));
        if (scenario != 'disabled') await db.setSetting(CreativeIllustration.enabledKey, '1');
        final work = await store.commission(deepThinking: true, requestId: 'picture',
          messageId: 'commission', brief: '做一张卡片', requestQuote: '做一张卡片', latestText: '做一张卡片');
        final id = work['id'] as String;
        messenger.setMockMethodCallHandler(CreativeWorker.preview, (call) async {
          final args = call.arguments as Map;
          if (success) {
            expect((args['images'][url] as Map)['bytes'], bytes);
          } else {
            expect(args.containsKey('images'), isFalse);
          }
          return fixture.nativePreviewResult(args);
        });
        final worker = CreativeWorker(db,
          now: () => DateTime(2026, 11, 12, 12),
          illustrationClient: IllustrationClient(clientFactory: () => MockClient((_) async {
            generations++;
            return success ? http.Response.bytes(bytes, 200) : http.Response('unavailable', 503);
          })),
          clientFactory: (abort) => DeepSeekClient(
            abortWhen: abort,
            jsonClientFactory: () => MockClient((_) async {
              plans++;
              return http.Response(jsonEncode({'choices': [{'finish_reason': 'stop', 'message': {
                'content': jsonEncode({'style': 'free', 'scene': 'a lamp', 'description': '一盏灯'}),
              }}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
            }),
            streamClientFactory: () => MockClient((request) async {
              turns++;
              final payload = jsonDecode(request.body) as Map;
              final tools = (payload['tools'] as List).map((tool) => tool['function']['name']);
              expect(tools.contains('work_generate_image'), turns == 1 && scenario != 'disabled');
              if (turns == 1) {
                return fixture.response(fixture.sse([
                  fixture.plan(), fixture.call('work_generate_image', {'brief': '蓝色灯盏'}),
                  // Even a duplicate tool call in the same batch cannot charge again.
                  if (scenario != 'disabled')
                    fixture.call('work_generate_image', {'brief': '再画一盏'}, id: 'duplicate'),
                ]));
              }
              if (!success) expect(request.body, contains('重新安排版式'));
              return fixture.response(fixture.sse([
                fixture.write(html), fixture.previewCall(), fixture.call('work_finish', {}),
              ]));
            }),
          ),
        );
        await worker.runOnce();
        expect(await db.companionAlbumItems(), isEmpty);
        await worker.runOnce();
        expect((await store.get(id))['status'], 'ready');
        expect(plans, scenario == 'disabled' ? 0 : 1);
        expect(generations, plans);
        final album = await db.companionAlbumItems();
        if (!success) {
          expect(album, isEmpty);
          return;
        }
        expect(album.single.blobId, blob);
        expect(await db.getSetting(CreativeIllustration.owner(id, blob)), blob);
        expect(await CreativeIllustration.load(db, 'another-work', html), isEmpty);
        expect(await CreativeIllustration.standaloneHtml(db, id, html), contains('data:image/png;base64,$png'));
        await db.deleteCompanionAlbumItem(album.single.id);
        expect(await db.removeUnreferencedMediaBlob(blob), isNull);
        expect((await CreativeIllustration.load(db, id, html)).keys, [url]);
        final snapshot = Map<String, dynamic>.from(await db.exportAll());
        await db.importAll(snapshot);
        expect((await CreativeIllustration.load(db, id, html)).keys, [url]);
        expect(await db.removeUnreferencedMediaBlob(blob), isNull);
      } finally {
        messenger.setMockMethodCallHandler(CreativeWorker.preview, null);
        PathProviderPlatform.instance = originalPaths;
        await db.closeForTesting();
        await directory.delete(recursive: true);
      }
    });
  }
}
