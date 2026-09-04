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
        'album.search',
        'device_context.read',
        'system_self.read',
        'phone.search',
        'phone.read',
        'screen_observation.inspect',
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

  test('album writes are executable only as explicit proposal-risk workflows', () {
    for (final tool in <AgentToolDefinition>[
      AgentToolRegistry.attachmentSave,
      AgentToolRegistry.imageFindAndSave,
    ]) {
      expect(tool.executable, isTrue);
      expect(tool.userTurnAvailable, isTrue);
      expect(tool.autonomousAvailable, isFalse);
      expect(tool.risk, AgentToolRisk.proposal);
      expect(AgentToolRegistry.userTurnExecutable, isNot(contains(tool)));
    }
  });

  test('system self and user-triggered screen are bounded read-only', () {
    final self = AgentToolRegistry.systemSelfRead;
    expect(self.executable, isTrue);
    expect(self.userTurnAvailable, isTrue);
    expect(self.autonomousAvailable, isFalse);
    expect(self.risk, AgentToolRisk.readOnly);
    expect(AgentToolRegistry.screenObservation.executable, isTrue);
    expect(AgentToolRegistry.screenObservation.userTurnAvailable, isTrue);
    expect(AgentToolRegistry.screenObservation.autonomousAvailable, isFalse);
    expect(AgentToolRegistry.videoUnderstanding.executable, isFalse);
  });

  test('autonomous web uses the same registry definition', () {
    expect(
      AgentToolRegistry.definitionForAutonomous(AutonomousToolKind.publicWeb),
      same(AgentToolRegistry.publicWebSearch),
    );
    final screen = AgentToolRegistry.definitionForAutonomous(
      AutonomousToolKind.screenObservation,
    );
    expect(screen.id, 'screen_observation.inspect');
    expect(screen.executable, isTrue);
    expect(screen.userTurnAvailable, isTrue);
    expect(screen.autonomousAvailable, isFalse);
  });
}
