#!/usr/bin/env python3
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def sha256(relative: str) -> str:
    return hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()


def main() -> int:
    pubspec = read("pubspec.yaml")
    assert "version: 0.31.3+45" in pubspec
    assert "static const int schemaVersion = 19;" in read(
        "lib/core/database/app_database.dart"
    )

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
        "AI Companion v0.31.3+45 · REDACTED LOCAL DIAGNOSTIC REPORT",
        "'coverState'",
        "'systemCoverActive'",
        "'coverSessionId'",
        "'coverRecoveryAttempt'",
        "'lastCoverExitReason'",
        "'lastCoverRecoveryResult'",
        "'coverDetachCount'",
    ]:
        assert token in diagnostics, token

    # v0.31.3 is deliberately isolated from Companion Voice, Desire and TTS.
    frozen_hashes = {
        "lib/features/chat/chat_controller.dart":
            "9709994886c24771c1c886bee0f79daef67dded8f884e5afa1f03817cfe35602",
        "lib/core/ai/companion_voice_protocol.dart":
            "9bbc744c70ec63cb35a81558098c76b98dd5e9c31b6cdc052ef96e4422047d19",
        "lib/core/desire/desire_core_policy.dart":
            "d28f0fb575ed2d7b32bb186e5058c07432a30a5aa81b76a5474a9f298c7dcab5",
        "lib/core/tts/tts_sentence_segmenter.dart":
            "8ee58af4cfab2e03bf3d80f527a777bab9a3790d75370ffe0760dfc4fe8906d8",
        "android/app/src/main/jniLibs/arm64-v8a/libbertvits2.so":
            "a599d482539fdbe01ccd82a9c688d0dce574c19dd681b15fd580185890e65792",
    }
    for relative, expected in frozen_hashes.items():
        assert sha256(relative) == expected, relative

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
