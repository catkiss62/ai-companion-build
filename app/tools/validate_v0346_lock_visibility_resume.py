#!/usr/bin/env python3
"""Source contract for v0.34.6 lock/unlock pet-action recovery."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"ERROR: missing {label}: {token}")


def main() -> int:
    pubspec = read("pubspec.yaml")
    workflow = read("../.github/workflows/build-apk.yml")
    service = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
    )
    pet = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
    )

    require(pubspec, "version: 0.34.6+71", "v0.34.6 build identity")
    require(
        workflow,
        "Build AI Companion v0.34.6+71 APK (Lock Resume)",
        "workflow title",
    )
    require(
        workflow,
        "python3 tools/validate_v0346_lock_visibility_resume.py",
        "workflow regression invocation",
    )
    require(
        workflow,
        "AI-Companion-v0.34.6-71-Lock-Resume-APK.apk",
        "draft Release APK identity",
    )

    start = pet.index("    fun setVisible(visible: Boolean) {")
    end = pet.index("    /** Re-adds the pet after the chat window", start)
    visibility_block = pet[start:end]
    require(
        visibility_block,
        "cancelAutonomyPlayback(resetToIdle = true)",
        "hidden pet transient-action reset",
    )
    if "cancelAutonomyPlayback(resetToIdle = false)" in visibility_block:
        raise SystemExit(
            "ERROR: hiding the pet may not preserve WALKING/STROLLING after its move tick is removed"
        )
    require(visibility_block, "player?.setPaused(!visible)", "player pause/resume")
    require(visibility_block, "scheduleNextAmbient(resumedAtMs)", "unlock reschedule")
    require(visibility_block, "scheduleNextBlink(resumedAtMs)", "unlock blink reschedule")

    require(service, "Intent.ACTION_SCREEN_OFF -> {", "screen-off lifecycle")
    require(service, "petOverlayWindow?.setVisible(false)", "screen-off hide")
    require(service, "Intent.ACTION_USER_PRESENT -> {", "unlock lifecycle")
    require(service, "petOverlayWindow?.setVisible(true)", "unlock show")

    # v0.34.6 is deliberately not another overlay recovery timing patch.
    require(service, "private const val COVER_RECOVERY_MAX_ATTEMPTS = 3", "bounded recovery")
    require(service, "private const val INPUT_RECOVERY_SETTLE_MS = 700L", "settle window")

    print(
        "v0.34.6 lock/unlock visibility contract validated: hidden autonomous "
        "movement resets to IDLE, unlock reschedules ambient motion, and bounded "
        "picker recovery timings remain unchanged."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
