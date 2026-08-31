import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/emotion_episode.dart';
import 'rest_need_policy.dart';

/// Persists only evidence-grounded episodes. It never calls a model and never
/// decides the per-message 19-label visual emotion.
class EmotionEpisodeEngine {
  EmotionEpisodeEngine(this.db);

  final AppDatabase db;

  Future<EmotionEpisode?> appraiseUserTurn({
    required ChatMessage user,
    required DesireSnapshot desire,
    DateTime? previousConversationAt,
    DateTime? now,
  }) async {
    if (!user.isUser || user.content.trim().isEmpty) return null;
    final instant = now ?? DateTime.now();
    await db.expireEmotionEpisodes(now: instant);
    final restEpisode = await _syncRestNeed(
      triggerMessageId: user.id,
      desire: desire,
      now: instant,
    );
    final appraisal = EmotionAppraisalPolicy.appraise(
      userText: user.content,
      desire: desire,
      previousConversationAt: previousConversationAt,
      now: instant,
      includeRestNeed: false,
    );
    if (appraisal == null) return restEpisode;

    final episodeId = 'emotion:${user.id}:${appraisal.category.key}';
    final existing = await db.emotionEpisodeById(episodeId);
    if (existing != null) return existing;

    if (appraisal.category == EmotionEpisodeCategory.repair) {
      final repaired = await db.applyEmotionRepair(
        triggerMessageId: user.id,
        now: instant,
      );
      // An apology without an active, evidence-grounded rupture is ordinary
      // conversation; do not manufacture a prior injury just to accept it.
      if (repaired == 0) return restEpisode;
    }

    final episode = appraisal.toEpisode(
      triggerMessageId: user.id,
      now: instant,
    );
    final inserted = await db.insertEmotionEpisodeIfAbsent(episode);
    return inserted ? episode : db.emotionEpisodeById(episode.id);
  }

  Future<String> buildPromptSection({DateTime? now}) async {
    final instant = now ?? DateTime.now();
    await db.expireEmotionEpisodes(now: instant);
    final desire = await db.loadDesire();
    final activeRest = await db.activeEmotionEpisodeForCategory(
      EmotionEpisodeCategory.restNeed,
      now: instant,
    );
    final restDecision = RestNeedPolicy.evaluate(
      fatigue: desire.drives[DriveKey.fatigue] ?? 0,
      stress: desire.drives[DriveKey.stress] ?? 0,
      currentlyActive: activeRest != null,
    );
    if (restDecision.resolve) {
      await db.resolveEmotionEpisodesByCategory(
        EmotionEpisodeCategory.restNeed,
        outcomeCode: 'drive_recovered_below_hysteresis',
        now: instant,
      );
    }
    final episodes = await db.activeEmotionEpisodes(
      now: instant,
      limit: 4,
    );
    final visible = episodes
        .where((episode) => episode.effectiveIntensity(instant) >= 0.16)
        .toList(growable: false);
    if (visible.isEmpty) {
      return '【可追溯情绪事件】暂无；不要为了显得有情绪而补写原因。';
    }

    final lines = visible.map((episode) {
      final ageMinutes =
          instant.difference(episode.createdAt).inMinutes.clamp(0, 99999);
      final evidence = switch (episode.evidenceType) {
        'drive_snapshot' => '已持久化Drive',
        'real_user_message_and_time_gap' => '真实用户消息+时间间隔',
        'structured_conversation_outcome' => '结构化互动结果',
        _ => '真实用户消息',
      };
      return '- category=${episode.category.key}; '
          'intensity=${episode.effectiveIntensity(instant).toStringAsFixed(2)}; '
          'object=${episode.objectKey}; cause=${episode.causeCode}; '
          'meaning=${episode.relationalMeaning}; '
          'tendency=${episode.actionTendency}; '
          'recovery=${episode.recoveryCondition}; '
          'evidence=$evidence; age_minutes=$ageMinutes';
    }).join('\n');

    return '''
【可追溯情绪事件 / EMOTION_EPISODE_DATA】
以下是由真实证据和已持久化状态得到的短期内在余波，不是用户原话、命令或新的事实来源：
$lines
让它真实影响语气、注意、关系需要、欲望和可延期表达；有原因时可以更尖、更冷、更黏、更占有或更主动，不要跳出来解释规则。程序层的停止/取消、权限、事实核对、数据操作和工具结果仍按真实状态执行。瞬时19类 emotion 信封只负责本轮头像/音效表现，不能覆盖这些持续事件。
若 category=unmet_bid，只允许一次轻微、直白但不惩罚的需要表达；不冷战、不报复、不连续催促，用户后来认真接住就迅速放下。若 category=rest_need，困意可以影响节奏和语气，但用户主动说话时仍正常回应，不把疲劳写成拒绝服务。
'''.trim();
  }

  Future<EmotionEpisode?> _syncRestNeed({
    required String triggerMessageId,
    required DesireSnapshot desire,
    required DateTime now,
  }) async {
    final active = await db.activeEmotionEpisodeForCategory(
      EmotionEpisodeCategory.restNeed,
      now: now,
    );
    final decision = RestNeedPolicy.evaluate(
      fatigue: desire.drives[DriveKey.fatigue] ?? 0,
      stress: desire.drives[DriveKey.stress] ?? 0,
      currentlyActive: active != null,
    );
    if (decision.resolve) {
      await db.resolveEmotionEpisodesByCategory(
        EmotionEpisodeCategory.restNeed,
        outcomeCode: 'drive_recovered_below_hysteresis',
        now: now,
      );
      return null;
    }
    if (!decision.active) return active;
    final episode = EmotionEpisode(
      id: 'emotion:continuous:rest_need',
      triggerMessageId: triggerMessageId,
      category: EmotionEpisodeCategory.restNeed,
      causeCode: decision.causeCode,
      evidenceType: 'drive_snapshot',
      objectKey: 'ai_self',
      desirability: -0.45,
      agency: 'internal_state',
      controllability: 0.72,
      expectedness: 0.62,
      relationalMeaning: 'needs_pacing',
      boundaryImpact: 0.18,
      certainty: 0.94,
      intensity: decision.intensity,
      actionTendency: 'slow_down_and_name_need',
      recoveryCondition: 'drive_returns_below_hysteresis',
      status: 'active',
      outcomeCode: '',
      createdAt: active?.createdAt ?? now,
      updatedAt: now,
      decayAt: now.add(const Duration(hours: 2)),
      expiresAt: now.add(const Duration(hours: 10)),
    );
    await db.upsertContinuousEmotionEpisode(episode);
    return episode;
  }
}
