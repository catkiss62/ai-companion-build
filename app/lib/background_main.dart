import 'dart:async';

import 'package:flutter/widgets.dart';

import 'core/ai/deepseek_client.dart';
import 'core/ai/durable_generation_recovery.dart';
import 'core/ai/durable_generation_runner.dart';
import 'core/ai/memory_extractor.dart';
import 'core/database/app_database.dart';
import 'core/desire/desire_engine.dart';
import 'core/desire/proactive_engine.dart';
import 'core/maintenance/recovery_orchestrator.dart';
import 'core/platform/android_bridge.dart';
import 'core/platform/background_chat_command_server.dart';
import 'core/storage/secure_config.dart';

@pragma('vm:entry-point')
Future<void> companionBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.instance;
  final desire = DesireEngine(db);
  final client = DeepSeekClient();
  final proactive = ProactiveEngine(
    db: db,
    desireEngine: desire,
    ai: client,
    android: AndroidBridge.instance,
  );
  final memoryExtractor = MemoryExtractor(
    db: db,
    client: client,
    desireEngine: desire,
  );
  final generationRunner = DurableGenerationRunner(
    db: db,
    client: client,
    secureConfig: SecureConfig.instance,
  );
  final generationRecovery = DurableGenerationRecovery(
    db: db,
    runner: generationRunner,
  );
  final orchestrator = RecoveryOrchestrator(
    db: db,
    generationRecovery: generationRecovery,
    memoryExtractor: memoryExtractor,
    proactive: proactive,
  );
  final wakeGate = _WakeGate();
  final chatCommands = BackgroundChatCommandServer(
    db: db,
    onWake: wakeGate.request,
  );
  chatCommands.start();

  // Give plugins/channels only a brief settling window. Durable recovery should
  // not sit idle for the old unconditional 20-second startup delay.
  await Future<void>.delayed(const Duration(seconds: 2));

  var wakeReason = 'background_engine_start';
  while (true) {
    var interval = const Duration(minutes: 10);
    try {
      final result = await orchestrator.runOnce(wakeReason: wakeReason);
      interval = result.nextDelay;
      await _clearBackgroundErrorSafely(db);
    } catch (error) {
      await _recordBackgroundErrorSafely(db, error);
      interval = const Duration(minutes: 10);
    }
    wakeReason = await wakeGate.wait(interval) ?? 'scheduled';
  }
}

Future<void> _clearBackgroundErrorSafely(AppDatabase db) async {
  try {
    if (!await db.brainWorkAllowed()) return;
    await db.setSetting('last_background_error', '');
  } catch (_) {}
}

Future<void> _recordBackgroundErrorSafely(AppDatabase db, Object error) async {
  try {
    if (!await db.brainWorkAllowed()) return;
    final previous =
        int.tryParse(await db.getSetting('background_error_count') ?? '') ?? 0;
    await db.setSetting('background_error_count', (previous + 1).toString());
    final raw = error.toString();
    await db.setSetting(
      'last_background_error',
      raw.length <= 320 ? raw : raw.substring(0, 320),
    );
  } catch (_) {}
}

class _WakeGate {
  Completer<String?>? _waiter;
  bool _pending = false;
  String _pendingReason = 'native_wake';

  void request(String reason) {
    final normalized = reason.trim().isEmpty ? 'native_wake' : reason.trim();
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(normalized);
      return;
    }
    _pending = true;
    _pendingReason = normalized;
  }

  Future<String?> wait(Duration timeout) async {
    if (_pending) {
      _pending = false;
      return _pendingReason;
    }
    final completer = Completer<String?>();
    _waiter = completer;
    try {
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } finally {
      if (identical(_waiter, completer)) _waiter = null;
    }
  }
}
