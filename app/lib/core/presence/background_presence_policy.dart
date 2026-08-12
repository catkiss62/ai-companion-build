/// Pure timing policy for turning coarse Android activity signals into a
/// bounded local companion heartbeat.
///
/// Native Android coalesces signal wakes before they reach Dart. This Dart-side
/// guard is a second layer: a signal wake can advance perception sooner than the
/// normal 7-24 minute heartbeat, but never on every notification/window event.
class BackgroundPresencePolicy {
  const BackgroundPresencePolicy._();

  static const reactivePrefix = 'signal:';
  static const reactivePerceptionMinInterval = Duration(seconds: 90);

  static bool isReactiveWakeReason(String wakeReason) =>
      wakeReason.trim().toLowerCase().startsWith(reactivePrefix);

  static bool shouldAdvanceHeartbeat({
    required String wakeReason,
    required DateTime now,
    required DateTime? lastPerceptionAt,
  }) {
    if (!isReactiveWakeReason(wakeReason)) return false;
    if (lastPerceptionAt == null) return true;
    return now.difference(lastPerceptionAt) >= reactivePerceptionMinInterval;
  }
}
