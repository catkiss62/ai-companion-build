import '../database/app_database.dart';
import '../platform/android_bridge.dart';
import 'perception_interpreter.dart';

class CurrentDeviceContextCapture {
  const CurrentDeviceContextCapture({
    required this.at,
    required this.deviceState,
    required this.usage,
    required this.recentSignals,
    required this.interpretation,
  });

  final DateTime at;
  final DevicePerceptionState deviceState;
  final List<UsageEventInfo> usage;
  final List<Map<String, Object?>> recentSignals;
  final PerceptionInterpretation interpretation;
}

/// Refreshes only the model-facing, expiring view of the device's current
/// context. It never changes Desire, Thought, Presence Momentum or proactive
/// frequency, so it is safe to run immediately before every model prompt.
///
/// Raw package names and notification/Accessibility text remain temporary
/// local inputs. Only the interpreter's coarse human-level observations are
/// synchronized into Awareness.
class CurrentDeviceContextRefresher {
  CurrentDeviceContextRefresher({
    required this.db,
    required this.android,
    this.interpreter = const PerceptionInterpreter(),
  });

  final AppDatabase db;
  final AndroidBridge android;
  final PerceptionInterpreter interpreter;

  Future<CurrentDeviceContextCapture?> refresh({
    required String reason,
    DateTime? now,
  }) async {
    if (!await db.brainWorkAllowed()) return null;
    if ((await db.getSetting('perception_enabled')) == '0') return null;

    final instant = now ?? DateTime.now();
    try {
      final deviceState = await android.getPerceptionState();
      final usage = deviceState.usageAccess
          ? await android.getRecentUsage(minutes: 90)
          : const <UsageEventInfo>[];
      final recentSignals = await db.recentDeviceEvents(
        minutes: 30,
        limit: 240,
      );
      final deviceStateEvents = await db.recentDeviceStateEvents();
      final interpretation = interpreter.interpret(
        usage: usage,
        recentSignals: recentSignals,
        deviceStateEvents: deviceStateEvents,
        deviceState: deviceState,
        now: instant,
      );

      // A transfer can begin while the Android snapshot is being interpreted.
      // Do not let the old device persist even short-lived Awareness after it
      // has lost Active Brain ownership.
      if (!await db.brainWorkAllowed()) return null;
      await db.syncAwarenessObservations(
        drafts: interpretation.observations,
        managedKeys: interpretation.managedKeys,
        now: instant,
      );
      if (!await db.brainWorkAllowed()) return null;

      final previousCount = int.tryParse(
            await db.getSetting('current_context_refresh_count') ?? '',
          ) ??
          0;
      await db.setSetting(
        'current_context_last_refresh_at',
        instant.millisecondsSinceEpoch.toString(),
      );
      await db.setSetting(
        'current_context_last_refresh_reason',
        _compact(reason, 80),
      );
      await db.setSetting(
        'current_context_refresh_count',
        '${previousCount + 1}',
      );
      await db.setSetting(
        'current_context_screen_interactive',
        deviceState.screenInteractive ? '1' : '0',
      );
      await db.setSetting(
        'current_context_device_locked',
        deviceState.deviceLocked ? '1' : '0',
      );
      await db.setSetting(
        'current_context_busy_score',
        interpretation.busyScore.toStringAsFixed(3),
      );
      await db.setSetting(
        'current_context_current_activity',
        interpretation.currentActivityKey ?? '',
      );
      await db.setSetting(
        'current_context_dominant_activity',
        interpretation.dominantActivityKey ?? '',
      );
      await db.setSetting(
        'current_context_observation_count',
        '${interpretation.observations.length}',
      );
      await db.setSetting('current_context_last_error', '');

      return CurrentDeviceContextCapture(
        at: instant,
        deviceState: deviceState,
        usage: usage,
        recentSignals: recentSignals,
        interpretation: interpretation,
      );
    } catch (error) {
      if (await db.brainWorkAllowed()) {
        await db.setSetting(
          'current_context_last_error',
          'refresh_failed:${error.runtimeType}',
        );
      }
      rethrow;
    }
  }

  String _compact(String value, int max) {
    final normalized = value.trim().isEmpty ? 'unspecified' : value.trim();
    return normalized.length <= max ? normalized : normalized.substring(0, max);
  }
}
