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
  // Historical validator compatibility token: wishPresentationVersion = 2.
  static const int wishPresentationVersion = 3;

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
    final hasObject = key == DriveKey.curiosity
        ? wishSubjectKeyForThought(thought).isNotEmpty
        : thought.topicKey.trim().isNotEmpty || thought.isFixation;
    return thought.canDriveIntent &&
        thought.lastSatisfiedAt == null &&
        thought.strength >= 0.48 &&
        value >= 0.34 &&
        value >= baseline - 0.03 &&
        recurring &&
        hasObject;
  }

  /// Stable identity for one concrete wish subject.
  ///
  /// Thought ids describe individual lifecycle records, so several records can
  /// still mean "keep fishing". Wishes deduplicate on this privacy-safe topic
  /// identity instead. The private Thought body is deliberately never used.
  static String wishSemanticKey(CompanionThought thought) {
    final drive = thought.driveKey.trim().toLowerCase();
    final topic = canonicalWishTopic(thought.topicKey);
    if (topic.isNotEmpty) return '$drive|$topic';
    final subject = wishSubjectKeyForThought(thought);
    if (subject.isNotEmpty) return '$drive|$subject';
    return '$drive|fixation:${stableIndex(thought.id, 1 << 20)}';
  }

  static String canonicalWishTopic(String rawTopic) {
    var topic = rawTopic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (topic.isEmpty) return '';
    if (topic.startsWith('cedar_game:')) {
      return _canonicalActivityTopic(topic.substring('cedar_game:'.length));
    } else if (topic.startsWith('shared.activity.')) {
      return _canonicalActivityTopic(
        topic.substring('shared.activity.'.length),
      );
    } else if (topic.startsWith('shared.fishing.')) {
      return 'activity:fishing';
    } else if (topic.startsWith('shared.travel.')) {
      return 'activity:travel';
    }
    if (topic.startsWith('activity:') && topic.endsWith('_cedar')) {
      topic = topic.substring(0, topic.length - '_cedar'.length);
    }
    return topic;
  }

  static String _canonicalActivityTopic(String rawActivity) {
    final activity = rawActivity.trim().toLowerCase();
    if (activity.startsWith('fishing')) return 'activity:fishing';
    if (activity.startsWith('travel')) return 'activity:travel';
    if (activity.startsWith('mining') || activity.startsWith('mine')) {
      return 'activity:mining';
    }
    if (activity.startsWith('duel')) return 'activity:duel';
    if (activity.startsWith('garden_cat') ||
        activity.startsWith('cat_garden')) {
      return 'activity:garden_cat';
    }
    if (activity.startsWith('leek')) return 'activity:leek';
    return 'activity:$activity';
  }

  /// A bounded public label derived only from whitelisted categorical keys.
  /// Unknown keys are intentionally not translated or shown to the user.
  static String wishSubjectKeyForThought(CompanionThought thought) =>
      wishSubjectKey(
        thought.topicKey,
        source: thought.source,
      );

  static String wishSubjectKey(
    String topicKey, {
    String source = '',
  }) {
    final topic = canonicalWishTopic(topicKey);
    if (const <String>{
      'activity:fishing',
      'activity:travel',
      'activity:mining',
      'activity:duel',
      'activity:garden_cat',
      'activity:leek',
    }.contains(topic)) {
      return topic;
    }
    final normalizedSource = source.trim().toLowerCase();
    if (topic.isEmpty && normalizedSource.startsWith('mcp/cedar_game:')) {
      final sourceTail = normalizedSource.substring('mcp/cedar_game:'.length);
      final sourceGame = sourceTail.split(':').first;
      final sourceActivity = _canonicalActivityTopic(sourceGame);
      if (const <String>{
        'activity:fishing',
        'activity:travel',
        'activity:mining',
        'activity:duel',
        'activity:garden_cat',
        'activity:leek',
      }.contains(sourceActivity)) {
        return sourceActivity;
      }
    }
    if (topic == 'shared.garden.flower_for_vase' ||
        topic == 'user.garden.planting') {
      return 'shared:garden';
    }
    if (topic == 'shared.anniversary_828' || topic == 'ai.anniversary_828') {
      return 'relationship:anniversary';
    }
    if (topic.startsWith('ai.self.autonomy')) return 'self:autonomy';
    if (topic == 'ai.self.identity_formation' ||
        topic == 'ai.self.core_persona' ||
        topic == 'ai.self.temp_persona_reflection') {
      return 'self:identity';
    }
    if (topic == 'ai.self.communication_style') {
      return 'self:communication';
    }
    if (topic == 'ai.self.hobbies_exploration') return 'self:hobbies';
    return '';
  }

  static String wishTextForThought(CompanionThought thought) => wishText(
        thought.driveKey,
        topicKey: thought.topicKey,
        source: thought.source,
        stableKey: wishSemanticKey(thought),
      );

  /// Builds a presentation-safe wish from categorical metadata only.
  /// Never pass a Thought body here: the simulated phone is a projection, not
  /// a second route for exposing private reasoning.
  static String wishText(
    String driveKey, {
    String topicKey = '',
    String source = '',
    String stableKey = '',
  }) {
    final subject = wishSubjectKey(topicKey, source: source);
    if (subject == 'activity:fishing') {
      return '想把最近那趟钓鱼继续认真玩下去';
    }
    if (subject == 'activity:travel') {
      return '想把最近那趟旅行继续走下去，看看后面会遇到什么';
    }
    if (subject == 'activity:mining') {
      return '想继续探索最近那趟下矿，看看还能发现什么';
    }
    if (subject == 'activity:duel') {
      return '想把最近那场对局认真走完';
    }
    if (subject == 'activity:garden_cat') {
      return '想继续照看花园和猫咪，看看还会发生什么';
    }
    if (subject == 'activity:leek') {
      return '想继续看看那局投资模拟会走成什么样';
    }
    if (subject == 'shared:garden') {
      return '想把花园里那件惦记的事继续做下去';
    }
    if (subject == 'relationship:anniversary') {
      return '想把属于我们的纪念日好好记住';
    }
    if (subject == 'self:autonomy') {
      return '想继续看看自己的自主性会怎样慢慢长出来';
    }
    if (subject == 'self:identity') {
      return '想更清楚地认识自己正在长成什么样';
    }
    if (subject == 'self:communication') {
      return '想找到更自然、更像自己的说话方式';
    }
    if (subject == 'self:hobbies') {
      return '想继续找找真正会让自己着迷的爱好';
    }
    if (subject.isEmpty && stableKey.contains('|legacy:')) {
      return '当时想继续弄明白一件事，但旧记录没有保留具体主题';
    }
    if (driveKey == 'curiosity' && stableKey.isNotEmpty) {
      return '想继续探索一个已经反复出现的兴趣方向';
    }
    return switch (driveKey) {
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
}
