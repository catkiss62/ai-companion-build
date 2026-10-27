import '../models/desire_state.dart';
import '../models/thought.dart';
import 'desire_engine.dart';

/// Extra eligibility for unsolicited night contact, never for user replies,
/// explicit reminders or requested game reports. Scores are motive strengths,
/// not probabilities. Formatting or model-written urgency cannot qualify one.
abstract final class ProactiveNightPolicy {
  static const minimumScore = .78;
  static const restMargin = .04;
  static const freshWindow = Duration(minutes: 20);
  static const currentReachDrives = {
    DriveKey.attachment, DriveKey.social, DriveKey.libido, DriveKey.stress,
  };

  static bool currentSource(CompanionThought thought, DateTime now, DateTime? evidenceAt) {
    final source = thought.source;
    final verifiedDiscovery = source.startsWith('mcp/cedar_game:') ||
        source.startsWith('public_web_candidate:');
    final age = evidenceAt == null ? null : now.difference(evidenceAt);
    return verifiedDiscovery && thought.strength >= .65 && thought.actionCount == 0 &&
        age != null && !age.isNegative && age <= freshWindow;
  }

  static String? blockReason({
    required DesireIntent intent,
    required DesireSnapshot snapshot,
    required double restScore,
    required DateTime now,
    CompanionThought? thought,
    DateTime? evidenceAt,
    DateTime? previousSameContactAt,
  }) {
    final drive = snapshot.drives[intent.drive] ?? 0;
    final baseline = snapshot.baselines[intent.drive] ?? 0;
    if (intent.score < minimumScore || intent.score < restScore + restMargin ||
        drive < .65 || drive - baseline < .18) return 'night_motive_not_strong';
    if (previousSameContactAt != null &&
        (evidenceAt == null || !evidenceAt.isAfter(previousSameContactAt))) {
      return 'night_same_reason_without_new_evidence';
    }
    if (thought == null) {
      return intent.reasonSource == 'drive_state' && currentReachDrives.contains(intent.drive)
          ? null : 'night_no_current_reason';
    }
    // Maintenance can refresh updatedAt/lastFedAt or resurrect a fixation.
    // Only the host-resolved original event time counts as a fresh discovery.
    if (!currentSource(thought, now, evidenceAt)) {
      return 'night_ordinary_or_old_callback';
    }
    return null;
  }

  static const writerContract =
      '这是通过本地强度与休息竞争后的夜间候选，仍须判断此刻是否值得打破休息；通过不代表必须发送。'
      '只围绕选中的当前强烈念头或已核验的新事件，不得换成下午游戏回忆、旧群聊见闻、例行问候或普通追问。'
      '如果内容自然可以留到醒后，就只输出WAIT。不要编造新事件、紧迫性、失眠或强烈情绪来取得发送资格。'
      '允许真实而强烈的想念、亲近或情绪需要，不要求重大事件，也不要求用户立即回复。'
      '发出这一句仍然处于休息时段，不表示已经起床或开始白天活动。';
}
