#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert any(v in pubspec for v in ['version: 0.30.0+36', 'version: 0.30.1+37', 'version: 0.30.2+38', 'version: 0.30.3+39', 'version: 0.31.0+40', 'version: 0.31.1+41'])

    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    assert 'static const int schemaVersion = 18;' in db

    main_dart = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
    assert "import 'background_main.dart' as background_runtime;" in main_dart
    assert "@pragma('vm:entry-point')" in main_dart
    assert 'Future<void> companionBackgroundMain() =>' in main_dart
    assert 'background_runtime.companionBackgroundMain();' in main_dart

    server = (ROOT / 'lib/core/platform/background_chat_command_server.dart').read_text(encoding='utf-8')
    for token in ["'backgroundDartReady'", "case 'overlayOpened':", "case 'sendMessage':", 'db.recentMessages(limit: 8)']:
        assert token in server, token

    overlay = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    assign = overlay.index('backgroundEngine = createdEngine')
    execute = overlay.index('createdEngine.dartExecutor.executeDartEntrypoint(entrypoint)')
    assert assign < execute, 'engine identity must be published before Dart starts'
    for token in [
        'if (chatExpanded) {',
        'refreshOverlayMessages(opened = true, attempt = 0)',
        'if (!backgroundBrainReady)',
        'setChatStatus("正在连接后台大脑…")',
        'SIGNAL_WAKE_MIN_INTERVAL_MS = 90_000L',
        'fun requestSignalBrainWake(context: Context, reason: String): Boolean',
        'requestBrainWake(context, "signal:${reason.take(80)}")',
        'requestSignalBrainWake(this@OverlayBubbleService, "device_present")',
    ]:
        assert token in overlay, token

    notification = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NotificationBridgeService.kt').read_text(encoding='utf-8')
    assert 'requestSignalBrainWake(this, "notification")' in notification
    # Wake reason must stay coarse; private notification title/text are only in NativeEventStore.
    assert 'requestSignalBrainWake(this, summary)' not in notification
    assert 'requestSignalBrainWake(this, sourcePackage)' not in notification

    accessibility = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt').read_text(encoding='utf-8')
    assert 'AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED' in accessibility
    assert 'requestSignalBrainWake(this, "accessibility_window")' in accessibility
    assert 'requestSignalBrainWake(this, sanitized)' not in accessibility
    assert 'requestSignalBrainWake(this, sourcePackage)' not in accessibility

    policy = (ROOT / 'lib/core/presence/background_presence_policy.dart').read_text(encoding='utf-8')
    assert "reactivePrefix = 'signal:'" in policy
    assert 'reactivePerceptionMinInterval = Duration(seconds: 90)' in policy
    assert 'shouldAdvanceHeartbeat' in policy

    perception = (ROOT / 'lib/core/perception/perception_engine.dart').read_text(encoding='utf-8')
    assert 'Duration minInterval = const Duration(minutes: 4)' in perception
    assert 'now.difference(last) < minInterval' in perception

    proactive = (ROOT / 'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    assert proactive.count('Duration perceptionMinInterval = const Duration(minutes: 4)') >= 3
    assert 'minInterval: perceptionMinInterval' in proactive
    # Existing anti-spam and fencing must survive the reactive path.
    for token in [
        "db.getSetting('transfer_lock')",
        "db.isLocalLeaseHeld('chat_turn_lease')",
        'sentToday >= 8',
        'sentLastTwoHours >= 2',
        'busyMultiplier = userBusy ? 0.72 : 1.0',
        'gateScore < threshold',
    ]:
        assert token in proactive, token

    orchestrator = (ROOT / 'lib/core/maintenance/recovery_orchestrator.dart').read_text(encoding='utf-8')
    for token in [
        "import '../presence/background_presence_policy.dart';",
        'scheduledHeartbeatDue',
        'reactiveHeartbeatDue',
        'BackgroundPresencePolicy.reactivePerceptionMinInterval',
        '_reactiveHeartbeatIsDue',
        'last_perception_capture_at',
    ]:
        assert token in orchestrator, token

    diagnostics = (ROOT / 'lib/core/diagnostics/preflight_diagnostics.dart').read_text(encoding='utf-8')
    for token in [
        "id: 'background_brain'",
        "title: '后台大脑连接'",
        "'backgroundPresence': {",
        "'lastWakeReason'",
        "'lastProactiveReason'",
        "'lastPerceptionAt'",
        "'nextHeartbeatAt'",
        (('AI Companion v0.31.1 · REDACTED LOCAL DIAGNOSTIC REPORT' if 'version: 0.31.1+41' in pubspec else 'AI Companion v0.31.0 · REDACTED LOCAL DIAGNOSTIC REPORT')
         if any(v in pubspec for v in ['version: 0.31.0+40', 'version: 0.31.1+41'])
         else 'AI Companion v0.30.3 · REDACTED LOCAL DIAGNOSTIC REPORT'),
    ]:
        assert token in diagnostics, token

    handoff = (ROOT / 'docs/HANDOFF.md').read_text(encoding='utf-8')
    handoff_tokens = ['Background Presence', 'schema v18', 'signal:*', 'HANDOFF']
    handoff_tokens += ((['v0.31.1+41'] if 'version: 0.31.1+41' in pubspec else ['v0.31.0+40']) if any(v in pubspec for v in ['version: 0.31.0+40', 'version: 0.31.1+41']) else ['v0.30.3+39'])
    for token in handoff_tokens:
        assert token in handoff, token

    print('v0.30.0 Background Presence static validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
