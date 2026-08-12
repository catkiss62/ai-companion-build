#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert any(v in pubspec for v in ['version: 0.30.1+37', 'version: 0.30.2+38', 'version: 0.30.3+39'])

    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    assert 'static const int schemaVersion = 18;' in db

    overlay = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in [
        'WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()',
        'BUBBLE_SAFE_MARGIN_DP = 6',
        'private fun bubbleSafeArea(): BubbleSafeArea',
        'private fun clampBubbleToSafeArea(): Boolean',
        'private fun snapBubbleToSafeEdge()',
        'private fun ensureOverlayHealth(reason: String, rebuildInputChannel: Boolean = false)',
        'removeViewImmediate(it)',
        'CompanionRuntimeState.noteOverlayTouch("cancel")',
        'private fun scheduleInputChannelRecovery(',
        'ensureOverlayHealth("permission_watch")',
        'eventType = "overlay_touch_self_healed"',
        'updateOverlayTouchHealth()',
    ]:
        assert token in overlay, token
    collapse = overlay[overlay.index('private fun collapseChatOverlay'):overlay.index('private fun enterChatInputMode')]
    assert 'removeChatWindow()' in collapse
    assert 'chatRoot?.visibility = View.GONE' not in collapse

    runtime = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt').read_text(encoding='utf-8')
    for token in [
        'overlayBubbleAttached', 'overlayBubbleTouchable', 'overlayPositionSafe',
        'overlayChatWindowAttached', 'overlayLastTouchAt', 'overlayLastTouchAction',
        'overlaySelfHealCount', 'overlayLastSelfHealAt', 'overlayLastSelfHealReason', 'fun setOverlayTouchHealth(', 'fun noteOverlaySelfHeal(reason: String)',
    ]:
        assert token in runtime, token

    main_activity = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt').read_text(encoding='utf-8')
    assert 'OverlayBubbleService.reconcileFromVisibleActivity(this)' in main_activity

    bridge = (ROOT / 'lib/core/platform/android_bridge.dart').read_text(encoding='utf-8')
    for token in ['overlayBubbleAttached', 'overlayBubbleTouchable', 'overlayPositionSafe', 'overlaySelfHealCount']:
        assert token in bridge, token

    diagnostics = (ROOT / 'lib/core/diagnostics/preflight_diagnostics.dart').read_text(encoding='utf-8')
    for token in [
        "id: 'overlay_touch'", "title: '悬浮球触摸健康'", "report['overlayTouch'] = {",
        "'bubbleTouchable'", "'positionSafe'", "'lastSelfHealReason'", "'selfHealCount'",
        'AI Companion v0.30.3 · REDACTED LOCAL DIAGNOSTIC REPORT',
    ]:
        assert token in diagnostics, token

    handoff = (ROOT / 'docs/HANDOFF.md').read_text(encoding='utf-8')
    for token in ['v0.30.3+39', 'Overlay Regression Repair', 'schema v18', 'overlayTouch']:
        assert token in handoff, token

    # Numerical model of the safe-area clamp/snap invariants used by the Kotlin code.
    def clamp(x: int, y: int, left: int, top: int, right: int, bottom: int, size: int):
        max_x = max(left, right - size)
        max_y = max(top, bottom - size)
        return min(max(x, left), max_x), min(max(y, top), max_y)

    for case in [
        # 1080x2400-ish phone with status/nav bars and 6dp-like margin.
        (-500, -500, 6, 90, 1074, 2290, 62),
        (5000, 5000, 6, 90, 1074, 2290, 62),
        # very narrow/small safe region must still never invert coerce ranges.
        (200, 300, 12, 24, 70, 80, 62),
    ]:
        x, y = clamp(*case)
        left, top, right, bottom, size = case[2], case[3], case[4], case[5], case[6]
        max_x = max(left, right - size)
        max_y = max(top, bottom - size)
        assert left <= x <= max_x
        assert top <= y <= max_y

    # v0.30.0 Background Presence guarantees survive unchanged.
    for token in [
        'SIGNAL_WAKE_MIN_INTERVAL_MS = 90_000L',
        'requestSignalBrainWake(this@OverlayBubbleService, "device_present")',
        'backgroundBrainReady = true',
    ]:
        assert token in overlay, token

    print('v0.30.1 Overlay Touch Recovery static validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
