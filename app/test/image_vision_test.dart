import 'dart:convert';
import 'dart:io';

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
}
