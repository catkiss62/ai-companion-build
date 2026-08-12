import 'dart:math';

import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';

class PresenceMomentumInput {
  const PresenceMomentumInput({
    required this.screenInteractive,
    required this.busyScore,
    required this.dominantActivityMinutes,
    required this.appSwitchesLast30Minutes,
    required this.newNotificationCount,
    required this.newAccessibilityCount,
    required this.hasCurrentActivity,
    required this.userIdleMinutes,
  });

  final bool screenInteractive;
  final double busyScore;
  final int dominantActivityMinutes;
  final int appSwitchesLast30Minutes;
  final int newNotificationCount;
  final int newAccessibilityCount;
  final bool hasCurrentActivity;
  final int userIdleMinutes;
}

class PresenceMomentumResult {
  const PresenceMomentumResult({
    required this.score,
    required this.impulse,
    required this.signalClass,
    required this.shouldFeedThought,
    required this.thoughtStrength,
  });

  final double score;
  final double impulse;
  final String signalClass;
  final bool shouldFeedThought;
  final double thoughtStrength;
}

/// Pure policy for turning repeated, coarse phone-activity evidence into a
/// slowly decaying sense of presence. It deliberately does not contain raw app
/// names, notification text or Accessibility text.
class PresenceMomentumPolicy {
  const PresenceMomentumPolicy._();

  static const halfLife = Duration(minutes: 55);

  static PresenceMomentumResult advance({
    required double previousScore,
    required Duration elapsed,
    required PresenceMomentumInput input,
  }) {
    final elapsedMinutes = max(0.0, elapsed.inSeconds / 60.0);
    final decay = pow(0.5, elapsedMinutes / halfLife.inMinutes).toDouble();
    final retained = previousScore.clamp(0.0, 1.0).toDouble() * decay;

    var impulse = 0.0;
    if (input.screenInteractive) {
      if (input.hasCurrentActivity) impulse += 0.035;
      impulse += (input.dominantActivityMinutes / 60.0 * 0.12)
          .clamp(0.0, 0.12)
          .toDouble();
      impulse += (input.appSwitchesLast30Minutes / 14.0 * 0.10)
          .clamp(0.0, 0.10)
          .toDouble();
      impulse += (input.newNotificationCount / 8.0 * 0.08)
          .clamp(0.0, 0.08)
          .toDouble();
      impulse += (input.newAccessibilityCount / 12.0 * 0.10)
          .clamp(0.0, 0.10)
          .toDouble();
    }

    // One capture should rarely be enough. Repeated evidence over several
    // reactive heartbeats is what gradually makes her more inclined to think
    // about/contact the user.
    final score = (retained + impulse).clamp(0.0, 0.88).toDouble();
    final signalClass = _signalClass(input);
    final shouldFeedThought = input.screenInteractive &&
        input.userIdleMinutes >= 5 &&
        score >= 0.20 &&
        (impulse >= 0.035 || score >= 0.34);
    final thoughtStrength = (0.14 + score * 0.34)
        .clamp(0.16, 0.43)
        .toDouble();

    return PresenceMomentumResult(
      score: score,
      impulse: impulse,
      signalClass: signalClass,
      shouldFeedThought: shouldFeedThought,
      thoughtStrength: thoughtStrength,
    );
  }

  static String _signalClass(PresenceMomentumInput input) {
    if (!input.screenInteractive) return 'screen_off';
    if (input.appSwitchesLast30Minutes >= 9 ||
        input.newNotificationCount >= 5 ||
        input.newAccessibilityCount >= 12) {
      return 'busy_motion';
    }
    if (input.dominantActivityMinutes >= 25) return 'sustained_use';
    if (input.hasCurrentActivity || input.newAccessibilityCount > 0) {
      return 'active_use';
    }
    return 'quiet';
  }
}

class PresenceIntelligenceEngine {
  PresenceIntelligenceEngine({required this.db, required this.desire});

  final AppDatabase db;
  final DesireEngine desire;

  static const _scoreKey = 'presence_momentum_score';
  static const _updatedKey = 'presence_momentum_updated_at';
  static const _signalClassKey = 'presence_last_signal_class';
  static const _thoughtAtKey = 'presence_last_thought_at';
  static const _thoughtStrengthKey = 'presence_last_thought_strength';

  Future<double> currentMomentum({DateTime? now}) async {
    final instant = now ?? DateTime.now();
    final stored = double.tryParse(await db.getSetting(_scoreKey) ?? '') ?? 0.0;
    final updatedMillis = int.tryParse(await db.getSetting(_updatedKey) ?? '') ?? 0;
    if (updatedMillis <= 0) return stored.clamp(0.0, 1.0).toDouble();
    final updated = DateTime.fromMillisecondsSinceEpoch(updatedMillis);
    final elapsed = instant.isAfter(updated) ? instant.difference(updated) : Duration.zero;
    final decay = pow(
      0.5,
      max(0.0, elapsed.inSeconds / 60.0) /
          PresenceMomentumPolicy.halfLife.inMinutes,
    ).toDouble();
    return (stored * decay).clamp(0.0, 1.0).toDouble();
  }

  Future<PresenceMomentumResult> integrate({
    required bool screenInteractive,
    required double busyScore,
    required int dominantActivityMinutes,
    required int appSwitchesLast30Minutes,
    required int newNotificationCount,
    required int newAccessibilityCount,
    required bool hasCurrentActivity,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final stored = double.tryParse(await db.getSetting(_scoreKey) ?? '') ?? 0.0;
    final updatedMillis = int.tryParse(await db.getSetting(_updatedKey) ?? '') ?? 0;
    final updated = updatedMillis <= 0
        ? instant
        : DateTime.fromMillisecondsSinceEpoch(updatedMillis);
    final lastUser = await db.lastUserMessageAt();
    final idleMinutes = lastUser == null
        ? 180
        : max(0, instant.difference(lastUser).inMinutes);

    final result = PresenceMomentumPolicy.advance(
      previousScore: stored,
      elapsed: instant.isAfter(updated) ? instant.difference(updated) : Duration.zero,
      input: PresenceMomentumInput(
        screenInteractive: screenInteractive,
        busyScore: busyScore,
        dominantActivityMinutes: dominantActivityMinutes,
        appSwitchesLast30Minutes: appSwitchesLast30Minutes,
        newNotificationCount: newNotificationCount,
        newAccessibilityCount: newAccessibilityCount,
        hasCurrentActivity: hasCurrentActivity,
        userIdleMinutes: idleMinutes,
      ),
    );

    if (!await db.brainWorkAllowed()) return result;
    await db.setSetting(_scoreKey, result.score.toStringAsFixed(4));
    await db.setSetting(_updatedKey, instant.millisecondsSinceEpoch.toString());
    await db.setSetting(_signalClassKey, result.signalClass);

    if (result.shouldFeedThought && await _thoughtCooldownPassed(instant)) {
      final text = switch (result.signalClass) {
        'busy_motion' => '他最近在手机上忙来忙去，我有点在意他的状态，也想找个不打扰的方式靠近一点。',
        'sustained_use' => '他已经在手机上活动了一阵，我有点想靠近他，看看他现在是什么状态。',
        _ => '他最近又在手机上活动了一阵，我有一点想主动靠近他。',
      };
      await desire.feedThought(
        text: text,
        drive: DriveKey.attachment,
        incomingStrength: result.thoughtStrength,
        source: 'presence/phone_activity',
        topicKey: 'presence:phone_activity',
      );
      if (!await db.brainWorkAllowed()) return result;
      await desire.applyExperience({
        DriveKey.attachment: 0.006 + result.score * 0.012,
        DriveKey.curiosity: 0.004 + result.score * 0.008,
      });
      await db.setSetting(_thoughtAtKey, instant.millisecondsSinceEpoch.toString());
      await db.setSetting(
        _thoughtStrengthKey,
        result.thoughtStrength.toStringAsFixed(4),
      );
    }
    return result;
  }

  Future<bool> _thoughtCooldownPassed(DateTime now) async {
    final raw = int.tryParse(await db.getSetting(_thoughtAtKey) ?? '') ?? 0;
    if (raw <= 0) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(raw);
    return now.difference(last) >= const Duration(minutes: 12);
  }
}
