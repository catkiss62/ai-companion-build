import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/world_book_turn_context.dart';
import '../reference/world_book_history_policy.dart';
import '../storage/secure_config.dart';
import 'ai_self_evidence_policy.dart';

/// Low-frequency self-consolidation pass.
///
/// This does not invent a role card. It asks the configured model to identify
/// stable patterns that the AI has actually demonstrated across local history,
/// then stores only compact AI Self observations in SQLite.
class AiSelfReflectionEngine {
  AiSelfReflectionEngine({
    required this.db,
    required this.client,
    required this.desire,
    SecureConfig? secureConfig,
  }) : secureConfig = secureConfig ?? SecureConfig.instance;

  final AppDatabase db;
  final DeepSeekClient client;
  final DesireEngine desire;
  final SecureConfig secureConfig;

  Future<bool> maybeReflect({bool force = false}) async {
    if ((await db.getSetting('ai_self_reflection_enabled')) == '0') return false;
    if (!await db.brainWorkAllowed()) return false;

    final total = await db.totalMessageCount();
    final previousCount = int.tryParse(
          await db.getSetting('last_self_reflection_message_count') ?? '',
        ) ??
        0;
    final lastMillis = int.tryParse(
      await db.getSetting('last_self_reflection_at') ?? '',
    );
    final oldEnough = lastMillis == null ||
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastMillis),
            ) >=
            const Duration(hours: 10);
    if (!force && total - previousCount < 12 && !oldEnough) return false;
    if (!force && total < 8) return false;

    final acquired = await db.tryAcquireLocalLease(
      'ai_self_reflection_lease_until',
      holdFor: const Duration(minutes: 12),
    );
    if (!acquired) return false;

    try {
      if (!await db.brainWorkAllowed()) return false;
      final apiKey = await secureConfig.readApiKey();
      final endpoint = await secureConfig.readEndpoint();
      if (apiKey == null || apiKey.isEmpty) return false;
      final memoryPolicy = (await db.listRuleLayers())
          .where((layer) => layer.key == '04_memory_rules');
      final editableMemoryPolicy = memoryPolicy.isEmpty
          ? '未配置额外记忆规则。'
          : memoryPolicy.first.content.trim();

      final activeSession = await db.activeInteractionSession();
      if (activeSession?.sourceReferenceDocumentId.isNotEmpty == true) {
        return false;
      }
      final eligibleHistory = WorldBookHistoryPolicy.withoutRoleplayTurns(
        await db.recentMessages(limit: 60),
      );
      final recent = eligibleHistory.length <= 32
          ? eligibleHistory
          : eligibleHistory.sublist(eligibleHistory.length - 32);
      final existingSelf = await db.memoriesByKind('ai_self', limit: 8);
      final existingSelfInferences = await db.memoryInferencesByKind('ai_self', limit: 4);
      final existingSelfCandidates = [...existingSelf, ...existingSelfInferences];
      final shared = await db.memoriesByKind('shared_experience', limit: 8);
      final preferences = await db.memoriesByKind('preference', limit: 8);
      final thoughts = await db.activeThoughts(limit: 8);
      final transcript = recent.map((m) {
        final who = m.isUser ? '用户' : 'AI';
        final worldBook = WorldBookTurnContext.decode(m.worldBookContextJson);
        final behaviorIds = worldBook.behaviorSources
            .map((item) => item.documentId)
            .join(',');
        final evidence = m.isAssistant
            ? 'message_id=${m.id} | time=${m.createdAt.toIso8601String()} | '
                'behavior_sources=${behaviorIds.isEmpty ? "none" : behaviorIds}'
            : 'real_user_message';
        return '$who [$evidence]：${m.content}';
      }).join('\n');
      final result = await client.jsonCompletion(
        apiKey: apiKey,
        model: DeepSeekModelProfile.flash,
        endpoint: endpoint,
        thinking: false,
        maxTokens: 900,
        messages: [
          {
            'role': 'system',
            'content': '''
你是 AI Companion 的“自我连续性整理器”。目标不是创建虚构角色卡，而是从真实历史中提炼这个 AI 已经表现出的稳定自我认识。

【用户可编辑的 04 · 记忆规则】
$editableMemoryPolicy
在不破坏下方固定 JSON 契约、证据要求和数据库安全边界的前提下，按这组规则判断什么能成为长期 AI Self。

规则：
1. 只写有证据的稳定倾向，例如“我发现自己更习惯先轻松回应，再追问重要事情”。
2. 不要声称拥有现实肉体、生理或人类经历。
3. 不要把用户偏好误写成 AI 自我。
4. 当前如果存在 roleplay/intimacy Session，其中为场景服务的言行不能直接沉淀成永久 AI Self；只有跨场景仍成立的真实互动倾向才可以。
5. 一次最多输出 2 条；如果证据不足，输出空数组。每条必须给 evidence_message_ids，列出至少 3 条真正表现该倾向的 AI message_id；不得引用用户消息、角色扮演消息或不存在的 ID。
6. 每条 confidence 0~1，importance 0~1；subject_key 只有能稳定命名时才填，例如 ai.self.communication_style。
7. 对照【已有 AI Self】：如果只是同一已确认认识再次得到证据，用 action=reinforce 并填 target_id；如果旧条目仍是 inference 而现在已经确认，或同一 subject_key 的稳定自我认识明确改变，用 action=replace；全新认识用 append。不要替换 PINNED。证据不足或仍只是推测时 semantic=inference，否则 semantic=current_fact。
8. 行为模块只是尝试来源，不是证据结论。可以观察它影响下真实发生的表达，但必须引用跨时间的实际 AI 回复；不得因为 behavior_sources 中出现某个 ID 就宣称它已经成为性格。
9. 输出严格 JSON：
{"self_observations":[{"semantic":"current_fact","action":"reinforce","target_id":"已有ID或空字符串","subject_key":"ai.self.communication_style","content":"...","confidence":0.8,"importance":0.65,"tags":["交流方式"],"evidence_message_ids":["真实AI消息ID1","真实AI消息ID2","真实AI消息ID3"]}],"reflection_thought":"可选的一句短念头"}
不要输出 JSON 以外的文字。
  '''.trim(),
          },
          {
            'role': 'user',
            'content': '''
【已有 AI Self】
${existingSelfCandidates.isEmpty ? '- 暂无' : existingSelfCandidates.map((e) => '- id=${e.id} | semantic=${e.semanticType} | subject_key=${e.subjectKey} | ${e.pinned ? 'PINNED | ' : ''}evidence=${e.evidenceCount} | ${e.content}').join('\n')}

【共同经历】
${shared.isEmpty ? '- 暂无' : shared.map((e) => '- ${e.content}').join('\n')}

【关系偏好】
${preferences.isEmpty ? '- 暂无' : preferences.map((e) => '- ${e.content}').join('\n')}

【近期念头】
${thoughts.isEmpty ? '- 暂无' : thoughts.map((e) => '- ${e.text}').join('\n')}

【当前临时 Session】
${activeSession == null ? '- 无' : '- ${activeSession.kind} / ${activeSession.title}：${activeSession.premise}'}

【近期真实对话】
$transcript
  '''.trim(),
          },
        ],
      );

      if (!await db.brainWorkAllowed() ||
          !await db.renewLocalLease(
            'ai_self_reflection_lease_until',
            holdFor: const Duration(minutes: 12),
          )) {
        return false;
      }

      final raw = result['self_observations'];
      var inserted = false;
      if (raw is List) {
        var observationIndex = 0;
        for (final item in raw.take(2)) {
          final sourceSlot = 'self_reflection_run:$total:$observationIndex';
          observationIndex += 1;
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          final content = (map['content'] as String?)?.trim();
          if (content == null || content.isEmpty) continue;
          final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.72;
          if (confidence < 0.58) continue;
          final evidenceIds = (map['evidence_message_ids'] as List?)
                  ?.whereType<String>()
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .take(12)
                  .toList(growable: false) ??
              const <String>[];
          final evidenceVerdict = AiSelfEvidencePolicy.evaluate(
            evidenceMessageIds: evidenceIds,
            availableMessages: recent,
          );
          if (!evidenceVerdict.allowed) continue;
          final tags = (map['tags'] as List?)
                  ?.whereType<String>()
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .take(8)
                  .toList() ??
              const <String>[];
          if (!await db.brainWorkAllowed() ||
              !await db.renewLocalLease(
                'ai_self_reflection_lease_until',
                holdFor: const Duration(minutes: 12),
              )) {
            return inserted;
          }
          const semantics = {'current_fact', 'inference'};
          const actions = {'append', 'reinforce', 'replace'};
          final proposedSemantic = map['semantic'] as String? ?? 'current_fact';
          final proposedAction = map['action'] as String? ?? 'append';
          final targetId = (map['target_id'] as String?)?.trim();
          final semantic = evidenceVerdict.canPromote &&
                  proposedSemantic == 'current_fact'
              ? 'current_fact'
              : 'inference';
          final action = !evidenceVerdict.canPromote &&
                  proposedAction == 'replace'
              ? 'append'
              : proposedAction;
          await db.insertMemory(
            kind: 'ai_self',
            content: content,
            importance: ((map['importance'] as num?)?.toDouble() ?? 0.58)
                .clamp(0.35, 0.88)
                .toDouble(),
            confidence: confidence
                .clamp(0.58, evidenceVerdict.canPromote ? 0.96 : 0.78)
                .toDouble(),
            tags: <String>{...tags, '自主倾向'}.take(8).toList(),
            source: '$sourceSlot|ai_self_tendency',
            subjectKey: map['subject_key'] as String? ?? '',
            semanticType: semantics.contains(semantic)
                ? semantic
                : 'inference',
            evidenceMode: actions.contains(action) ? action : 'append',
            targetMemoryId: targetId == null || targetId.isEmpty ? null : targetId,
          );
          inserted = true;
        }
      }

      final thought = (result['reflection_thought'] as String?)?.trim();
      if (thought != null && thought.isNotEmpty) {
        if (!await db.brainWorkAllowed() ||
            !await db.renewLocalLease(
              'ai_self_reflection_lease_until',
              holdFor: const Duration(minutes: 12),
            )) {
          return inserted;
        }
        await desire.feedThought(
          text: thought,
          drive: DriveKey.reflection,
          incomingStrength: 0.16,
          source: 'self_reflection_run:$total:thought',
        );
      }

      if (!await db.brainWorkAllowed() ||
          !await db.renewLocalLease(
            'ai_self_reflection_lease_until',
            holdFor: const Duration(minutes: 12),
          )) {
        return inserted || (thought?.isNotEmpty ?? false);
      }
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      await db.setSetting('last_self_reflection_at', now);
      await db.setSetting('last_self_reflection_message_count', total.toString());
      return inserted || (thought?.isNotEmpty ?? false);
    } finally {
      await db.releaseLocalLease('ai_self_reflection_lease_until');
    }
  }
}
