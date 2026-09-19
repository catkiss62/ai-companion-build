import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_outcome_media.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/media/safe_public_image_downloader.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

McpToolOutcome _textOutcome(String text) => McpToolOutcome(
      content: <McpContentBlock>[
        McpContentBlock(kind: McpContentKind.text, text: text),
      ],
      isError: false,
    );

MessageAttachment _attachment(String id) => MessageAttachment(
      id: id,
      messageId: 'assistant-1',
      kind: MessageAttachment.imageKind,
      originalPath: 'media://$id/original.jpg',
      thumbnailPath: 'media://$id/thumbnail.png',
      mimeType: 'image/jpeg',
      byteSize: 3,
      width: 1,
      height: 1,
      source: 'cedar-test',
      createdAt: DateTime.utc(2026, 9, 19),
    );

void main() {
  test('extracts travel photo_url from nested JSON text only', () {
    final inner = r'''
{"spot":{"name":"Harbor","photo_url":"https://cdn.example/spot.jpg"},"specialties":[{"photo_url":"https://cdn.example/food.png"}]}
'''.trim();
    final outcome = _textOutcome(
      jsonEncode(<String, Object?>{'game': 'travel', 'text': inner, 'slot': 1}),
    );

    final candidates = CedarOutcomeMediaBridge.candidates(outcome);

    expect(
      candidates.map((item) => item.url).toList(),
      <String>[
        'https://cdn.example/spot.jpg',
        'https://cdn.example/food.png',
      ],
    );
    expect(candidates.every((item) => item.fieldName == 'photo_url'), isTrue);
  });

  test('supports explicit image containers and camel-case protocol fields', () {
    const outcome = McpToolOutcome(
      content: <McpContentBlock>[],
      isError: false,
      structuredContent: <String, Object?>{
        'result': <String, Object?>{
          'imageUrl': 'https://cdn.example/ore.jpg',
          'images': <Object?>[
            <String, Object?>{'url': 'https://cdn.example/tunnel.png'},
          ],
        },
      },
    );

    expect(
      CedarOutcomeMediaBridge.candidates(outcome)
          .map((item) => item.url)
          .toList(),
      <String>[
        'https://cdn.example/ore.jpg',
        'https://cdn.example/tunnel.png',
      ],
    );
  });

  test('rejects prose URLs, unsafe schemes, duplicates and excess media', () {
    final outcome = _textOutcome(r'''
{"text":"look at https://cdn.example/prose.jpg","photo_url":"http://cdn.example/plain.jpg","photos":[{"url":"https://cdn.example/a.jpg"},{"url":"https://cdn.example/a.jpg"},{"url":"https://cdn.example/b.jpg"},{"url":"https://cdn.example/c.jpg"},{"url":"https://cdn.example/d.jpg"}]}
''');

    final candidates = CedarOutcomeMediaBridge.candidates(outcome, limit: 3);

    expect(
      candidates.map((item) => item.url).toList(),
      <String>[
        'https://cdn.example/a.jpg',
        'https://cdn.example/b.jpg',
        'https://cdn.example/c.jpg',
      ],
    );
  });

  test('remote errors never produce candidates', () {
    const outcome = McpToolOutcome(
      content: <McpContentBlock>[
        McpContentBlock(
          kind: McpContentKind.text,
          text: '{"photo_url":"https://cdn.example/error.jpg"}',
        ),
      ],
      isError: true,
    );

    expect(CedarOutcomeMediaBridge.candidates(outcome), isEmpty);
  });

  test('download boundary rejects private and local HTTPS targets', () {
    expect(
      SafePublicImageDownloader.safePublicHttps(
        Uri.parse('https://127.0.0.1/image.jpg'),
      ),
      isFalse,
    );
    expect(
      SafePublicImageDownloader.safePublicHttps(
        Uri.parse('https://device.local/image.jpg'),
      ),
      isFalse,
    );
  });

  test('activity event preserves the same durable attachment reference', () {
    final event = CedarGameEvent(
      id: 'event-1',
      kind: 'outcome',
      summary: 'ore found',
      createdAt: DateTime.utc(2026, 9, 19),
      imageData: 'legacy-inline',
    ).withAttachmentImage(
      reference: 'media://sha/original.jpg',
      mimeType: 'image/jpeg',
    );

    final restored = CedarGameEvent.fromJson(event.toJson()).withoutInlineMedia();

    expect(restored.imageReference, 'media://sha/original.jpg');
    expect(restored.imageMimeType, 'image/jpeg');
    expect(restored.imageData, isEmpty);
    expect(restored.contentKinds, contains('image'));
  });

  test('materialization keeps successes and degrades individual failures', () async {
    final values = <CedarOutcomeMediaCandidate>[
      const CedarOutcomeMediaCandidate(
        url: 'https://cdn.example/a.jpg',
        fieldName: 'photo_url',
      ),
      const CedarOutcomeMediaCandidate(
        url: 'https://cdn.example/fail.jpg',
        fieldName: 'photo_url',
      ),
      const CedarOutcomeMediaCandidate(
        url: 'https://cdn.example/b.jpg',
        fieldName: 'photo_url',
      ),
    ];
    final discarded = <String>[];

    final attachments = await CedarOutcomeMediaBridge.materialize(
      candidates: values,
      materialize: (candidate) async {
        if (candidate.url.contains('fail')) throw const FormatException('bad');
        return _attachment(candidate.url.endsWith('a.jpg') ? 'a' : 'b');
      },
      discard: (attachment) async => discarded.add(attachment.id),
    );

    expect(attachments.map((item) => item.id).toList(), <String>['a', 'b']);
    expect(discarded, isEmpty);
  });

  test('Stop discards every materialized but undelivered attachment', () async {
    final token = GenerationCancellationToken();
    final discarded = <String>[];
    var calls = 0;

    final future = CedarOutcomeMediaBridge.materialize(
      candidates: const <CedarOutcomeMediaCandidate>[
        CedarOutcomeMediaCandidate(
          url: 'https://cdn.example/a.jpg',
          fieldName: 'photo_url',
        ),
        CedarOutcomeMediaCandidate(
          url: 'https://cdn.example/b.jpg',
          fieldName: 'photo_url',
        ),
      ],
      cancellationToken: token,
      materialize: (candidate) async {
        calls += 1;
        final attachment = _attachment('$calls');
        if (calls == 2) token.cancel();
        return attachment;
      },
      discard: (attachment) async => discarded.add(attachment.id),
    );

    await expectLater(
      future,
      throwsA(isA<GenerationCancelledByUserException>()),
    );
    expect(discarded.toSet(), <String>{'1', '2'});
  });
}
