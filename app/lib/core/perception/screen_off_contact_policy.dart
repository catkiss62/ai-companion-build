import 'dart:math';

import '../desire/desire_core_policy.dart';

class ScreenOffContactDecision {
  const ScreenOffContactDecision({
    required this.eligible,
    required this.reason,
    required this.sessionKey,
    this.socialPulse = 0,
    this.thoughtStrength = 0,
    this.nightScale = 0,
  });

  final bool eligible;
  final String reason;
  final String sessionKey;
  final double socialPulse;
  final double thoughtStrength;
  final double nightScale;
}

/// Treats a sustained screen-off period as a bounded contact opportunity.
///
/// Screen-off is not evidence that the user is free, asleep, or available to
/// reply. It only says that the user is not actively operating this screen.
/// One physical screen-off session can therefore create at most one small
/// social pulse; elapsed minutes never accumulate into repeated pulses.
class ScreenOffContactPolicy {
  const ScreenOffContactPolicy._();

  static const minimumOffDuration = Duration(minutes: 90);
  static const maximumSocialPulse = 0.010;

  static ScreenOffContactDecision evaluate({
    required DateTime now,
    required DateTime? screenOffAt,
    required String lastPulsedSessionKey,
    required double currentFatigue,
  }) {
    if (screenOffAt == null || screenOffAt.isAfter(now)) {
      return const ScreenOffContactDecision(
        eligible: false,
        reason: 'screen_off_start_unknown',
        sessionKey: '',
      );
    }
    final sessionKey = screenOffAt.millisecondsSinceEpoch.toString();
    if (lastPulsedSessionKey == sessionKey) {
      return ScreenOffContactDecision(
        eligible: false,
        reason: 'same_screen_off_session',
        sessionKey: sessionKey,
      );
    }
    if (now.difference(screenOffAt) < minimumOffDuration) {
      return ScreenOffContactDecision(
        eligible: false,
        reason: 'minimum_silence_not_reached',
        sessionKey: sessionKey,
      );
    }

    final effectiveFatigue = max(
      currentFatigue,
      DesireCorePolicy.circadianFatigueFloor(now),
    );
    // Daytime fatigue at/below 0.16 keeps full weight. Around 22:00 the
    // contact opportunity is already roughly halved; from about 23:00 through
    // the deep night it approaches, but never mathematically becomes, zero.
    final nightScale = ((0.42 - effectiveFatigue) / 0.26)
        .clamp(0.04, 1.0)
        .toDouble();
    return ScreenOffContactDecision(
      eligible: true,
      reason: 'contact_window_opened',
      sessionKey: sessionKey,
      socialPulse: maximumSocialPulse * nightScale,
      thoughtStrength: 0.26 * nightScale,
      nightScale: nightScale,
    );
  }
}
