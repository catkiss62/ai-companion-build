import '../database/app_database.dart';
import '../models/autonomous_action.dart';
import '../platform/android_bridge.dart';
import '../storage/secure_config.dart';
import 'agent_outcome_journal.dart';
import 'agent_tool.dart';
import 'agent_tool_registry.dart';

enum AgentSystemReadScope { capabilities, runtime, recentOutcomes, all }

extension AgentSystemReadScopeKey on AgentSystemReadScope {
  String get key => switch (this) {
        AgentSystemReadScope.capabilities => 'capabilities',
        AgentSystemReadScope.runtime => 'runtime',
        AgentSystemReadScope.recentOutcomes => 'recent_outcomes',
        AgentSystemReadScope.all => 'all',
      };

  static AgentSystemReadScope fromInput(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('recent') ||
        normalized.contains('outcome') ||
        normalized.contains('近期') ||
        normalized.contains('最近') ||
        normalized.contains('做过') ||
        normalized.contains('干了')) {
      return AgentSystemReadScope.recentOutcomes;
    }
    if (normalized.contains('runtime') ||
        normalized.contains('status') ||
        normalized.contains('状态') ||
        normalized.contains('运行')) {
      return AgentSystemReadScope.runtime;
    }
    if (normalized.contains('capabil') ||
        normalized.contains('feature') ||
        normalized.contains('能力') ||
        normalized.contains('功能') ||
        normalized.contains('会什么') ||
        normalized.contains('能做什么')) {
      return AgentSystemReadScope.capabilities;
    }
    return AgentSystemReadScope.all;
  }
}

class AgentSystemCapabilityFact {
  const AgentSystemCapabilityFact({
    required this.id,
    required this.title,
    required this.access,
    required this.state,
    required this.description,
  });

  final String id;
  final String title;
  final String access;
  final String state;
  final String description;
}

class AgentSystemRuntimeFacts {
  const AgentSystemRuntimeFacts({
    required this.activeBrain,
    required this.transferLocked,
    required this.textModelConfigured,
    required this.visionConfigured,
    required this.publicWebEnabled,
    required this.phoneEnabled,
    required this.perceptionEnabled,
    required this.ttsEnabled,
    required this.selfDriveEnabled,
    required this.thoughtLifecycleEnabled,
    required this.aiSelfReflectionEnabled,
    required this.relationshipContinuityEnabled,
    required this.backgroundBrainReady,
    required this.overlayAuthorized,
    required this.overlayRunning,
    required this.usageAuthorized,
    required this.accessibilityAuthorized,
    required this.accessibilityConnected,
    required this.notificationAuthorized,
    required this.notificationConnected,
  });

  final bool activeBrain;
  final bool transferLocked;
  final bool? textModelConfigured;
  final bool? visionConfigured;
  final bool publicWebEnabled;
  final bool phoneEnabled;
  final bool perceptionEnabled;
  final bool ttsEnabled;
  final bool selfDriveEnabled;
  final bool thoughtLifecycleEnabled;
  final bool aiSelfReflectionEnabled;
  final bool relationshipContinuityEnabled;
  final bool? backgroundBrainReady;
  final bool? overlayAuthorized;
  final bool? overlayRunning;
  final bool? usageAuthorized;
  final bool? accessibilityAuthorized;
  final bool? accessibilityConnected;
  final bool? notificationAuthorized;
  final bool? notificationConnected;
}

class AgentSelfReadableOutcome {
  const AgentSelfReadableOutcome({
    required this.capabilityId,
    required this.origin,
    required this.status,
    required this.outcome,
    required this.resultCount,
    required this.occurredAt,
  });

  final String capabilityId;
  final String origin;
  final String status;
  final String outcome;
  final int resultCount;
  final DateTime occurredAt;
}

class AgentSystemSelfSnapshot {
  const AgentSystemSelfSnapshot({
    required this.runtime,
    required this.capabilities,
    required this.outcomes,
  });

  final AgentSystemRuntimeFacts runtime;
  final List<AgentSystemCapabilityFact> capabilities;
  final List<AgentSelfReadableOutcome> outcomes;
}

class AgentSystemFactsPolicy {
  const AgentSystemFactsPolicy._();

  static List<AgentSystemCapabilityFact> capabilities(
    AgentSystemRuntimeFacts runtime,
  ) => <AgentSystemCapabilityFact>[
        AgentSystemCapabilityFact(
          id: 'relationship.continuity',
          title: '持续关系、长期记忆与 AI Self',
          access: 'foundation',
          state: runtime.relationshipContinuityEnabled
              ? (runtime.aiSelfReflectionEnabled
                  ? 'enabled'
                  : 'enabled_reflection_paused')
              : 'continuity_disabled',
          description: '维持关系历史、共同经历、长期记忆和逐渐形成的自我认识。',
        ),
        AgentSystemCapabilityFact(
          id: 'desire.thought',
          title: 'Desire、Thought 与主动联系',
          access: 'foundation',
          state: runtime.selfDriveEnabled && runtime.thoughtLifecycleEnabled
              ? 'enabled'
              : 'partially_disabled',
          description: '形成自己的欲望、念头和联系意图；主动发送仍受节律、疲劳和 Gate 约束。',
        ),
        AgentSystemCapabilityFact(
          id: 'public_web.search',
          title: '公开网页搜索与浏览器记录',
          access: 'chat_tool+autonomous',
          state: runtime.publicWebEnabled
              ? 'chat_and_autonomous_enabled'
              : 'chat_only_autonomous_disabled',
          description: '可在聊天中按要求搜索，也可由真实 Desire 发起受预算保护的公开资料发现。',
        ),
        AgentSystemCapabilityFact(
          id: 'vision.qwen',
          title: '千问识图',
          access: 'chat_tool+background',
          state: _configuredState(runtime.visionConfigured),
          description: '识别用户发来的图片，并为私人相册候选做单图强绑定判断。',
        ),
        AgentSystemCapabilityFact(
          id: 'album.private',
          title: '私人相册与模糊回想',
          access: 'chat_tool+background',
          state: runtime.phoneEnabled ? 'enabled' : 'disabled',
          description: '保存经过判断的正常图片，并在聊天中只读检索保存时的视觉摘要。',
        ),
        AgentSystemCapabilityFact(
          id: 'device.perception',
          title: '手机状态与受控屏幕感知',
          access: 'chat_tool+autonomous',
          state: runtime.perceptionEnabled ? 'enabled' : 'disabled',
          description: '读取当前设备和 App 粗粒度状态；屏幕观察另受敏感页 Gate 与预算保护。',
        ),
        AgentSystemCapabilityFact(
          id: 'overlay.pet',
          title: '悬浮陪伴与桌宠',
          access: 'manual+background',
          state: _connectedState(
            runtime.overlayAuthorized,
            runtime.overlayRunning,
          ),
          description: '由用户在设置中开启；不是聊天工具，运行状态取决于 Android 授权和服务。',
        ),
        AgentSystemCapabilityFact(
          id: 'tts.local',
          title: '本地 TTS 与情绪提示音',
          access: 'manual+background',
          state: runtime.ttsEnabled ? 'enabled' : 'disabled',
          description: '可朗读对白或整段内容；是否自动朗读由当前设置决定。',
        ),
        const AgentSystemCapabilityFact(
          id: 'chat.immersive',
          title: '普通聊天与沉浸房间',
          access: 'foundation',
          state: 'enabled',
          description: '普通聊天用于日常连续关系，沉浸房间用于更长、更深的共同场景。',
        ),
        const AgentSystemCapabilityFact(
          id: 'state.takeover',
          title: '完整状态接管',
          access: 'manual',
          state: 'enabled',
          description: '由用户手动把完整关系状态迁移到另一设备，并维持单一 Active Brain。',
        ),
        const AgentSystemCapabilityFact(
          id: 'state.encrypted_backup',
          title: '非破坏性分卷加密备份',
          access: 'manual',
          state: 'enabled',
          description: '由用户手动创建或恢复 .aibackup；创建后当前设备继续运行。',
        ),
        AgentSystemCapabilityFact(
          id: 'agent.read_tools',
          title: '统一只读 Agent 工具',
          access: 'chat_tool',
          state: _configuredState(runtime.textModelConfigured),
          description: '可读取网页、规则、记忆、相册、设备状态以及当前这份系统事实。',
        ),
        const AgentSystemCapabilityFact(
          id: 'mcp.games',
          title: 'MCP AI 专属小游戏',
          access: 'future',
          state: 'not_implemented',
          description: '尚未接入，当前不能调用、游玩或声称已经产生游戏经历。',
        ),
      ];

  static String buildPrompt({
    required AgentSystemReadScope scope,
    required AgentSystemSelfSnapshot snapshot,
  }) {
    final buffer = StringBuffer('''
已从 App 本地真源按需读取自己的当前系统。下面是可变运行事实，不是人设想象，也不是用户原话。
只能依据列出的事实回答；区分“系统支持”“当前启用/配置/连接”“聊天里能直接调用”“需用户手动操作”“未来尚未实现”。
不要背诵整份技术清单，结合当前问题用第一人称自然概括；没有 Outcome 就不要声称最近做过。不得把这些可变事实自动整理成长期 AI Self 或 Memory。
'''.trim());
    if (scope == AgentSystemReadScope.runtime ||
        scope == AgentSystemReadScope.all) {
      final runtime = snapshot.runtime;
      buffer
        ..writeln('\n\n[SYSTEM_FACT kind=build]')
        ..writeln('app_version=0.40.10+139')
        ..writeln('sqlite_schema=${AppDatabase.schemaVersion}')
        ..writeln('brain_role=${runtime.activeBrain ? 'active' : 'standby'}')
        ..writeln('transfer_locked=${runtime.transferLocked}')
        ..writeln('text_model_configured=${_flag(runtime.textModelConfigured)}')
        ..writeln('vision_configured=${_flag(runtime.visionConfigured)}')
        ..writeln('public_web_autonomous_enabled=${runtime.publicWebEnabled}')
        ..writeln('private_phone_enabled=${runtime.phoneEnabled}')
        ..writeln('perception_enabled=${runtime.perceptionEnabled}')
        ..writeln('tts_enabled=${runtime.ttsEnabled}')
        ..writeln('self_drive_enabled=${runtime.selfDriveEnabled}')
        ..writeln('thought_lifecycle_enabled=${runtime.thoughtLifecycleEnabled}')
        ..writeln('ai_self_reflection_enabled=${runtime.aiSelfReflectionEnabled}')
        ..writeln('relationship_continuity_enabled=${runtime.relationshipContinuityEnabled}')
        ..writeln('background_brain_ready=${_flag(runtime.backgroundBrainReady)}')
        ..writeln('accessibility_authorized=${_flag(runtime.accessibilityAuthorized)}')
        ..writeln('accessibility_connected=${_flag(runtime.accessibilityConnected)}')
        ..writeln('notification_authorized=${_flag(runtime.notificationAuthorized)}')
        ..writeln('notification_connected=${_flag(runtime.notificationConnected)}')
        ..writeln('usage_authorized=${_flag(runtime.usageAuthorized)}');
    }
    if (scope == AgentSystemReadScope.capabilities ||
        scope == AgentSystemReadScope.all) {
      buffer.writeln('\n\n[SYSTEM_FACT kind=capabilities]');
      for (final fact in snapshot.capabilities) {
        buffer.writeln(
          '- id=${fact.id}; title=${fact.title}; access=${fact.access}; '
          'state=${fact.state}; meaning=${fact.description}',
        );
      }
    }
    if (scope == AgentSystemReadScope.recentOutcomes ||
        scope == AgentSystemReadScope.all) {
      buffer.writeln('\n\n[RECENT_AGENT_OUTCOME source=bounded_local_projection]');
      if (snapshot.outcomes.isEmpty) {
        buffer.writeln('- none: 暂无可核对的近期真实行动结果。');
      } else {
        for (final event in snapshot.outcomes.take(8)) {
          buffer.writeln(
            '- capability=${event.capabilityId}; '
            'capability_name=${_capabilityName(event.capabilityId)}; '
            'origin=${event.origin}; '
            'status=${event.status}; outcome=${event.outcome}; '
            'outcome_meaning=${_outcomeMeaning(event.outcome)}; '
            'result_count=${event.resultCount}; '
            'at=${event.occurredAt.toLocal().toIso8601String()}',
          );
        }
      }
    }
    buffer.write('''

[SYSTEM_SELF_READ_PRIVACY]
api_secret=false; endpoint=false; raw_setting=false; database_or_file_path=false; device_id=false; raw_log_or_error=false; tool_argument_or_result_body=false; web_screen_image_notification_chat_thought_body=false
''');
    return buffer.toString().trim();
  }

  static String _configuredState(bool? value) => switch (value) {
        true => 'configured',
        false => 'not_configured',
        null => 'unknown',
      };

  static String _connectedState(bool? authorized, bool? connected) {
    if (authorized == false) return 'not_authorized';
    if (authorized == null || connected == null) return 'unknown';
    return connected ? 'running' : 'authorized_not_running';
  }

  static String _flag(bool? value) => switch (value) {
        true => 'true',
        false => 'false',
        null => 'unknown',
      };

  static String _capabilityName(String id) => switch (id) {
        'public_web.search' => '聊天中搜索公开网页',
        'public_web.autonomous_discovery' => '自主查找公开资料',
        'rules.read' => '读取当前规则',
        'memory.search' => '检索本地记忆',
        'album.search' => '回想已存相册',
        'album.autonomous_review' => '自主识图并决定是否收藏',
        'device_context.read' => '查看当前手机状态',
        'screen_observation.inspect' => '受控查看当前屏幕',
        'video_understanding.inspect' => '受控理解视频片段',
        _ => '已注册能力',
      };

  static String _outcomeMeaning(String value) {
    if (value.startsWith('gate_')) return '被当前安全或运行条件阻止，没有执行成功';
    return switch (value) {
      'completed' => '已经真实完成',
      'candidate_stored' => '已经得到结果并保存为待判断候选',
      'observation_stored' => '已经得到并保存一条观察结果',
      'saved' => '识别与判断后已经收藏到私人相册',
      'no_result' || 'no_useful_result' => '执行完成但没有可用结果',
      'ai_rejected' => '识别后决定不收藏',
      'exact_duplicate' || 'visual_duplicate' => '识别后发现重复，因此没有再次收藏',
      'adult_rejected' => '因相册安全规则没有收藏',
      'blocked' => '被本地边界阻止，没有执行成功',
      'failed' ||
      'provider_failure' ||
      'download' ||
      'image_processing' ||
      'image_binding' ||
      'local_write' =>
        '执行失败；只能说明失败阶段，不能声称已经得到结果',
      'cancelled' => '行动被取消，没有完成',
      _ => '仅有固定结果码；不要推测具体内容',
    };
  }
}

class AgentSystemSelfReader {
  AgentSystemSelfReader({
    required this.db,
    required this.android,
    required this.secureConfig,
  });

  final AppDatabase db;
  final AndroidBridge android;
  final SecureConfig secureConfig;

  Future<AgentToolResult> read({required String requestedScope}) async {
    final scope = AgentSystemReadScopeKey.fromInput(requestedScope);
    await _note('request', scope: scope);
    try {
      final runtime = await _runtimeFacts();
      final outcomes = await _recentOutcomes();
      final snapshot = AgentSystemSelfSnapshot(
        runtime: runtime,
        capabilities: AgentSystemFactsPolicy.capabilities(runtime),
        outcomes: outcomes,
      );
      final prompt = AgentSystemFactsPolicy.buildPrompt(
        scope: scope,
        snapshot: snapshot,
      );
      final resultCount = (scope == AgentSystemReadScope.capabilities
              ? snapshot.capabilities.length
              : scope == AgentSystemReadScope.recentOutcomes
                  ? snapshot.outcomes.length
                  : scope == AgentSystemReadScope.runtime
                      ? 1
                      : snapshot.capabilities.length +
                          snapshot.outcomes.length +
                          1)
          .clamp(0, 1000)
          .toInt();
      await _note('success', scope: scope, resultCount: resultCount);
      return AgentToolResult(
        toolId: AgentToolRegistry.systemSelfRead.id,
        status: AgentToolStatus.succeeded,
        displayText: scope == AgentSystemReadScope.recentOutcomes
            ? '已核对近期真实行动结果'
            : '已读取自己的当前系统',
        promptData: prompt,
        resultCount: resultCount,
      );
    } catch (_) {
      await _note('failed', scope: scope);
      rethrow;
    }
  }

  Future<AgentSystemRuntimeFacts> _runtimeFacts() async {
    Future<bool?> configured(Future<String?> Function() read) async {
      try {
        return (await read())?.trim().isNotEmpty == true;
      } catch (_) {
        return null;
      }
    }

    CapabilityStatus? capability;
    try {
      capability = await android.capabilityStatus();
    } catch (_) {}
    return AgentSystemRuntimeFacts(
      activeBrain: (await db.getSetting('active_brain')) != '0',
      transferLocked: (await db.getSetting('transfer_lock')) == '1',
      textModelConfigured: await configured(secureConfig.readApiKey),
      visionConfigured: await configured(secureConfig.readVisionApiKey),
      publicWebEnabled:
          (await db.getSetting('public_web_discovery_enabled')) != '0',
      phoneEnabled: (await db.getSetting('simulated_phone_enabled')) != '0',
      perceptionEnabled: (await db.getSetting('perception_enabled')) != '0',
      ttsEnabled: (await db.getSetting('tts_enabled')) != '0',
      selfDriveEnabled: (await db.getSetting('self_drive_enabled')) != '0',
      thoughtLifecycleEnabled:
          (await db.getSetting('thought_lifecycle_enabled')) != '0',
      aiSelfReflectionEnabled:
          (await db.getSetting('ai_self_reflection_enabled')) != '0',
      relationshipContinuityEnabled:
          (await db.getSetting('relationship_continuity_enabled')) != '0',
      backgroundBrainReady: capability?.backgroundBrainReady,
      overlayAuthorized: capability?.overlay,
      overlayRunning: capability?.overlayRunning,
      usageAuthorized: capability?.usage,
      accessibilityAuthorized: capability?.accessibility,
      accessibilityConnected: capability?.accessibilityConnected,
      notificationAuthorized:
          capability == null ? null : capability.notificationListener,
      notificationConnected: capability?.notificationListenerConnected,
    );
  }

  Future<List<AgentSelfReadableOutcome>> _recentOutcomes() async {
    final normalized = <AgentSelfReadableOutcome>[];
    final journal = await db.agentOutcomeJournal(limit: 12);
    normalized.addAll(journal.map(_fromJournal));
    final autonomous = await db.recentAutonomousActionRuns(limit: 12);
    normalized.addAll(autonomous.map(_fromAutonomous));
    normalized.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final seen = <String>{};
    return normalized.where((event) {
      final key = '${event.capabilityId}|${event.origin}|${event.status}|'
          '${event.outcome}|${event.occurredAt.millisecondsSinceEpoch}';
      return seen.add(key);
    }).take(8).toList(growable: false);
  }

  static AgentSelfReadableOutcome _fromJournal(AgentOutcomeEvent event) =>
      AgentSelfReadableOutcome(
        capabilityId: event.capabilityId,
        origin: event.origin,
        status: event.status,
        outcome: event.outcome,
        resultCount: event.resultCount,
        occurredAt: event.occurredAt,
      );

  static AgentSelfReadableOutcome _fromAutonomous(AutonomousActionRun run) =>
      AgentSelfReadableOutcome(
        capabilityId: switch (run.tool) {
          AutonomousToolKind.publicWeb => 'public_web.autonomous_discovery',
          AutonomousToolKind.screenObservation =>
            'screen_observation.inspect',
          AutonomousToolKind.videoUnderstanding =>
            'video_understanding.inspect',
        },
        origin: 'autonomous',
        status: run.status.key,
        outcome: run.status == AutonomousActionStatus.blocked
            ? 'gate_${run.gateReason.key}'
            : run.outcome.key,
        resultCount: run.resultCount,
        occurredAt: run.finishedAt ?? run.requestedAt,
      );

  Future<void> _note(
    String outcome, {
    required AgentSystemReadScope scope,
    int resultCount = 0,
  }) async {
    try {
      Future<void> increment(String key) async {
        final current = int.tryParse(await db.getSetting(key) ?? '') ?? 0;
        await db.setSetting(key, '${current + 1}');
      }

      if (outcome == 'request') {
        await increment('system_self_read_request_count');
      } else if (outcome == 'success') {
        await increment('system_self_read_success_count');
      } else {
        await increment('system_self_read_failure_count');
      }
      await db.setSetting('system_self_read_last_outcome', outcome);
      await db.setSetting('system_self_read_last_scope', scope.key);
      await db.setSetting('system_self_read_last_result_count', '$resultCount');
      await db.setSetting(
        'system_self_read_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Diagnostic counters must not make an otherwise valid system read fail.
    }
  }
}
