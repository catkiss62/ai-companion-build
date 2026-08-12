#!/usr/bin/env python3
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]

def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert 'version: 0.30.3+39' in pubspec

    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    assert 'static const int schemaVersion = 18;' in db

    overlay = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in [
        'inputRecoveryInProgress',
        'CompanionRuntimeState.setOverlayRecoveryInProgress(true)',
        'INPUT_RECOVERY_MIN_GAP_MS = 8_000L',
        'INPUT_RECOVERY_SETTLE_MS = 700L',
        'SYSTEM_COVER_REQUEST_MIN_GAP_MS = 4_000L',
        'if (inputRecoveryScheduled || inputRecoveryInProgress) return',
        'if (CompanionRuntimeState.isAppVisible())',
        'visibilityWasSuppressed',
        'window_visibility_suppressed',
        'window_visibility_restored',
        'rebuildInputChannel = CompanionRuntimeState.consumeOverlayInputSuspect()',
    ]:
        assert token in overlay, token
    assert 'scheduleInputChannelRecovery("device_unlock"' not in overlay
    assert 'rebuildInputChannel = reconcileReason == "visible_activity_reconcile"' not in overlay

    open_start = overlay.index('private fun openFullApp()')
    open_end = overlay.index('private fun setChatStatus', open_start)
    open_block = overlay[open_start:open_end]
    assert 'startActivity(launchIntent)' in open_block
    assert 'collapseChatOverlay(' not in open_block
    assert 'overlay_open_full_app_requested' in open_block

    accessibility = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt').read_text(encoding='utf-8')
    assert 'ApplicationInfo' not in accessibility
    assert 'FLAG_SYSTEM' not in accessibility
    for token in ['com.android.documentsui', 'permissioncontroller', 'packageinstaller', 'com.android.settings', 'system_surface_return']:
        assert token in accessibility, token

    runtime = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt').read_text(encoding='utf-8')
    for token in ['overlayRecoveryInProgress', 'fun setOverlayRecoveryInProgress(value: Boolean)', 'fun isAppVisible(): Boolean']:
        assert token in runtime, token

    main_activity = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt').read_text(encoding='utf-8')
    collapse = main_activity.index('OverlayBubbleService.collapseChatFromVisibleActivity(this)')
    reconcile = main_activity.index('OverlayBubbleService.reconcileFromVisibleActivity(this)')
    assert collapse < reconcile

    diagnostics = (ROOT / 'lib/core/diagnostics/preflight_diagnostics.dart').read_text(encoding='utf-8')
    for token in [
        'AI Companion v0.30.3 · REDACTED LOCAL DIAGNOSTIC REPORT',
        "'recoveryInProgress'", "'coverRecoveryCount'", "'selfHealCount'",
    ]:
        assert token in diagnostics, token

    # Presence Intelligence must remain present and its key policy parameters frozen.
    presence = (ROOT / 'lib/core/presence/presence_intelligence.dart').read_text(encoding='utf-8')
    for token in [
        'halfLife = Duration(minutes: 55)',
        "topicKey: 'presence:phone_activity'",
        "source: 'presence/phone_activity'",
        'score >= 0.20',
    ]:
        assert token in presence, token
    proactive = (ROOT / 'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    assert '(presenceMomentum * (userBusy ? 0.055 : 0.095))' in proactive
    assert '.clamp(0.0, 0.085)' in proactive

    handoff = (ROOT / 'docs/HANDOFF.md').read_text(encoding='utf-8')
    for token in ['v0.30.3+39', 'Overlay Regression Repair', 'selfHealCount=28', 'Presence 完全冻结', 'schema v18']:
        assert token in handoff, token

    print('v0.30.3 Overlay Regression Repair static validation passed.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
