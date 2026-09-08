import 'package:ai_companion_localfirst/core/agent/agent_task_loop.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:flutter_test/flutter_test.dart';

AgentToolResult result(AgentToolStatus status) => AgentToolResult(
      toolId: AgentToolRegistry.phoneRead.id,
      status: status,
      displayText: status.key,
      promptData: 'bounded outcome',
    );

void main() {
  test('Agent v2 keeps three planning rounds and six total calls', () {
    expect(AgentTaskLoopPolicy.maxPlanningRounds, 3);
    expect(AgentTaskLoopPolicy.maxToolCalls, 6);
    expect(AgentTaskLoopPolicy.maxCallsPerRound, 2);
    expect(
      AgentTaskLoopPolicy.allowedCalls(planningRounds: 0, toolCalls: 0),
      2,
    );
    expect(
      AgentTaskLoopPolicy.allowedCalls(planningRounds: 2, toolCalls: 5),
      1,
    );
    expect(
      AgentTaskLoopPolicy.allowedCalls(planningRounds: 3, toolCalls: 5),
      0,
    );
    expect(
      AgentTaskLoopPolicy.allowedCalls(planningRounds: 2, toolCalls: 6),
      0,
    );
  });

  test('call fingerprints are stable and separate changed arguments', () {
    const first = AgentToolCall(
      toolId: 'phone.read',
      arguments: <String, String>{'query': '月亮', 'section': 'tarot'},
      reasonTag: 'model_selected',
    );
    const reordered = AgentToolCall(
      toolId: 'phone.read',
      arguments: <String, String>{'section': 'tarot', 'query': '月亮'},
      reasonTag: 'model_selected',
    );
    const changed = AgentToolCall(
      toolId: 'phone.read',
      arguments: <String, String>{'section': 'diary', 'query': '月亮'},
      reasonTag: 'model_selected',
    );
    expect(
      AgentTaskLoopPolicy.callFingerprint(first),
      AgentTaskLoopPolicy.callFingerprint(reordered),
    );
    expect(
      AgentTaskLoopPolicy.callFingerprint(first),
      isNot(AgentTaskLoopPolicy.callFingerprint(changed)),
    );
  });

  test('native replanning rejects an exact repeated call', () {
    const native = DeepSeekToolCall(
      id: 'call-phone',
      name: 'phone_read',
      arguments: '{"section":"tarot","query":"月亮"}',
    );
    final initial = AgentToolPlanner.fromNativeToolCalls(
      const <DeepSeekToolCall>[native],
      latestUserText: '看看你的塔罗记录里有没有月亮',
    );
    expect(initial.calls, hasLength(1));
    final repeated = AgentToolPlanner.fromNativeToolCalls(
      const <DeepSeekToolCall>[native],
      latestUserText: '看看你的塔罗记录里有没有月亮',
      excludedCallFingerprints: <String>{
        AgentTaskLoopPolicy.callFingerprint(initial.calls.single),
      },
    );
    expect(repeated.isEmpty, isTrue);
  });

  test('repeat guard still allows the same tool with a changed query', () {
    const repeated = DeepSeekToolCall(
      id: 'call-repeat',
      name: 'public_web_search',
      arguments: '{"query":"鲸鱼睡眠"}',
    );
    const refined = DeepSeekToolCall(
      id: 'call-refined',
      name: 'public_web_search',
      arguments: '{"query":"鲸鱼半脑睡眠 研究"}',
    );
    const previous = AgentToolCall(
      toolId: 'public_web.search',
      arguments: <String, String>{'query': '鲸鱼睡眠'},
      reasonTag: 'model_selected',
    );
    final plan = AgentToolPlanner.fromNativeToolCalls(
      const <DeepSeekToolCall>[repeated, refined],
      latestUserText: '上网查一下鲸鱼是怎么睡觉的',
      excludedCallFingerprints: <String>{
        AgentTaskLoopPolicy.callFingerprint(previous),
      },
    );
    expect(plan.calls, hasLength(1));
    expect(plan.calls.single.arguments['query'], '鲸鱼半脑睡眠 研究');
  });

  test('remaining global budget can reduce a round to one call', () {
    final plan = AgentToolPlanner.fromNativeToolCalls(
      const <DeepSeekToolCall>[
        DeepSeekToolCall(
          id: 'call-search',
          name: 'phone_search',
          arguments: '{"section":"diary","query":"海边"}',
        ),
        DeepSeekToolCall(
          id: 'call-read',
          name: 'phone_read',
          arguments: '{"section":"diary","query":"海边"}',
        ),
      ],
      latestUserText: '查一下你手机日记里的海边记录并读给我',
      maxCalls: 1,
    );
    expect(plan.calls, hasLength(1));
  });

  test('local verification never upgrades partial or absent outcomes', () {
    final supported = AgentTaskLoopPolicy.verify(
      <AgentToolResult>[result(AgentToolStatus.succeeded)],
    );
    expect(supported.state, AgentTaskVerificationState.supported);
    expect(supported.completionSupported, isTrue);

    final partial = AgentTaskLoopPolicy.verify(<AgentToolResult>[
      result(AgentToolStatus.succeeded),
      result(AgentToolStatus.noResult),
    ]);
    expect(partial.state, AgentTaskVerificationState.partiallySupported);
    expect(partial.completionSupported, isFalse);

    final exhausted = AgentTaskLoopPolicy.verify(
      <AgentToolResult>[result(AgentToolStatus.succeeded)],
      budgetExhausted: true,
    );
    expect(exhausted.state, AgentTaskVerificationState.budgetExhausted);
    expect(exhausted.completionSupported, isFalse);
    expect(exhausted.renderForFinalPrompt(), contains('不能继续假装执行'));
  });

  test('proposal tools remain distinguishable from read-only steps', () {
    const readPlan = AgentToolPlan(calls: <AgentToolCall>[
      AgentToolCall(
        toolId: 'phone.search',
        arguments: <String, String>{'section': 'diary'},
        reasonTag: 'model_selected',
      ),
    ]);
    const sendPlan = AgentToolPlan(calls: <AgentToolCall>[
      AgentToolCall(
        toolId: 'sticker.send',
        arguments: <String, String>{'intent': '开心'},
        reasonTag: 'explicit_request',
      ),
    ]);
    expect(AgentTaskLoopPolicy.containsProposal(readPlan), isFalse);
    expect(AgentTaskLoopPolicy.containsProposal(sendPlan), isTrue);
  });

  test('planning instruction keeps execution bounded and non-reporting', () {
    final prompt = AgentTaskLoopPolicy.planningInstruction(
      completedPlanningRounds: 1,
      completedToolCalls: 2,
    );
    expect(prompt, contains('第 2/3 个规划回合'));
    expect(prompt, contains('不得原样重试同一工具和参数'));
    expect(prompt, contains('不要输出计划'));
    expect(prompt, isNot(contains('**')));
  });
}
