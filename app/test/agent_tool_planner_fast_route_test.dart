import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary companionship turns bypass the tool planner', () {
    expect(AgentToolPlanner.shouldConsultModel('今天有点累，抱抱我'), isFalse);
    expect(AgentToolPlanner.routeLocally('随便和我聊点什么'), isNull);
  });

  test('explicit web request is routed locally without a second model call', () {
    final plan = AgentToolPlanner.routeLocally('帮我上网搜一下 REDMI K80 Ultra 的公开资料');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.publicWebSearch.id);
    expect(plan.calls.single.arguments['query'], contains('REDMI K80 Ultra'));
  });

  test('explicit rules and device reads become real bounded calls', () {
    final rules = AgentToolPlanner.routeLocally('去看看当前规则02');
    expect(rules!.calls.single.toolId, AgentToolRegistry.rulesRead.id);

    final device = AgentToolPlanner.routeLocally('看看我现在打开的是哪个 App');
    expect(device!.calls.single.toolId, AgentToolRegistry.deviceContextRead.id);
  });

  test('fresh ambiguous facts still consult the bounded model router', () {
    expect(AgentToolPlanner.shouldConsultModel('现在汇率是多少？'), isTrue);
  });
}
