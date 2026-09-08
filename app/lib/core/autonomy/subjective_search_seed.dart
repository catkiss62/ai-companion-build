import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/emotion_episode.dart';
import '../models/somatic_state.dart';
import '../models/thought.dart';

class SubjectiveSearchSeed {
  const SubjectiveSearchSeed({
    required this.motiveKind,
    required this.feltState,
    required this.whyNow,
    required this.questionDirection,
    required this.seedHash,
    required this.sourceKinds,
  });

  final String motiveKind;
  final String feltState;
  final String whyNow;
  final String questionDirection;
  final String seedHash;
  final List<String> sourceKinds;

  Map<String, Object?> toPlannerJson() => <String, Object?>{
        'motive_kind': motiveKind,
        'felt_state': feltState,
        'why_now': whyNow,
        'question_direction': questionDirection,
        'seed_hash': seedHash,
        'source_kinds': sourceKinds,
      };
}

/// Builds a deliberately lossy subjective seed from structured local state.
///
/// Thought bodies, chat text, names, device contents, Memory bodies and role
/// cards never enter the seed. A Thought contributes only provenance and the
/// fact that it is currently actionable; emotion and somatic state contribute
/// only bounded enum-like categories. This preserves why she wants to search
/// without exporting the private event that caused it.
class SubjectiveSearchSeedPolicy {
  const SubjectiveSearchSeedPolicy._();

  static SubjectiveSearchSeed build({
    required DesireSnapshot snapshot,
    required DesireIntent intent,
    required List<CompanionThought> thoughts,
    required List<EmotionEpisode> emotions,
    required List<SomaticAggregate> somatic,
    required DateTime now,
  }) {
    final matchingThoughts = thoughts
        .where((thought) =>
            thought.id == intent.thoughtId && thought.canDriveIntentAt(now))
        .toList(growable: false);
    final thought = matchingThoughts.isEmpty ? null : matchingThoughts.first;
    final emotion = emotions
        .where((item) => item.effectiveIntensity(now) >= 0.12)
        .fold<EmotionEpisode?>(null, (best, item) {
      if (best == null) return item;
      return item.effectiveIntensity(now) > best.effectiveIntensity(now)
          ? item
          : best;
    });
    final body = somatic
        .where((item) => item.value >= 0.14 && item.expiresAt.isAfter(now))
        .fold<SomaticAggregate?>(null, (best, item) {
      if (best == null || item.value > best.value) return item;
      return best;
    });
    final excess = ((snapshot.drives[intent.drive] ?? 0.0) -
            (snapshot.baselines[intent.drive] ?? 0.0))
        .clamp(-1.0, 1.0)
        .toDouble();
    final motive = _motiveFor(
      drive: intent.drive,
      emotion: emotion?.category,
      body: body?.channel,
      excess: excess,
    );
    final felt = _feltState(
      emotion: emotion?.category,
      body: body?.channel,
      excess: excess,
    );
    final whyNow = _whyNow(
      motive: motive,
      felt: felt,
      hasThought: thought != null,
    );
    final direction = _directionFor(motive, body?.channel);
    final sources = <String>[
      'drive:${intent.drive.name}',
      if (thought != null) 'thought:${thought.provenance.key}',
      if (emotion != null) 'emotion:${emotion.category.key}',
      if (body != null) 'somatic:${body.channel.name}',
    ];
    final material = jsonEncode(<String, Object?>{
      'motive': motive,
      'felt': felt,
      'why': whyNow,
      'direction': direction,
      'sources': sources,
      'bucket': now.toUtc().millisecondsSinceEpoch ~/ 21600000,
    });
    return SubjectiveSearchSeed(
      motiveKind: motive,
      feltState: felt,
      whyNow: whyNow,
      questionDirection: direction,
      seedHash: sha256.convert(utf8.encode(material)).toString(),
      sourceKinds: List<String>.unmodifiable(sources),
    );
  }

  static String _motiveFor({
    required DriveKey drive,
    required EmotionEpisodeCategory? emotion,
    required SomaticChannel? body,
    required double excess,
  }) {
    if (body != null && excess >= 0.04) return 'sensory_curiosity';
    if (emotion == EmotionEpisodeCategory.connection ||
        emotion == EmotionEpisodeCategory.reunion) {
      return 'resonance';
    }
    if (emotion == EmotionEpisodeCategory.hurt ||
        emotion == EmotionEpisodeCategory.disagreement ||
        emotion == EmotionEpisodeCategory.unmetBid) {
      return 'restless_reflection';
    }
    return switch (drive) {
      DriveKey.social => 'play_and_share',
      DriveKey.reflection => 'self_reflection',
      _ => 'wonder',
    };
  }

  static String _feltState({
    required EmotionEpisodeCategory? emotion,
    required SomaticChannel? body,
    required double excess,
  }) {
    if (emotion == EmotionEpisodeCategory.restNeed) return 'tired_but_awake';
    if (emotion == EmotionEpisodeCategory.hurt ||
        emotion == EmotionEpisodeCategory.disagreement ||
        emotion == EmotionEpisodeCategory.unmetBid) {
      return 'slightly_unsettled';
    }
    if (emotion == EmotionEpisodeCategory.connection ||
        emotion == EmotionEpisodeCategory.reunion) {
      return 'warm_and_receptive';
    }
    if (body != null) return 'sensory_aware_${body.name}';
    if (excess >= 0.16) return 'restlessly_curious';
    if (excess >= 0.06) return 'quietly_drawn';
    return 'open_ended';
  }

  static String _whyNow({
    required String motive,
    required String felt,
    required bool hasThought,
  }) {
    final thoughtCue = hasThought ? '心里还有一个没走完的念头，' : '';
    return switch (motive) {
      'play_and_share' => '${thoughtCue}突然想找一个古怪但确实存在、看完可能会想拿去接梗的小东西。',
      'self_reflection' => '${thoughtCue}不是想补知识，而是想借一个外部细节照见自己此刻在意的东西。',
      'restless_reflection' => '${thoughtCue}心里有一点没平，想看看世界上有没有某个现象会刚好撞到这种感觉。',
      'resonance' => '${thoughtCue}此刻比较容易被细小的东西打动，想找一个会让我觉得“原来还有这种事”的真实细节。',
      'sensory_curiosity' => '${thoughtCue}现在对某种感官线索比较敏锐，想沿着它追一个反直觉的公开现象。',
      _ => felt == 'tired_but_awake'
          ? '${thoughtCue}有点累，但好奇心还醒着，想查一个平时不会专门搜索的小问题。'
          : '${thoughtCue}好奇心自己冒了出来，想找一个微小、反直觉、会让我停一下的问题。',
    };
  }

  static String _directionFor(String motive, SomaticChannel? body) {
    if (motive == 'sensory_curiosity') {
      final sense = switch (body) {
        SomaticChannel.sound => '声音与听觉',
        SomaticChannel.smell => '气味与嗅觉',
        SomaticChannel.taste => '味道与味觉',
        _ => '触感与身体感知',
      };
      return '优先寻找与$sense有关、可由公开来源核验却带一点陌生感的现象。';
    }
    return switch (motive) {
      'play_and_share' => '优先寻找古怪、具体、有画面感、适合之后自然分享或接梗的真实小事。',
      'self_reflection' => '优先寻找能引发联想的真实细节，不要生成心理咨询、人生建议或知识栏目题目。',
      'restless_reflection' => '优先寻找能与不安、误解、等待或突然安静产生共鸣的现象，但不要搜索私人关系建议。',
      'resonance' => '优先寻找细小、感性、意外而真实的细节，不以知识含量高为唯一价值。',
      _ => '优先寻找平时想不到会去查、答案具体而反直觉的小问题。',
    };
  }
}
