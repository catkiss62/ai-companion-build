import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/work_text_reference.dart';
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
  test('freshness is per target and per turn, including history, timeout and budget exits', () async {
    for (final scenario in ['history', 'wrong', 'timeout', 'partial', 'both', 'budget', 'implicit', 'online', 'file']) {
      var turn = 0;
      final listing = scenario == 'partial' || scenario == 'both';
      final goal = listing ? '查清单中两个仓库目前的情况'
          : scenario == 'implicit' ? '查最新'
          : scenario == 'online' ? '联网重读 Acme/One 的说明'
          : scenario == 'file' ? '再查一下文件里的最新日期'
          : '查 Acme/One 最新情况';
      final result = await ResearchCommission.run(
        goal: goal, context: [], priorRepositories: {'acme/one', 'other/two'},
        previousTargets: {'acme/one'},
        reference: WorkTextSnapshot('list.txt', 'https://github.com/acme/One\nacme/Three'),
        cancellation: GenerationCancellationToken(), progress: (_, __) {},
        transport: MockClient((_) async {
          if (scenario == 'timeout') throw TimeoutException('offline');
          return http.Response('live README', 200);
        }),
        searchHistory: (_, __) async => {'matches': [{'source': 'README · acme/one', 'excerpt': 'old'}], 'thread_turns': 2},
        plan: (_) async {
          turn++;
          DeepSeekToolCall read(String name) => DeepSeekToolCall(id: 'r-$turn-$name', name: ResearchCommission.read,
              arguments: jsonEncode({'repository': name, 'use_saved': true}));
          final calls = <DeepSeekToolCall>[];
          if (turn == 1 || scenario == 'budget') {
            if (['history', 'budget', 'implicit', 'online'].contains(scenario)) {
              calls.add(DeepSeekToolCall(id: 'h$turn', name: ResearchCommission.recall, arguments: '{"query":"one"}'));
            } else if (scenario == 'wrong') {
              calls.add(read('other/two'));
            } else if (scenario != 'file') {
              calls.add(read('acme/one'));
              if (scenario == 'both') calls.add(read('acme/three'));
            }
          }
          return (content: '结束', reasoning: '', finishReason: 'stop', toolCalls: calls);
        },
      );
      if (scenario == 'both' || scenario == 'file') {
        expect(result['end'], 'planner_finished', reason: scenario);
        if (listing) expect(result['live_readmes'], containsAll(['acme/one', 'acme/three']));
      } else {
        expect(result['end'], 'evidence_incomplete', reason: scenario);
        expect(result['unverified_repositories'], [listing ? 'acme/three' : 'acme/one'], reason: scenario);
        if (scenario == 'wrong') expect(result['live_readmes'], ['other/two']);
        if (scenario == 'budget') expect(result['planning_rounds'], 6);
        if (scenario == 'timeout') expect((result['evidence'] as List).first['error'], 'github_timeout');
      }
    }
  });

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
              Float32List.fromList(
                s.contains('睡觉')
                    ? [1, 0]
                    : s.contains('休眠')
                    ? [.51, .86]
                    : [.23, .97],
              ),
          ],
        ),
      );
      final rows = [
        {'goal': '休眠', 'answer': '启动夜间休眠'},
        {'goal': '云端目录', 'answer': '选蓝色'},
      ];
      final hits = await engine.search(
        '睡觉',
        rows,
        GenerationCancellationToken(),
      );
      expect((hits['matches'] as List).map((e) => e['turn']).toSet(), {1});
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
  test(
    'saved complete README can be reused, and a request for current evidence fetches again',
    () async {
      for (final fresh in [false, true]) {
        var calls = 0, plans = 0;
        final result = await ResearchCommission.run(
          goal: fresh ? '核对最新 README' : '沿用上次依据',
          context: [],
          priorRepositories: {'demo/a'},
          savedReadmes: {'demo/a': 'saved text'},
          cancellation: GenerationCancellationToken(),
          progress: (_, __) {},
          transport: MockClient((_) async {
            calls++;
            return http.Response('fresh text', 200);
          }),
          plan: (messages) async {
            if (plans > 0)
              expect(
                messages.last['content'],
                contains(fresh ? 'fresh text' : 'saved text'),
              );
            return (
              content: '完成',
              reasoning: '',
              finishReason: 'stop',
              toolCalls: plans++ == 0
                  ? [
                      DeepSeekToolCall(
                        id: '1',
                        name: ResearchCommission.read,
                        arguments: '{"repository":"demo/a","use_saved":true}',
                      ),
                    ]
                  : <DeepSeekToolCall>[],
            );
          },
        );
        expect(calls, fresh ? 1 : 0);
        expect(result['verified_repositories'], contains('demo/a'));
      }
    },
  );
}
