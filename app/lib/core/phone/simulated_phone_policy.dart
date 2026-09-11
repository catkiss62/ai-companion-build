import '../models/desire_state.dart';
import '../models/thought.dart';

enum SimulatedPhoneAppKind {
  album,
  browser,
  notes,
  mood,
  wishes,
  diary,
  cart,
  tarot,
}

class SimulatedPhonePolicy {
  const SimulatedPhonePolicy._();

  static const int tarotAssetCount = 22;
  static const int noteDailyLimit = 6;
  static const int noteDayStartMinute = 9 * 60;
  static const int noteDayEndMinute = 24 * 60;
  static const int noteSlotMinutes =
      (noteDayEndMinute - noteDayStartMinute) ~/ noteDailyLimit;
  static const Duration wishAdditionCooldown = Duration(hours: 6);

  static bool updatesAllowed({
    required bool phoneEnabled,
    required SimulatedPhoneAppKind app,
  }) =>
      app == SimulatedPhoneAppKind.tarot || phoneEnabled;

  static String localDay(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static DateTime localDayStart(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String previousLocalDay(DateTime value) => localDay(
        localDayStart(value).subtract(const Duration(days: 1)),
      );

  static int stableIndex(String key, int length, {int salt = 0}) {
    if (length <= 0) return 0;
    var hash = 0x811c9dc5 ^ salt;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash % length;
  }

  static String tarotAssetPath(int index) {
    final safe = index.clamp(0, tarotAssetCount - 1);
    return 'assets/tarot/rws_major/ar' +
        safe.toString().padLeft(2, '0') +
        '.jpg';
  }

  static Map<String, int> moodMetrics(DesireSnapshot desire) {
    double value(DriveKey key) => (desire.drives[key] ?? 0).clamp(0, 1);
    final fatigue = value(DriveKey.fatigue);
    final stress = value(DriveKey.stress);
    final energy =
        ((1 - fatigue) * 62 + (1 - stress) * 38)
            .round()
            .clamp(0, 100)
            .toInt();
    final closeness = (value(DriveKey.attachment) * 100).round();
    final curiosity = (value(DriveKey.curiosity) * 100).round();
    final reserve =
        ((1 - (fatigue > stress ? fatigue : stress)) * 100).round();
    final score =
        (energy * 0.34 + closeness * 0.24 + curiosity * 0.20 + reserve * 0.22)
            .round()
            .clamp(0, 100)
            .toInt();
    return {
      'energy': energy,
      'closeness': closeness,
      'curiosity': curiosity,
      'reserve': reserve,
      'score': score,
    };
  }

  static int? noteSlotIndex(DateTime value) {
    final local = value.toLocal();
    final minute = local.hour * 60 + local.minute;
    if (minute < noteDayStartMinute || minute >= noteDayEndMinute) return null;
    return ((minute - noteDayStartMinute) ~/ noteSlotMinutes)
        .clamp(0, noteDailyLimit - 1)
        .toInt();
  }

  static bool noteOpportunityAllowed({
    required DateTime now,
    required int todayCount,
    required Set<int> attemptedSlots,
    required double fatigue,
  }) {
    final slot = noteSlotIndex(now);
    if (slot == null ||
        todayCount >= noteDailyLimit ||
        attemptedSlots.contains(slot)) {
      return false;
    }
    final tiredness = fatigue.clamp(0.0, 1.0).toDouble();
    if (tiredness >= 0.85) return false;
    // The last evening window is optional when she is already tired. This can
    // only remove an opportunity; it never expands the six-slot hard ceiling.
    if (slot == noteDailyLimit - 1 && tiredness >= 0.65) return false;
    return true;
  }

  static bool wishAdditionAllowed({
    required DateTime now,
    required DateTime? lastAddedAt,
  }) =>
      lastAddedAt == null ||
      now.difference(lastAddedAt) >= wishAdditionCooldown;

  static bool wishEligible({
    required CompanionThought thought,
    required DesireSnapshot desire,
  }) {
    final drive = DriveKey.values.where((item) => item.name == thought.driveKey);
    if (drive.isEmpty) return false;
    final key = drive.first;
    final value = desire.drives[key] ?? 0;
    final baseline = desire.baselines[key] ?? 0;
    final recurring = thought.isFixation ||
        thought.fedCount >= 2 ||
        thought.mergedCount >= 1 ||
        thought.actionCount >= 1;
    final hasObject = thought.topicKey.trim().isNotEmpty || thought.isFixation;
    return thought.canDriveIntent &&
        thought.lastSatisfiedAt == null &&
        thought.strength >= 0.48 &&
        value >= 0.34 &&
        value >= baseline - 0.03 &&
        recurring &&
        hasObject;
  }

  static String wishText(String driveKey) => switch (driveKey) {
        'attachment' => '想和你留下一件以后还会记得的小事',
        'curiosity' => '想认真找点没见过的新鲜东西看看',
        'reflection' => '想把最近一直绕在心里的事慢慢理清楚',
        'duty' => '想把一直挂着的那件事好好做完',
        'social' => '想攒一个真的有趣、值得聊的话题',
        'libido' => '想留一点只属于我们两个人的亲密时间',
        'stress' => '想给脑袋和心情都留一点喘气的空隙',
        'fatigue' => '想找个舒服的时间好好休息一次',
        _ => '想把心里那件还没落地的事完成',
      };

}
