import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/core/autonomy/layered_public_web_provider.dart';
import 'package:ai_companion_localfirst/core/autonomy/web_page_evidence.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response completion(Object content, {String? finishReason = 'stop'}) =>
    http.Response(
      jsonEncode({
        'choices': [
          {
            if (finishReason != null) 'finish_reason': finishReason,
            'message': {'content': jsonEncode(content)},
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

PublicWebCandidateDraft source() => PublicWebCandidateDraft(
  fingerprint: 'page',
  title: '完整公开材料',
  summary: '原始搜索片段',
  url: 'https://example.com/page',
  sourceDomain: 'example.com',
  provider: 'tavily',
  language: 'zh',
  driveKey: 'curiosity',
  intentAction: 'discover_interest',
  interestKey: 'curiosity:test',
  discoveredAt: DateTime.utc(2026, 10, 12),
  expiresAt: DateTime.utc(2026, 10, 26),
);

const summary = {
  'reader_summary': '正文中的事实与限制均已整理。',
  'key_points': ['明确的事实'],
  'uncertainties': ['仍需进一步核实'],
  'topic_tags': ['研究'],
  'event_date': '',
  'publication_date': '',
};

AgnesWebCompactor compactor(http.Client client) => AgnesWebCompactor(
  apiKey: 'test-key',
  endpoint: 'https://relay.example/v1/chat/completions',
  model: 'agnes-2.5-flash',
  client: client,
);

void main() {
  for (final finish in <String?>['stop', null]) {
    test('Qwen accepts complete album JSON with finish=$finish', () async {
      final client = QwenVisionClient(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['max_tokens'], 4096);
          expect(body['response_format'], {'type': 'json_object'});
          expect((body['messages'] as List).last['content'], hasLength(2));
          return completion({
            'summary': '蓝色杯子旁有纸条，写着“稍后回来”。',
            'request_match': {
              'matches': true,
              'confidence': 0.94,
              'reason': '杯子主体清晰可见',
            },
            'album': {
              'save': true,
              'category': 'memory',
              'tags': ['memory'],
              'reason': '手写纸条留下共同回忆',
              'adult_content': false,
              'aesthetic_tags': ['静物'],
              'confidence': 0.92,
            },
          }, finishReason: finish);
        }),
      );
      try {
        final observation = await client.observeBytes(
          apiKey: 'test-key',
          endpoint: QwenVisionClient.defaultEndpoint,
          model: QwenVisionClient.defaultModel,
          imageBytes: Uint8List.fromList([137, 80, 78, 71]),
          assessForAlbum: true,
          requestedSubject: '蓝色杯子',
        );
        expect(observation.summary, contains('稍后回来'));
        expect(observation.albumSave, isTrue);
        expect(observation.requestMatchConfidence, 0.94);
      } finally {
        client.close();
      }
    });
  }

  for (final finish in ['length', 'content_filter', 'tool_calls']) {
    test('Qwen rejects explicit $finish even with parseable JSON', () async {
      final client = QwenVisionClient(
        client: MockClient((_) async => completion(
          {'summary': '不能把这个有效 JSON 当成完整观察。'},
          finishReason: finish,
        )),
      );
      try {
        await expectLater(
          client.observeBytes(
            apiKey: 'test-key',
            endpoint: QwenVisionClient.defaultEndpoint,
            model: QwenVisionClient.defaultModel,
            imageBytes: Uint8List.fromList([137, 80, 78, 71]),
          ),
          throwsA(isA<FormatException>().having(
            (error) => error.message,
            'reason',
            contains(finish),
          )),
        );
      } finally {
        client.close();
      }
    });
  }

  test('Agnes reads every page segment and merges without output caps', () async {
    final materials = <String>[];
    var merges = 0;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body.containsKey('max_tokens'), isFalse);
      final prompt = (body['messages'] as List).last['content'] as String;
      if (prompt.contains('【公开正文开始】')) {
        materials.add(prompt.split('【公开正文开始】\n').last
            .split('\n【公开正文结束】').first);
      } else {
        merges++;
      }
      return completion(summary);
    });
    try {
      final page = '${List.filled(28000, '文').join()}尾部证据';
      final reader = compactor(client);
      final result = await reader.summarizeExtracted(
        query: '全部材料',
        candidates: [source()],
        extractedContents: {source().url: page},
      );
      expect(materials, hasLength(2));
      expect(materials.join(), page);
      expect(merges, 1);
      expect(result.single.isVerifiedRead, isTrue);
      expect(result.single.pageBody, page);
      expect(reader.lastSucceeded, isTrue);
    } finally {
      client.close();
    }
  });

  for (final stage in ['segment', 'merge']) {
    test('Agnes refuses a truncated $stage summary as verified evidence', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final prompt = (body['messages'] as List).last['content'] as String;
        final segment = prompt.contains('【公开正文开始】');
        return completion(summary,
          finishReason: (stage == 'segment') == segment ? 'length' : 'stop');
      });
      try {
        final reader = compactor(client);
        final result = await reader.summarizeExtracted(
          query: '全部材料',
          candidates: [source()],
          extractedContents: {source().url: List.filled(28010, '文').join()},
        );
        expect(result.single.isVerifiedRead, isFalse);
        expect(result.single.readState, 'summary_failed');
        expect(reader.lastSucceeded, isFalse);
      } finally {
        client.close();
      }
    });
  }

  for (final finish in <String?>['stop', null, 'length']) {
    test('Agnes snippet response finish=$finish preserves success boundary', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body.containsKey('max_tokens'), isFalse);
        return completion({
          'items': [{'id': 0, 'summary': '整理后的公开事实'}],
        }, finishReason: finish);
      });
      try {
        final reader = compactor(client);
        final result = await reader.compact([source()]);
        expect(reader.lastSucceeded, finish != 'length');
        expect(result.single.summary,
          finish == 'length' ? source().summary : '整理后的公开事实');
      } finally {
        client.close();
      }
    });
  }

  test('Agnes retains connection probe cap and full-page safety budget', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect((jsonDecode(request.body) as Map)['max_tokens'], 120);
      return completion('简短连接检查');
    });
    try {
      final reader = compactor(client);
      expect(await reader.testConnection(), isNotNull);
      final result = await reader.summarizeExtracted(
        query: '全部材料',
        candidates: [source()],
        extractedContents: {
          source().url: List.filled(WebPageEvidence.maxBodyChars + 1, '文').join(),
        },
      );
      expect(requests, 1);
      expect(result.single.readState, 'unreadable');
      expect(result.single.appraisalReason, 'body_over_reading_budget');
      expect(reader.lastSucceeded, isFalse);
    } finally {
      client.close();
    }
  });
}
