import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MessageAttachment attachment({
  String status = MessageAttachment.visionPendingStatus,
  String summary = '',
}) {
  return MessageAttachment(
    id: 'attachment-1',
    messageId: 'message-1',
    kind: MessageAttachment.imageKind,
    originalPath: 'originals/attachment-1.jpg',
    thumbnailPath: 'thumbnails/attachment-1.png',
    mimeType: 'image/jpeg',
    byteSize: 1234,
    width: 800,
    height: 600,
    source: 'gallery',
    createdAt: DateTime(2026),
    visionStatus: status,
    visionSummary: summary,
  );
}

void main() {
  test('completed visual observation becomes prompt context', () {
    final message = ChatMessage(
      id: 'message-1',
      role: 'user',
      content: '看这个',
      createdAt: DateTime(2026),
      attachments: [
        attachment(
          status: MessageAttachment.visionCompletedStatus,
          summary: '一只橘猫坐在窗边。',
        ),
      ],
    );

    expect(message.promptContent, contains('一只橘猫坐在窗边'));
    expect(message.promptContent, contains('附言：看这个'));
  });

  test('Qwen request uses a data URI and parses strict JSON', () async {
    late Map<String, dynamic> requestBody;
    final client = QwenVisionClient(
      client: MockClient((request) async {
        requestBody =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'model': 'qwen3-vl-plus',
            'choices': [
              {
                'message': {
                  'content': jsonEncode({'summary': '桌上有一只蓝色杯子。'}),
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final directory = await Directory.systemTemp.createTemp('vision-test-');
    final file = File('${directory.path}/thumbnail.png');
    await file.writeAsBytes(const [137, 80, 78, 71]);

    try {
      final result = await client.observe(
        apiKey: 'test-key',
        endpoint: QwenVisionClient.defaultEndpoint,
        model: QwenVisionClient.defaultModel,
        imageFile: file,
      );
      final messages = requestBody['messages'] as List<dynamic>;
      final user = messages[1] as Map<String, dynamic>;
      final content = user['content'] as List<dynamic>;
      final image = content.first as Map<String, dynamic>;
      final imageUrl = image['image_url'] as Map<String, dynamic>;
      expect(imageUrl['url'], startsWith('data:image/png;base64,'));
      expect(result.summary, '桌上有一只蓝色杯子。');
    } finally {
      client.close();
      await directory.delete(recursive: true);
    }
  });

  test('album assessment sends candidate plus soft identity reference', () async {
    late Map<String, dynamic> requestBody;
    final client = QwenVisionClient(
      albumIdentityReferenceLoader: () async => Uint8List.fromList([1, 2, 3]),
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'model': 'qwen3-vl-plus',
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'summary': '蓝发鲸鱼少女插画。',
                    'album': {
                      'save': true,
                      'category': 'self_image',
                      'reason': '核心身份组合一致。',
                      'adult_content': false,
                      'aesthetic_tags': ['蓝色系', '鲸鱼尾'],
                      'confidence': 0.91,
                    },
                  }),
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final directory = await Directory.systemTemp.createTemp('album-vision-');
    final file = File('${directory.path}/thumbnail.png');
    await file.writeAsBytes(const [137, 80, 78, 71]);

    try {
      final result = await client.observe(
        apiKey: 'test-key',
        endpoint: QwenVisionClient.defaultEndpoint,
        model: QwenVisionClient.defaultModel,
        imageFile: file,
        assessForAlbum: true,
      );
      final messages = requestBody['messages'] as List<dynamic>;
      final system = messages.first as Map<String, dynamic>;
      final user = messages[1] as Map<String, dynamic>;
      final content = user['content'] as List<dynamic>;
      expect(content, hasLength(4));
      expect(
        ((content[2] as Map<String, dynamic>)['image_url']
                as Map<String, dynamic>)['url'],
        startsWith('data:image/webp;base64,'),
      );
      expect(system['content'], contains('鲸鱼耳鳍'));
      expect(system['content'], contains('服装、裙长、配饰'));
      expect(result.albumSave, isTrue);
      expect(result.albumCategory, 'self_image');
    } finally {
      client.close();
      await directory.delete(recursive: true);
    }
  });

  test('adult album result is never saved', () async {
    final client = QwenVisionClient(
      albumIdentityReferenceLoader: () async => Uint8List(0),
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': '成人向图片。',
                      'album': {
                        'save': true,
                        'category': 'other',
                        'adult_content': true,
                      },
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    final directory = await Directory.systemTemp.createTemp('adult-vision-');
    final file = File('${directory.path}/thumbnail.png');
    await file.writeAsBytes(const [137, 80, 78, 71]);

    try {
      final result = await client.observe(
        apiKey: 'test-key',
        endpoint: QwenVisionClient.defaultEndpoint,
        model: QwenVisionClient.defaultModel,
        imageFile: file,
        assessForAlbum: true,
      );
      expect(result.albumSave, isFalse);
      expect(result.albumCategory, 'other');
    } finally {
      client.close();
      await directory.delete(recursive: true);
    }
  });
}
