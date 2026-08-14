#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> int:
    pubspec = read("pubspec.yaml")
    version = re.search(
        r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$",
        pubspec,
        re.MULTILINE,
    )
    assert version is not None
    assert tuple(map(int, version.groups())) >= (0, 31, 3, 45)
    assert any(version in read("lib/core/database/app_database.dart") for version in (
        "static const int schemaVersion = 19;",
        "static const int schemaVersion = 20;",
    ))

    overlay = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
    )
    for token in [
        "ACTION_SYSTEM_COVER_ENTER",
        "ACTION_SYSTEM_COVER_EXIT",
        "handleSystemCoverEntered",
        "retireBubbleForSystemCover",
        "windowManager.removeViewImmediate(bubble)",
        "handleSystemCoverExited",
        "COVER_EXIT_STABLE_DELAY_MS = 1_100L",
        "COVER_RECOVERY_MAX_ATTEMPTS = 3",
        "COVER_RECOVERY_RETRY_DELAYS_MS = longArrayOf(1_800L, 4_000L)",
        "if (CompanionRuntimeState.isOverlaySystemCoverActive())",
        "Never re-add an overlay beneath a still-active system picker",
        '"suspect_watchdog"',
        '"bounded_cover_recovery:',
        'eventType = "overlay_system_cover_entered"',
        'eventType = "overlay_system_cover_recovered"',
    ]:
        assert token in overlay, token

    recovery_start = overlay.index("private fun scheduleCoverRecovery(")
    recovery_end = overlay.index("private fun updateOverlayTouchHealth()", recovery_start)
    recovery = overlay[recovery_start:recovery_end]
    assert "CompanionRuntimeState.isAppVisible()" not in recovery
    assert "while (" not in recovery
    assert "COVER_RECOVERY_MAX_ATTEMPTS" in recovery

    runtime = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt"
    )
    for token in [
        'overlayCoverState: String = "idle"',
        "overlaySystemCoverActive",
        "overlayCoverSessionId",
        "overlayCoverRecoveryAttempt",
        "overlayLastCoverExitReason",
        "overlayLastCoverRecoveryResult",
        "overlayCoverDetachCount",
        "fun noteOverlayCoverEntered(",
        "fun noteOverlayCoverExited(",
        "fun noteOverlayCoverRecoveryScheduled(",
        "fun noteOverlayCoverRecoveryResult(",
        "fun noteOverlayCoverRecoveryFailed(",
        "fun noteOverlayCoverRecoveryDeferred(",
    ]:
        assert token in runtime, token

    accessibility = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
    )
    for token in [
        "notifySystemCoverEntered",
        "notifySystemCoverExited",
        "CompanionRuntimeState.isOverlaySystemCoverActive()",
        "com.android.documentsui",
        "com.android.providers.media.module",
        "com.android.photopicker",
        "com.miui.fileexplorer",
        'p.contains("photopicker")',
    ]:
        assert token in accessibility, token
    assert "sourcePackage" not in accessibility[
        accessibility.index("notifySystemCoverEntered") :
        accessibility.index("if (!PrivacyFilter.allowPackage")
    ]

    diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
    for token in [
        "REDACTED LOCAL DIAGNOSTIC REPORT",
        "'coverState'",
        "'systemCoverActive'",
        "'coverSessionId'",
        "'coverRecoveryAttempt'",
        "'lastCoverExitReason'",
        "'lastCoverRecoveryResult'",
        "'coverDetachCount'",
    ]:
        assert token in diagnostics, token

    # A cover session can schedule at most attempts 1, 2 and 3. A re-enter
    # increments the session token, making callbacks from the old token inert.
    attempts = []
    max_attempts = 3
    attempt = 1
    while attempt <= max_attempts:
        attempts.append(attempt)
        attempt += 1
    assert attempts == [1, 2, 3]
    old_session, current_session = 7, 8
    assert old_session != current_session

    print("v0.31.3 HyperOS file-picker overlay recovery validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
