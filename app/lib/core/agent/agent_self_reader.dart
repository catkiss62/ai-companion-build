import '../database/app_database.dart';
import '../platform/android_bridge.dart';
import 'agent_tool.dart';
import 'agent_tool_registry.dart';

enum AgentSelfReadScope { facts, outcomes, growth, all }

extension AgentSelfReadScopeKey on AgentSelfReadScope {
  String get key => switch (this) {
        AgentSelfReadScope.facts => 'facts',
        AgentSelfReadScope.outcomes => 'outcomes',
        AgentSelfReadScope.growth => 'growth',
        AgentSelfReadScope.all => 'all',
      };

  static AgentSelfReadScope fromArgument(String value) => switch (
        value.trim().toLowerCase()) {
        'facts' || 'fact' || 'capabilities' => AgentSelfReadScope.facts,
        'outcomes' || 'outcome' || 'recent' => AgentSelfReadScope.outcomes,
        'growth' || 'learning' || 'personality_learning' =>
          AgentSelfReadScope.growth,
        _ => AgentSelfReadScope.all,
      };
}

class AgentSelfReadResult {
  const AgentSelfReadResult({
    required this.promptData,
    required this.factCount,
    required this.outcomeCount,
    this.growthCount = 0,
  });

  final String promptData;
  final int factCount;
  final int outcomeCount;
  final int growthCount;

  int get resultCount => factCount + outcomeCount + growthCount;
}

class AgentSystemFact {
  const AgentSystemFact({
    required this.id,
    required this.title,
    required this.status,
    required this.detail,
  });

  final String id;
  final String title;
  final String status;
  final String detail;
}

class AgentSelfReader {
  AgentSelfReader({
    required this.db,
    required this.android,
  });

  final AppDatabase db;
  final AndroidBridge android;

  static const buildLabel = 'v0.41.15+154';

  static const systemFacts = <AgentSystemFact>[
    AgentSystemFact(
      id: 'local_continuity',
      title: '本地连续性',
      status: 'implemented',
      detail: '聊天、长期记忆、关系、AI Self、Thought、Desire、Emotion 与身体状态保存在本地数据库并持续参与对话。',
    ),
    AgentSystemFact(
      id: 'chat_surfaces',
      title: '聊天与呈现',
      status: 'implemented',
      detail: '支持 App 普通聊天、沉浸房间、原生悬浮聊天、19 类情绪呈现、动作/对白分段与可见思考。',
    ),
    AgentSystemFact(
      id: 'voice_presence',
      title: '本地语音与桌面陪伴',
      status: 'implemented',
      detail: '支持本地 TTS、停止/撤回、主动通知，以及桌宠或悬浮球陪伴；具体权限和系统状态仍以设备实际结果为准。',
    ),
    AgentSystemFact(
      id: 'proactive_web',
      title: '主动联系与公开网页',
      status: 'implemented',
      detail: '主动联系由 Desire/Thought/Intent/Gate 决定；公开网页发现可自主执行并把真实 Outcome 留在本地。',
    ),
    AgentSystemFact(
      id: 'phone_album',
      title: '模拟手机与私人相册',
      status: 'implemented',
      detail: '支持本地浏览器历史、相册保存/检索与模拟手机页面；相册检索读取保存时摘要，不会假装重新看见原图。',
    ),
    AgentSystemFact(
      id: 'backup_transfer',
      title: '完整备份与设备接管',
      status: 'implemented_device_restore_pending',
      detail: '支持完整状态备份、预检、恢复与单 Active Brain 接管；单文件导出已真机验证，破坏性恢复仍待用户选择后验收。',
    ),
    AgentSystemFact(
      id: 'system_self_context',
      title: '系统事实与近期 Outcome',
      status: 'implemented',
      detail: '只有在当前问题需要时，才能只读查看这份能力事实、无正文的近期工具结果和人格学习观察层元数据；不会常驻塞入每轮 Prompt。',
    ),
    AgentSystemFact(
      id: 'one_time_screen_observation',
      title: '用户单次当前屏幕观察',
      status: 'implemented_user_turn_only',
      detail: '用户明确请求时可经敏感页 Gate 截取一张当前屏幕交给视觉模型；截图不保存。自主截屏与 Desire 调度尚未实现。',
    ),
    AgentSystemFact(
      id: 'personality_learning_phase1',
      title: '人格学习观察层',
      status: 'implemented_observation_only',
      detail: '能够从真实用户原话中整理偏好/关系许可候选并记录支持、反证和成熟度；当前候选不进入回复、AI Self、Desire、Moe 或长期习惯，行为影响与 AI 自身习惯阶段尚未开启。',
    ),
  ];

  Future<AgentSelfReadResult> read(
    AgentSelfReadScope scope, {
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final currentDeviceId = await db.ensureDeviceId();
    var currentDeviceLabel = 'Android device';
    try {
      currentDeviceLabel = _oneLine(await android.deviceLabel(), 80);
    } catch (_) {}
    final activeBrain = (await db.getSetting('active_brain')) != '0';
    final since = instant.subtract(const Duration(days: 14));
    final includesOutcomes =
        scope == AgentSelfReadScope.outcomes || scope == AgentSelfReadScope.all;
    final userRows = !includesOutcomes
        ? const <Map<String, Object?>>[]
        : await db.recentAgentToolOutcomes(limit: 12, since: since);
    final autonomousRows = !includesOutcomes
        ? const <Map<String, Object?>>[]
        : await db.recentAutonomousActionOutcomes(limit: 12, since: since);
    final growthStats = scope == AgentSelfReadScope.growth ||
            scope == AgentSelfReadScope.all
        ? await db.personalityLearningDiagnosticStats()
        : const <String, Object?>{};
    return composePromptData(
      scope: scope,
      activeBrain: activeBrain,
      currentDeviceId: currentDeviceId,
      currentDeviceLabel: currentDeviceLabel,
      userRows: userRows,
      autonomousRows: autonomousRows,
      growthStats: growthStats,
    );
  }

  /// Pure formatter kept separate from storage so privacy, ordering and
  /// redaction can be regression-tested without opening the Android database.
  static AgentSelfReadResult composePromptData({
    required AgentSelfReadScope scope,
    required bool activeBrain,
    required String currentDeviceId,
    required String currentDeviceLabel,
    List<Map<String, Object?>> userRows = const <Map<String, Object?>>[],
    List<Map<String, Object?>> autonomousRows = const <Map<String, Object?>>[],
    Map<String, Object?> growthStats = const <String, Object?>{},
  }) {
    final factLines = <String>[];
    if (scope == AgentSelfReadScope.facts || scope == AgentSelfReadScope.all) {
      factLines.add(
        '[SYSTEM_RUNTIME build=$buildLabel schema=${AppDatabase.schemaVersion} '
        'brain=${activeBrain ? 'active' : 'standby'} device=${_field(currentDeviceLabel, 80)}]',
      );
      for (final fact in systemFacts) {
        factLines.add(
          '[SYSTEM_FACT id=${fact.id} status=${fact.status}] '
          '${fact.title}：${fact.detail}',
        );
      }
      for (final tool in AgentToolRegistry.all) {
        final availability = tool.executable ? 'executable' : 'not_implemented';
        factLines.add(
          '[TOOL_CAPABILITY id=${tool.id} status=$availability '
          'user_turn=${tool.userTurnAvailable} autonomous=${tool.autonomousAvailable} '
          'risk=${tool.risk.key}] ${tool.title}：${tool.description}',
        );
      }
    }

    final outcomeLines = <String>[];
    if (scope == AgentSelfReadScope.outcomes ||
        scope == AgentSelfReadScope.all) {
      final outcomes = <AgentRecentOutcome>[
        ...userRows.map(AgentRecentOutcome.fromUserToolRow),
        ...autonomousRows.map(AgentRecentOutcome.fromAutonomousRow),
      ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
      for (final outcome in outcomes.take(8)) {
        final definition = AgentToolRegistry.byId(outcome.toolId);
        final title = definition?.title ?? _fallbackToolTitle(outcome.toolId);
        final sameDevice = outcome.sourceDeviceId.isEmpty ||
            outcome.sourceDeviceId == currentDeviceId;
        final device = sameDevice ? '本机' : '其他设备';
        final origin = _field(outcome.origin, 24);
        final toolId = _field(outcome.toolId, 80);
        final status = _field(outcome.status, 24);
        final outcomeKind = _field(outcome.outcomeKind, 40);
        outcomeLines.add(
          '[RECENT_OUTCOME origin=$origin tool=$toolId '
          'status=$status outcome=$outcomeKind '
          'count=${outcome.resultCount} at=${_localMinute(outcome.finishedAt)} '
          'device=$device] $title',
        );
      }
    }

    final growthLines = <String>[];
    if (scope == AgentSelfReadScope.growth || scope == AgentSelfReadScope.all) {
      final statusCounts = _safeCountMap(growthStats['statusCounts']);
      final latestObservedAt =
          (growthStats['latestObservedAt'] as num?)?.toInt() ?? 0;
      growthLines.add(
        '[GROWTH_RUNTIME phase=observation_only enabled=${growthStats['enabled'] == true}] '
        '候选与证据只用于观察，不进入回复、AI Self、Desire、Moe 或长期习惯。',
      );
      growthLines.add(
        '[GROWTH_COUNTS candidates=${_safeCount(growthStats['candidateCount'])} '
        'evidence=${_safeCount(growthStats['evidenceCount'])} '
        'forming=${statusCounts['forming'] ?? 0} '
        'established=${statusCounts['established'] ?? 0} '
        'contradicted=${statusCounts['contradicted'] ?? 0} '
        'retired=${statusCounts['retired'] ?? 0}]',
      );
      growthLines.add(
        '[GROWTH_LATEST observed_at=${latestObservedAt <= 0 ? 'none' : _localMinute(DateTime.fromMillisecondsSinceEpoch(latestObservedAt))}]',
      );
    }

    final sections = <String>[
      if (factLines.isNotEmpty) '''
【SYSTEM FACTS / 当前系统事实】
这些是 App 代码提供的当前能力元数据。可以据此说明“用户和项目为你做了哪些能力”，但不得声称这些功能是你自己编写的，也不得把未实现工具说成可用。
${factLines.join('\n')}
'''.trim(),
      if (outcomeLines.isNotEmpty || scope == AgentSelfReadScope.outcomes) '''
【RECENT OUTCOMES / 近期真实工具结果】
这些只证明对应工具曾以所列状态结束，不包含当时的搜索词、网页、相册、记忆、规则正文或模型思考。不得补写未提供的具体内容；失败、阻止和无结果必须照实表达。
${outcomeLines.isEmpty ? '最近 14 天没有可读取的 terminal tool Outcome。' : outcomeLines.join('\n')}
'''.trim(),
      if (growthLines.isNotEmpty) '''
【PERSONALITY LEARNING STATUS / 人格学习与成长状态】
这些是本次从本地学习表真实读取的有界元数据，只能据此说明当前 observation-only 阶段、计数、成熟度分布和最近观察时间。结果没有读取任何候选命题、subject、证据原句、用户/AI 消息或模型提案；不得补写“学到了什么”，也不得把一次读取夸大成持续数小时的查看。
${growthLines.join('\n')}
'''.trim(),
      '''
【系统自读边界】
本结果没有读取密钥、API endpoint、原始日志、数据库路径、聊天正文、规则正文、学习候选/证据正文、工具参数、URL、Provider payload 或隐藏 reasoning。自主屏幕观察、视频、修改提案、真实提醒与 MCP 若标记 not_implemented，就只能说尚未实现。
'''.trim(),
    ];
    return AgentSelfReadResult(
      promptData: sections.join('\n\n'),
      factCount: factLines.length,
      outcomeCount: outcomeLines.length,
      growthCount: growthLines.length,
    );
  }

  static String _fallbackToolTitle(String id) => switch (id) {
        'public_web.search' || 'public_web' => '公开网页发现',
        'screen_observation.inspect' || 'screen_observation' => '当前屏幕观察',
        'video_understanding.inspect' || 'video_understanding' => '视频理解',
        _ => '本地工具',
      };

  static String _localMinute(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}T'
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _oneLine(String value, int limit) =>
      _bounded(value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim(), limit);

  static String _field(String value, int limit) =>
      _oneLine(value, limit).replaceAll(RegExp(r'[\[\]=]'), '_');

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit).trimRight();

  static int _safeCount(Object? value) =>
      ((value as num?)?.toInt() ?? 0).clamp(0, 1000000).toInt();

  static Map<String, int> _safeCountMap(Object? value) {
    if (value is! Map) return const <String, int>{};
    return <String, int>{
      for (final entry in value.entries)
        _field(entry.key.toString(), 40): _safeCount(entry.value),
    };
  }
}

class AgentRecentOutcome {
  const AgentRecentOutcome({
    required this.toolId,
    required this.origin,
    required this.status,
    required this.outcomeKind,
    required this.resultCount,
    required this.finishedAt,
    required this.sourceDeviceId,
    required this.sourceDeviceLabel,
  });

  final String toolId;
  final String origin;
  final String status;
  final String outcomeKind;
  final int resultCount;
  final DateTime finishedAt;
  final String sourceDeviceId;
  final String sourceDeviceLabel;

  factory AgentRecentOutcome.fromUserToolRow(Map<String, Object?> row) =>
      AgentRecentOutcome(
        toolId: row['tool_id'] as String? ?? '',
        origin: row['origin'] as String? ?? 'user_turn',
        status: row['status'] as String? ?? 'failed',
        outcomeKind: row['outcome_kind'] as String? ?? '',
        resultCount: (row['result_count'] as num?)?.toInt() ?? 0,
        finishedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['finished_at'] as num?)?.toInt() ?? 0,
        ),
        sourceDeviceId: row['source_device_id'] as String? ?? '',
        sourceDeviceLabel: row['source_device_label'] as String? ?? '',
      );

  factory AgentRecentOutcome.fromAutonomousRow(Map<String, Object?> row) {
    final toolKind = row['tool_kind'] as String? ?? '';
    final toolId = switch (toolKind) {
      'public_web' => AgentToolRegistry.publicWebSearch.id,
      'screen_observation' => AgentToolRegistry.screenObservation.id,
      'video_understanding' => AgentToolRegistry.videoUnderstanding.id,
      _ => toolKind,
    };
    return AgentRecentOutcome(
      toolId: toolId,
      origin: 'autonomous',
      status: row['status'] as String? ?? 'failed',
      outcomeKind: row['outcome_kind'] as String? ?? '',
      resultCount: (row['result_count'] as num?)?.toInt() ?? 0,
      finishedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['finished_at'] as num?)?.toInt() ??
            (row['requested_at'] as num?)?.toInt() ??
            0,
      ),
      sourceDeviceId: row['device_id'] as String? ?? '',
      sourceDeviceLabel: '',
    );
  }
}
