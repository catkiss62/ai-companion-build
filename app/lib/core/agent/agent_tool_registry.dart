import '../models/autonomous_action.dart';
import 'agent_tool.dart';

/// The single capability catalog used by both direct chat work and autonomous
/// Desire actions. A registry entry describes a real capability; it never
/// grants Android permission or turns a prompt-only Skill into executable code.
class AgentToolRegistry {
  const AgentToolRegistry._();

  static const publicWebSearch = AgentToolDefinition(
    id: 'public_web.search',
    title: '搜索公开网页',
    description: '搜索当前公开网页并返回有来源的标题、摘要与网址。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: true,
  );
  static const rulesRead = AgentToolDefinition(
    id: 'rules.read',
    title: '读取当前规则',
    description: '从本地数据库读取六大规则或指定规则，不修改内容。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const memorySearch = AgentToolDefinition(
    id: 'memory.search',
    title: '检索本地记忆',
    description: '按当前问题检索本地长期记忆、历史版本与未完成话题。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const deviceContextRead = AgentToolDefinition(
    id: 'device_context.read',
    title: '查看当前手机状态',
    description: '读取当前 App 名称、屏幕/锁屏状态与粗粒度忙碌度。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const screenObservation = AgentToolDefinition(
    id: 'screen_observation.inspect',
    title: '查看当前屏幕',
    description: '受敏感页 Gate 与独立预算保护的当前屏幕观察。',
    risk: AgentToolRisk.readOnly,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: true,
  );
  static const videoUnderstanding = AgentToolDefinition(
    id: 'video_understanding.inspect',
    title: '理解视频片段',
    description: '后续视频理解能力。',
    risk: AgentToolRisk.readOnly,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: true,
  );
  static const memoryProposal = AgentToolDefinition(
    id: 'memory.propose_change',
    title: '提出记忆修改',
    description: '生成可审查的记忆修改提案；不会直接写入。',
    risk: AgentToolRisk.proposal,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: false,
  );
  static const personalityProposal = AgentToolDefinition(
    id: 'personality.propose_change',
    title: '提出自画像/人设修改',
    description: '生成高风险差异提案，必须由男朋友确认。',
    risk: AgentToolRisk.proposal,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: false,
  );
  static const rulesProposal = AgentToolDefinition(
    id: 'rules.propose_change',
    title: '提出规则修改',
    description: '生成规则差异提案，必须明确确认后才能应用。',
    risk: AgentToolRisk.proposal,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: false,
  );
  static const reminderSchedule = AgentToolDefinition(
    id: 'reminder.schedule',
    title: '设置真实提醒',
    description: '把“半小时后找我”等约定落到 Android 调度。',
    risk: AgentToolRisk.proposal,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: false,
  );
  static const mcpInvoke = AgentToolDefinition(
    id: 'mcp.invoke',
    title: '调用 MCP',
    description: '后续由 MCP Registry 提供的外部能力。',
    risk: AgentToolRisk.privileged,
    executable: false,
    userTurnAvailable: false,
    autonomousAvailable: false,
  );

  static const all = <AgentToolDefinition>[
    publicWebSearch,
    rulesRead,
    memorySearch,
    deviceContextRead,
    screenObservation,
    videoUnderstanding,
    memoryProposal,
    personalityProposal,
    rulesProposal,
    reminderSchedule,
    mcpInvoke,
  ];

  static AgentToolDefinition? byId(String id) {
    for (final definition in all) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static List<AgentToolDefinition> get userTurnExecutable => all
      .where((tool) =>
          tool.executable &&
          tool.userTurnAvailable &&
          tool.risk == AgentToolRisk.readOnly)
      .toList(growable: false);

  static AgentToolDefinition definitionForAutonomous(
    AutonomousToolKind kind,
  ) => switch (kind) {
        AutonomousToolKind.publicWeb => publicWebSearch,
        AutonomousToolKind.screenObservation => screenObservation,
        AutonomousToolKind.videoUnderstanding => videoUnderstanding,
      };
}
