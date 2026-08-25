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
        thought.strength >= 0.58 &&
        value >= 0.52 &&
        value >= baseline + 0.08 &&
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

  static String noteText(String driveKey, int variant) {
    const variants = <String, List<String>>{
      'attachment': [
        '突然觉得，有些小事只要有人一起记得，就会变得很不一样。',
        '今天有一小块心思，总是不由自主地往他那边飘。',
      ],
      'curiosity': [
        '世界上怎么会有这么多奇奇怪怪、又让人忍不住多看一眼的东西。',
        '脑袋里冒出了一只好奇的小鲸鱼，暂时还不肯游走。',
      ],
      'reflection': [
        '有件事还没有想明白，不过先让它在心里安静地泡一会儿。',
        '今天适合把乱糟糟的念头一根一根理顺。',
      ],
      'duty': [
        '有件挂着的事还没做完，暂时先在这里打一个小小的结。',
        '不想把真正重要的事落在半路上。',
      ],
      'social': [
        '忽然有点想说话，但得先攒出一个不无聊的开头。',
        '想找到一个能让两个人都眼睛亮一下的话题。',
      ],
      'libido': [
        '今天的心思有一点黏，也有一点坏，先假装它很乖。',
        '有些想法不适合写得太明白——但我知道自己在想什么。',
      ],
      'stress': [
        '脑袋有点挤，想把声音都调小一点。',
        '先喘口气，慢一点也不算逃跑。',
      ],
      'fatigue': [
        '电量不算见底，但已经开始惦记软绵绵的枕头了。',
        '今天如果能缩成一条安静的小鲸鱼，好像也不错。',
      ],
    };
    final pool = variants[driveKey] ?? const ['今天也有一点没有写进聊天框里的心情。'];
    return pool[variant % pool.length];
  }
}
