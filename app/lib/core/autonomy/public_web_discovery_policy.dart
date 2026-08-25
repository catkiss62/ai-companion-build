import '../desire/desire_engine.dart';
import '../models/desire_state.dart';

class PublicWebDiscoveryTopic {
  const PublicWebDiscoveryTopic({
    required this.query,
    required this.interestKey,
  });

  final String query;
  final String interestKey;
}

/// Pure routing policy from an existing Desire Intent to a privacy-safe
/// public-knowledge topic. It never consumes raw Thought or user text.
class PublicWebDiscoveryPolicy {
  const PublicWebDiscoveryPolicy._();

  static const dailyLimit = 4;
  static const budgetWindow = Duration(hours: 24);
  static const candidateTtl = Duration(days: 14);
  static const candidateCap = 240;
  static const minimumIntentScore = 0.60;
  static const wildcardMinimumScore = 0.58;

  static const _topics = <DriveKey, List<String>>{
    DriveKey.curiosity: <String>[
      '宇宙',
      '动物行为',
      '科学史',
      '未来科技',
      '自然现象',
      '人工智能',
    ],
    DriveKey.reflection: <String>[
      '心理学',
      '哲学',
      '文学',
      '艺术史',
      '人类学',
      '记忆',
    ],
    DriveKey.social: <String>[
      '文化习俗',
      '节日',
      '城市生活',
      '音乐史',
      '动画史',
      '游戏史',
    ],
  };

  static bool eligible(DesireIntent intent) {
    if (!_topics.containsKey(intent.drive)) return false;
    final threshold = intent.wantAction == 'wildcard_share'
        ? wildcardMinimumScore
        : minimumIntentScore;
    return intent.score >= threshold;
  }

  static DesireIntent toToolIntent(DesireIntent source) => DesireIntent(
        drive: source.drive,
        score: source.score,
        reason: source.reason,
        wantAction: 'discover_interest',
        thoughtId: source.thoughtId,
        reasonSource: source.reasonSource,
      );

  static PublicWebDiscoveryTopic topicFor({
    required DesireIntent intent,
    required DateTime now,
  }) {
    final choices = _topics[intent.drive] ?? _topics[DriveKey.curiosity]!;
    final sixHourBucket = now.toUtc().hour ~/ 6;
    final dayOrdinal = now.toUtc().difference(DateTime.utc(2020)).inDays;
    final index = (dayOrdinal + sixHourBucket + intent.drive.index) % choices.length;
    final query = choices[index];
    return PublicWebDiscoveryTopic(
      query: query,
      interestKey: "${intent.drive.name}:${index.toString().padLeft(2, '0')}",
    );
  }

  static String dedupeWindow(DateTime now) {
    final utc = now.toUtc();
    final day = '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}';
    return '$day:${utc.hour ~/ 6}';
  }
}
