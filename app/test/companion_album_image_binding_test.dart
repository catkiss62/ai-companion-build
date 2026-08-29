import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/core/diagnostics/provider_health.dart';
import 'package:ai_companion_localfirst/core/storage/companion_album_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestAlbumStorage extends CompanionAlbumStorage {
  _TestAlbumStorage(this.directory);

  final Directory directory;

  @override
  Future<Directory> get rootDirectory async => directory;
}

void main() {
  test('ordinary other image keeps observed and stored bytes identical', () async {
    final directory = await Directory.systemTemp.createTemp('album-binding-');
    final source = File('${directory.path}/candidate.png');
    await source.writeAsBytes(const [137, 80, 78, 71, 1, 2, 3, 4]);
    final vision = QwenVisionClient(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': '一幅有清晰主体的普通插画。',
                      'album': {
                        'save': true,
                        'category': 'other',
                        'reason': '画面完整且有趣。',
                        'adult_content': false,
                      },
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final storage = _TestAlbumStorage(directory);

    try {
      final observation = await vision.observe(
        apiKey: 'test-key',
        endpoint: QwenVisionClient.defaultEndpoint,
        model: QwenVisionClient.defaultModel,
        imageFile: source,
        assessForAlbum: true,
      );
      expect(observation.albumSave, isTrue);
      expect(observation.albumCategory, 'other');
      await storage.requireContentSha256(
        source,
        observation.inputContentSha256,
      );
      final stored = await storage.saveThumbnail(
        id: 'ordinary-other',
        source: source,
        expectedContentSha256: observation.inputContentSha256,
      );
      final storedFile = await storage.fileFor(stored.relativePath);
      expect(await storedFile.readAsBytes(), await source.readAsBytes());
      expect(stored.contentSha256, observation.inputContentSha256);
    } finally {
      vision.close();
      await directory.delete(recursive: true);
    }
  });

  test('candidate replacement after vision is rejected before save', () async {
    final directory = await Directory.systemTemp.createTemp('album-binding-');
    final source = File('${directory.path}/candidate.png');
    await source.writeAsBytes(const [137, 80, 78, 71, 1]);
    final vision = QwenVisionClient(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': '候选图片。',
                      'album': {
                        'save': true,
                        'category': 'other',
                        'adult_content': false,
                      },
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final storage = _TestAlbumStorage(directory);

    try {
      final observation = await vision.observe(
        apiKey: 'test-key',
        endpoint: QwenVisionClient.defaultEndpoint,
        model: QwenVisionClient.defaultModel,
        imageFile: source,
        assessForAlbum: true,
      );
      await source.writeAsBytes(const [137, 80, 78, 71, 9]);
      await expectLater(
        storage.requireContentSha256(
          source,
          observation.inputContentSha256,
        ),
        throwsA(isA<AlbumImageBindingException>()),
      );
      await expectLater(
        storage.saveThumbnail(
          id: 'must-not-save',
          source: source,
          expectedContentSha256: observation.inputContentSha256,
        ),
        throwsA(isA<AlbumImageBindingException>()),
      );
      expect(
        await File('${directory.path}/thumbnails/must-not-save.png').exists(),
        isFalse,
      );
    } finally {
      vision.close();
      await directory.delete(recursive: true);
    }
  });

  test('binding failures map to a fixed redacted diagnostic category', () {
    const error = AlbumImageBindingException('source_changed');
    expect(error.toString(), 'album_image_binding_mismatch:source_changed');
    expect(ProviderHealth.errorCategory(error), 'image_binding');
  });
}
