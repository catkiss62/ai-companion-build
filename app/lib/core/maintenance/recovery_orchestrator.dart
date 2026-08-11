import 'dart:math';

import '../ai/durable_generation_recovery.dart';
import '../ai/memory_extractor.dart';
import '../database/app_database.dart';
import '../desire/proactive_engine.dart';
import '../models/desire_state.dart';

class RecoveryCycleResult {
  const RecoveryCycleResult({
    required this.state,
    required this.nextDelay,
    this.generationRecovered = false,
    this.proactiveReason = '',
    this.heartbeatAdvanced = false,
  });

  final String state;
  final Duration nextDelay;
  final bool generationRecovered;
  final String proactiveReason;
  final bool heartbeatAdvanced;
}

/// Coordinates durable recovery queues. Queue polling and the companion's
/// inner-life heartbeat deliberately use separate clocks: a job retry due in a
/// few seconds must never make Desire/Thought tick at that same frequency.
class RecoveryOrchestrator {
  RecoveryOrchestrator({
    required this.db,
    required this.generationRecovery,
    required this.memoryExtractor,
    required this.proactive,
    Random? random,
  }) : _random = random ?? Random();

  final AppDatabase db;
  final DurableGenerationRecovery generationRecovery;
  final MemoryExtractor memoryExtractor;
  final ProactiveEngine proactive;
  final Random _random;

  static const _orchestratorLease = 'recovery_orchestrator_lease_until';
  static const _nextHeartbeatKey = 'recovery_orchestrator_next_heartbeat_at';

  Future<RecoveryCycleResult> runOnce({
    String wakeReason = 'scheduled',
    bool allowProactive = true,
  }) async {
    await db.ensureReady();
    if (!await db.brainWorkAllowed()) {
      return const RecoveryCycleResult(
        state: 'inactive_brain',
        nextDelay: Duration(minutes: 10),
      );
    }
    final acquired = await db.tryAcquireLocalLease(
      _orchestratorLease,
      holdFor: const Duration(minutes: 6),
    );
    if (!acquired) {
      return const RecoveryCycleResult(
        state: 'orchestrator_busy',
        nextDelay: Duration(seconds: 8),
      );
    }

    final startedAt = DateTime.now();
    try {
      await _markStarted(startedAt, wakeReason);
      final generationRecovered = await generationRecovery.recoverOne();
      await _guardOrchestratorOwnership();
      await memoryExtractor.drainPending(
        retryIfBusy: false,
        maxJobs: 2,
      );
      await _guardOrchestratorOwnership();

      final now = DateTime.now();
      final blocking = await db.blockingGenerationJob();
      final heartbeatDue = await _heartbeatIsDue(now);
      var heartbeatAdvanced = false;
      var proactiveReason = '';
      Duration heartbeatDelay;

      if (heartbeatDue) {
        if (blocking != null || !allowProactive) {
          final heartbeat = await proactive.maintainLocalStateOnly();
          if (heartbeat == null) {
            heartbeatDelay = const Duration(seconds: 30);
          } else {
            heartbeatAdvanced = true;
            heartbeatDelay = _nextHeartbeat(heartbeat.snapshot, _random);
            await _storeNextHeartbeat(now.add(heartbeatDelay));
            proactiveReason = blocking != null
                ? 'local_heartbeat_while_generation_waits'
                : 'proactive_disabled_for_cycle';
          }
        } else {
          final decision = await proactive.evaluate();
          proactiveReason = decision.reason;
          if (decision.reason == '主动心跳正在由另一引擎处理' ||
              decision.reason == '用户正在与我聊天') {
            heartbeatDelay = const Duration(seconds: 30);
          } else {
            heartbeatAdvanced = true;
            final snapshot = await db.loadDesire();
            heartbeatDelay = _nextHeartbeat(snapshot, _random);
            await _storeNextHeartbeat(now.add(heartbeatDelay));
          }
        }
      } else {
        heartbeatDelay = await _remainingHeartbeatDelay(now);
      }

      await _guardOrchestratorOwnership();
      final postTurnDelay = await _nextPostTurnDelay();
      late Duration nextDelay;
      late String state;
      if (blocking != null) {
        final generationDelay = await db.nextGenerationRecoveryDelay();
        nextDelay = _smallestDelay(
          heartbeatDelay,
          generationDelay,
          postTurnDelay,
        );
        state = heartbeatAdvanced
            ? 'waiting_generation:${blocking.status}:heartbeat'
            : 'waiting_generation:${blocking.status}';
      } else {
        nextDelay = _smallestDelay(heartbeatDelay, postTurnDelay);
        state = heartbeatAdvanced ? 'idle:heartbeat' : 'idle';
      }

      nextDelay = _boundedDelay(nextDelay);
      await _markCompleted(
        state: state,
        wakeReason: wakeReason,
        nextDelay: nextDelay,
        proactiveReason: proactiveReason,
      );
      return RecoveryCycleResult(
        state: state,
        nextDelay: nextDelay,
        generationRecovered: generationRecovered,
        proactiveReason: proactiveReason,
        heartbeatAdvanced: heartbeatAdvanced,
      );
    } on _RecoveryOrchestratorOwnershipLost {
      return const RecoveryCycleResult(
        state: 'orchestrator_ownership_lost',
        nextDelay: Duration(seconds: 8),
      );
    } catch (error) {
      await _markFailed(error, wakeReason);
      rethrow;
    } finally {
      await db.releaseLocalLease(_orchestratorLease);
    }
  }

  Future<void> _guardOrchestratorOwnership() async {
    if (!await db.brainWorkAllowed()) {
      throw const _RecoveryOrchestratorOwnershipLost();
    }
    final renewed = await db.renewLocalLease(
      _orchestratorLease,
      holdFor: const Duration(minutes: 6),
    );
    if (!renewed) throw const _RecoveryOrchestratorOwnershipLost();
  }

  Future<bool> _heartbeatIsDue(DateTime now) async {
    final raw = int.tryParse(await db.getSetting(_nextHeartbeatKey) ?? '') ?? 0;
    return raw <= 0 || raw <= now.millisecondsSinceEpoch;
  }

  Future<Duration> _remainingHeartbeatDelay(DateTime now) async {
    final raw = int.tryParse(await db.getSetting(_nextHeartbeatKey) ?? '') ?? 0;
    if (raw <= 0) return Duration.zero;
    final at = DateTime.fromMillisecondsSinceEpoch(raw);
    return at.isAfter(now) ? at.difference(now) : Duration.zero;
  }

  Future<void> _storeNextHeartbeat(DateTime at) async {
    if (!await db.renewLocalLease(
      _orchestratorLease,
      holdFor: const Duration(minutes: 6),
    )) return;
    await db.setSetting(_nextHeartbeatKey, at.millisecondsSinceEpoch.toString());
  }

  Future<Duration?> _nextPostTurnDelay() async {
    if (await db.isLocalLeaseHeld('post_turn_memory_lease')) {
      return const Duration(seconds: 30);
    }
    return db.nextPostTurnRecoveryDelay();
  }

  Future<void> _markStarted(DateTime startedAt, String wakeReason) async {
    if (!await db.renewLocalLease(
      _orchestratorLease,
      holdFor: const Duration(minutes: 6),
    )) return;
    await db.setSetting(
      'recovery_orchestrator_last_started_at',
      startedAt.millisecondsSinceEpoch.toString(),
    );
    await db.setSetting('recovery_orchestrator_state', 'running');
    await db.setSetting(
      'recovery_orchestrator_last_wake_reason',
      _compact(wakeReason, 120),
    );
  }

  Future<void> _markCompleted({
    required String state,
    required String wakeReason,
    required Duration nextDelay,
    required String proactiveReason,
  }) async {
    if (!await db.renewLocalLease(
      _orchestratorLease,
      holdFor: const Duration(minutes: 6),
    )) return;
    final now = DateTime.now();
    final count = int.tryParse(
          await db.getSetting('recovery_orchestrator_cycle_count') ?? '',
        ) ??
        0;
    await db.setSetting('recovery_orchestrator_cycle_count', '${count + 1}');
    await db.setSetting(
      'recovery_orchestrator_last_completed_at',
      now.millisecondsSinceEpoch.toString(),
    );
    await db.setSetting('recovery_orchestrator_state', state);
    await db.setSetting(
      'recovery_orchestrator_last_wake_reason',
      _compact(wakeReason, 120),
    );
    await db.setSetting('recovery_orchestrator_last_error', '');
    await db.setSetting(
      'recovery_orchestrator_next_wake_at',
      now.add(nextDelay).millisecondsSinceEpoch.toString(),
    );
    await db.setSetting(
      'recovery_orchestrator_last_proactive_reason',
      _compact(proactiveReason, 220),
    );
  }

  Future<void> _markFailed(Object error, String wakeReason) async {
    if (!await db.brainWorkAllowed()) return;
    if (!await db.renewLocalLease(
      _orchestratorLease,
      holdFor: const Duration(minutes: 2),
    )) return;
    final now = DateTime.now();
    await db.setSetting('recovery_orchestrator_state', 'error');
    await db.setSetting(
      'recovery_orchestrator_last_completed_at',
      now.millisecondsSinceEpoch.toString(),
    );
    await db.setSetting(
      'recovery_orchestrator_last_wake_reason',
      _compact(wakeReason, 120),
    );
    await db.setSetting(
      'recovery_orchestrator_last_error',
      _compact(error.toString(), 360),
    );
    await db.setSetting(
      'recovery_orchestrator_next_wake_at',
      now.add(const Duration(minutes: 10)).millisecondsSinceEpoch.toString(),
    );
  }

  Duration _smallestDelay(Duration fallback, [Duration? a, Duration? b]) {
    var result = fallback;
    if (a != null && a < result) result = a;
    if (b != null && b < result) result = b;
    return result;
  }

  Duration _boundedDelay(Duration wait) {
    if (wait < const Duration(seconds: 5)) return const Duration(seconds: 5);
    if (wait > const Duration(minutes: 24)) return const Duration(minutes: 24);
    return wait;
  }

  String _compact(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);
}

class _RecoveryOrchestratorOwnershipLost implements Exception {
  const _RecoveryOrchestratorOwnershipLost();
}

Duration _nextHeartbeat(DesireSnapshot snapshot, Random random) {
  final fatigue = snapshot.drives[DriveKey.fatigue] ?? 0.0;
  final strongestNonFatigue = DriveKey.values
      .where((d) => d != DriveKey.fatigue)
      .map((d) => snapshot.drives[d] ?? 0.0)
      .fold<double>(0.0, max);
  var minutes = 18.0 - strongestNonFatigue * 10.0 + fatigue * 8.0;
  minutes += (random.nextDouble() - 0.5) * 4.0;
  minutes = minutes.clamp(7.0, 24.0).toDouble();
  return Duration(seconds: (minutes * 60).round());
}
