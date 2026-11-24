import 'dart:convert';
import 'dart:typed_data';
import 'package:ai_companion_localfirst/core/agent/commission_history_search.dart';
import 'package:ai_companion_localfirst/core/agent/research_commission.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/memory/local_semantic_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'retrieves clipped and older original text, later revisions and same-thread evidence',
    () async {
      final rows = <Map<String, dynamic>>[
        {'goal': '备份间隔', 'answer': '备份间隔为一小时'},
        for (int i = 0; i < 11; i++) {'goal': '天气', 'answer': '晴'},
        {'goal': '备份间隔改成十五分钟', 'answer': '收到'},
        {
          'goal': '看说明',
          'answer': '空' * 2600 + '云端校验码 Q6N8',
          'evidence': [
            {
              'repository': 'demo/Two',
              'url': 'https://github.com/demo/Two#readme',
              'readme_excerpt': 'The offline engine uses local weights.',
            },
          ],
        },
      ];
      final engine = CommissionHistorySearch(
        encoder: LocalSemanticIndex(enabled: false),
      );
      Future<List> lookup(String q) async =>
          (await engine.search(
                q,
                rows,
                GenerationCancellationToken(),
              ))['matches']
              as List;
      final result = await lookup('备份间隔');
      expect(result.map((e) => e['turn']), containsAll([1, 13]));
      expect((await lookup('Q6N8')).first['excerpt'], contains('校验码'));
      expect(
        (await lookup('local weights')).first['url'],
        contains('demo/Two#readme'),
      );
      expect(await lookup('量子隧穿'), isEmpty);
      rows.removeLast();
      expect(await lookup('Q6N8'), isEmpty);
    },
  );

  test(
    'semantic paraphrase uses separate local vectors; deleted source cannot return',
    () async {
      final engine = CommissionHistorySearch(
        encoder: LocalSemanticIndex(
          enabled: true,
          encoder: (texts) async => [
            for (final s in texts)
              Float32List.fromList([
                if (s.contains('休眠') || s.contains('睡觉')) 1 else 0,
                if (s.contains('休眠') || s.contains('睡觉')) 0 else 1,
              ]),
          ],
        ),
      );
      final rows = [
        {'goal': '休眠', 'answer': '启动夜间休眠'},
      ];
      final hits = await engine.search(
        '睡觉',
        rows,
        GenerationCancellationToken(),
      );
      expect(hits['matches'], isNotEmpty);
      final empty = await engine.search(
        '睡觉',
        [],
        GenerationCancellationToken(),
      );
      expect(empty['matches'], isEmpty);
    },
  );

  test(
    'comparison continues after one repository, follows README cursor and terminates',
    () async {
      var step = 0, requests = 0;
      DeepSeekToolCall read(String repo, [int offset = 0]) => DeepSeekToolCall(
        id: 'r$step',
        name: ResearchCommission.read,
        arguments: jsonEncode({'repository': repo, 'offset': offset}),
      );
      final r = await ResearchCommission.run(
        goal: '对比 https://github.com/demo/A 和 https://github.com/demo/B 离线能力',
        context: [],
        cancellation: GenerationCancellationToken(),
        progress: (_, __) {},
        transport: MockClient((req) async {
          requests++;
          return http.Response('x' * 4200 + 'LOCAL', 200);
        }),
        plan: (messages) async {
          step++;
          if (step == 3) expect(messages.last['content'], contains('demo/b'));
          if (step == 5) expect(messages.last['content'], contains('LOCAL'));
          final calls = switch (step) {
            1 => [read('demo/A')],
            3 => [read('demo/B')],
            4 => [read('demo/B', 4200)],
            _ => <DeepSeekToolCall>[],
          };
          return (
            content: '结果',
            reasoning: '',
            toolCalls: calls,
            finishReason: 'stop',
          );
        },
      );
      expect(requests, 2);
      expect(r['verified_repositories'], containsAll(['demo/a', 'demo/b']));
      expect(r['end'], 'planner_finished');
    },
  );
  test(
    'unavailable comparison can be delivered with an explicit evidence gap',
    () async {
      var count = 0;
      final result = await ResearchCommission.run(
        goal: '比较 https://github.com/demo/A 和 https://github.com/demo/B',
        context: [],
        progress: (_, __) {},
        cancellation: GenerationCancellationToken(),
        transport: MockClient((_) async => http.Response('read', 200)),
        plan: (_) async => (
          content: '部分证据',
          reasoning: '',
          finishReason: 'stop',
          toolCalls: ++count == 1
              ? [
                  DeepSeekToolCall(
                    id: '1',
                    name: ResearchCommission.read,
                    arguments: '{"repository":"demo/A"}',
                  ),
                ]
              : <DeepSeekToolCall>[],
        ),
      );
      expect(count, 3);
      expect(result['end'], 'evidence_incomplete');
    },
  );
}
