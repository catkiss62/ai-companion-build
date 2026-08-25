import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/models/autonomous_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat tools are executable read-only capabilities', () {
    final tools = AgentToolRegistry.userTurnExecutable;
    expect(
      tools.map((tool) => tool.id),
      containsAll(<String>[
        'public_web.search',
        'rules.read',
        'memory.search',
        'device_context.read',
      ]),
    );
    expect(tools.every((tool) => tool.risk == AgentToolRisk.readOnly), isTrue);
    expect(tools.every((tool) => tool.executable), isTrue);
  });

  test('high-risk changes and future MCP remain non-executable', () {
    for (final id in <String>[
      'memory.propose_change',
      'personality.propose_change',
      'rules.propose_change',
      'reminder.schedule',
      'mcp.invoke',
    ]) {
      final tool = AgentToolRegistry.byId(id)!;
      expect(tool.executable, isFalse, reason: id);
      expect(tool.userTurnAvailable, isFalse, reason: id);
    }
  });

  test('autonomous web uses the same registry definition', () {
    expect(
      AgentToolRegistry.definitionForAutonomous(AutonomousToolKind.publicWeb),
      same(AgentToolRegistry.publicWebSearch),
    );
    expect(
      AgentToolRegistry
          .definitionForAutonomous(AutonomousToolKind.screenObservation)
          .id,
      'screen_observation.inspect',
    );
  });
}
