import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/emotion_episode.dart';

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
    final appraisal = EmotionAppraisalPolicy.appraise(
      userText: user.content,
      desire: desire,
      previousConversationAt: previousConversationAt,
      now: instant,
    );
    if (appraisal == null) return null;

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
      if (repaired == 0) return null;
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
'''.trim();
  }
}
