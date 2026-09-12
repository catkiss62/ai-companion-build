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
    autonomousAvailable: false,
  );
  static const rulesRead = AgentToolDefinition(
    id: 'rules.read',
    title: '读取当前规则',
    description: '从本地数据库读取七大规则或指定规则，不修改内容。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: true,
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
  static const albumSearch = AgentToolDefinition(
    id: 'album.search',
    title: '回想已存相册',
    description: '按当前问题模糊检索她已经保存的本地相册内容，不读取图片文件且不修改相册。',
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
  static const systemSelfRead = AgentToolDefinition(
    id: 'system_self.read',
    title: '读取自身系统事实',
    description: '只读查看当前真实能力、未实现边界与无正文的近期工具 Outcome。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const phoneSearch = AgentToolDefinition(
    id: 'phone.search',
    title: '搜索自己的手机',
    description: '只读搜索查手机中的日记、随笔、心情、愿望、购物车、塔罗、浏览器和相册，不触发刷新或已读。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const phoneRead = AgentToolDefinition(
    id: 'phone.read',
    title: '读取自己的手机内容',
    description: '按栏目、条目句柄或关键词只读取得一条查手机内容，不生成新内容、不标记已读。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const attachmentSave = AgentToolDefinition(
    id: 'attachment.save',
    title: '保存用户当前图片',
    description: '仅在用户本轮明确要求时，确认同一条图片附件已由唯一相册写入链保存；不猜测成功。',
    risk: AgentToolRisk.proposal,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const imageFindAndSave = AgentToolDefinition(
    id: 'image.find_and_save',
    title: '联网找图并保存',
    description: '仅按用户本轮明确命令，搜索带图片的公开候选、识别同一图片并把同一缩略图保存到私有相册。',
    risk: AgentToolRisk.proposal,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const stickerSend = AgentToolDefinition(
    id: 'sticker.send',
    title: '发送本地表情包',
    description: '仅按用户本轮明确要求，从已启用的内部表情图库选择一张真实图片作为整条回复，不附带对白；不会写入查手机相册。',
    risk: AgentToolRisk.proposal,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const webImageSend = AgentToolDefinition(
    id: 'image.web_send',
    title: '联网寻找并发送图片',
    description: '仅按用户本轮明确要求，搜索公开图片、下载同一候选并经像素核验后随当前回复发送；不保存到她的相册。',
    risk: AgentToolRisk.proposal,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const albumImageSend = AgentToolDefinition(
    id: 'album.image_send',
    title: '发送已存相册图片',
    description: '仅按用户本轮明确要求，从她已保存的本地相册中语义匹配一张真实图片随当前回复发送；不联网识图、不改相册。',
    risk: AgentToolRisk.proposal,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const screenObservation = AgentToolDefinition(
    id: 'screen_observation.inspect',
    title: '查看当前屏幕',
    description: '仅在用户本轮明确请求时，经敏感页 Gate 截取一次当前屏幕并临时识图；不保存截图。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: false,
  );
  static const cedarToyListGames = AgentToolDefinition(
    id: 'cedar_toy.list_games',
    title: '读取 Cedar Toy 游戏列表',
    description: '从 Cedar Toy MCP 取得此刻真实游戏列表；网络请求不是模型调用。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: true,
  );
  static const cedarToyGetGuide = AgentToolDefinition(
    id: 'cedar_toy.get_guide',
    title: '读取 Cedar Toy 游戏指南',
    description: '只为真实列表中的一个游戏取得远端指南。',
    risk: AgentToolRisk.readOnly,
    executable: true,
    userTurnAvailable: true,
    autonomousAvailable: true,
  );
  static const cedarToyPlay = AgentToolDefinition(
    id: 'cedar_toy.play',
    title: '游玩 Cedar Toy 游戏',
    description: '仅按完整真实指南中的动作调用远端游戏，并返回真实 Outcome。',
    risk: AgentToolRisk.proposal,
    executable: true,
    userTurnAvailable: true,
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
    albumSearch,
    deviceContextRead,
    systemSelfRead,
    phoneSearch,
    phoneRead,
    attachmentSave,
    imageFindAndSave,
    stickerSend,
    webImageSend,
    albumImageSend,
    screenObservation,
    cedarToyListGames,
    cedarToyGetGuide,
    cedarToyPlay,
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

  /// Executable tools that may be described to the model for a narrowly
  /// matched current request. Proposal-risk tools remain hidden from ordinary
  /// chat and still require an explicit local intent check before execution.
  static List<AgentToolDefinition> get userTurnModelCallable => all
      .where((tool) => tool.executable && tool.userTurnAvailable)
      .toList(growable: false);

  static AgentToolDefinition definitionForAutonomous(
    AutonomousToolKind kind,
  ) => switch (kind) {
        AutonomousToolKind.publicWeb => publicWebSearch,
        AutonomousToolKind.screenObservation => screenObservation,
        AutonomousToolKind.videoUnderstanding => videoUnderstanding,
      };
}
