import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/agent/research_commission.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/diagnostics/model_usage_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;
  late CommissionWorkspace ws;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp();
    ws = CommissionWorkspace(directory: dir);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
    'recent completed work: 48 hours, latest three, deletion and private skill files',
    () async {
      final now = DateTime(2026, 11, 24, 12);
      String name(int i) => '任务-00000000-0000-0000-0000-00000000000$i.json';
      for (var i = 0; i < 6; i++) {
        await ws.write(
          name(i),
          jsonEncode({
            'goal': '$i',
            'state': 'completed',
            'at': now
                .subtract(Duration(hours: i == 4 ? 50 : i))
                .millisecondsSinceEpoch,
          }),
        );
      }
      await ws.write('技能-测试.md', '仅作工作指引');
      expect((await ws.recent(now: now)).map((m) => m['goal']), [
        '0',
        '1',
        '2',
      ]);
      await ws.remove(name(0));
      await ws.remove(name(1));
      expect((await ws.recent(now: now)).map((m) => m['goal']), [
        '2',
        '3',
        '5',
      ]);
      expect(() => ws.read('../技能-测试.md'), throwsFormatException);
    },
  );
  test(
    'real tool protocol searches then reads; prior prefix and evidence persist',
    () async {
      final history = <List<Map<String, Object?>>>[];
      final steps = [
        DeepSeekToolCall(
          id: 'a',
          name: ResearchCommission.search,
          arguments: '{"query":"android pet"}',
        ),
        DeepSeekToolCall(
          id: 'b',
          name: ResearchCommission.read,
          arguments: '{"repository":"demo/Pet"}',
        ),
      ];
      final result = await ResearchCommission.run(
        goal: '找开源桌宠项目',
        context: [],
        workspace: ws,
        cancellation: GenerationCancellationToken(),
        progress: (_, __) {},
        transport: MockClient(
          (req) async => req.url.path.endsWith('/readme')
              ? http.Response('Android overlay README', 200)
              : http.Response(
                  '{"items":[{"full_name":"demo/Pet","stargazers_count":33}]}',
                  200,
                ),
        ),
        plan: (messages) async {
          final i = history.length;
          history.add(messages);
          return (
            content: i == 2 ? '已核实' : '',
            reasoning: '',
            toolCalls: i < 2 ? [steps[i]] : <DeepSeekToolCall>[],
            finishReason: 'stop',
          );
        },
      );
      expect(result['readmes'], 1);
      expect(result['tool_calls'], 2);
      expect(history[1].take(history[0].length), history[0]);
      expect(
        (result['evidence'] as List).last['url'],
        'https://github.com/demo/Pet#readme',
      );
    },
  );
  test(
    'planner creates a private skill and cannot invoke unknown tools',
    () async {
      var i = 0;
      final r = await ResearchCommission.run(
        goal: '保存工作方法',
        context: [],
        workspace: ws,
        cancellation: GenerationCancellationToken(),
        progress: (_, __) {},
        plan: (_) async => (
          reasoning: '',
          content: '',
          finishReason: 'stop',
          toolCalls: i++ == 0
              ? [
                  const DeepSeekToolCall(
                    id: 'a',
                    name: 'workspace_save',
                    arguments: '{"kind":"技能","title":"筛选","body":"先读 README"}',
                  ),
                  const DeepSeekToolCall(
                    id: 'b',
                    name: 'send_qq',
                    arguments: '{}',
                  ),
                ]
              : <DeepSeekToolCall>[],
        ),
      );
      expect(await ws.read('技能-筛选.md'), '先读 README');
      expect((r['evidence'] as List).last['error'], 'unsupported_tool');
    },
  );
  test('missing cache accounting is distinct from an observed zero', () {
    final r = ModelUsageTelemetry.planningTasks(
      jsonEncode([
        {
          'provider': 'deepseek',
          'lane': ResearchCommission.lane,
          'execution_id': 'job',
          'input_tokens': 100,
        },
        {
          'provider': 'deepseek',
          'lane': ResearchCommission.lane,
          'execution_id': 'job',
          'input_tokens': 200,
          'cache_usage_available': true,
          'cache_hit_tokens': 160,
          'cache_miss_tokens': 40,
        },
      ]),
    ).single;
    expect((r['firstObserved'] as Map)['hitRatio'], null);
    expect((r['laterObserved'] as Map)['hitRatio'], .8);
  });
}
