#!/usr/bin/env python3
"""Static contract checks for v0.33.7 falling visual rollback D3.1.2."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


assert any(version in read("pubspec.yaml") for version in (
    "version: 0.33.7+62", "version: 0.33.9+64", "version: 0.34.1+66", "version: 0.34.3+68", "version: 0.34.6+71",
))

pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt")
skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")
physics = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetThrowPhysics.kt")
require(
    pet,
    [
        'player?.play("FALLING", reason = reason, force = true, immediate = true)',
        'player?.play("LANDING", reason = "pet_overlay_landing", force = true, immediate = true)',
        'if (step.hardLanding) player?.queueAfterCurrent("DIZZY")',
        "handler.postDelayed(task, LIGHT_LANDING_DELAY_MS)",
        "private const val LIGHT_LANDING_DELAY_MS = 180L",
        "private const val PORTRAIT_BOTTOM_MARGIN_DP = 16",
    ],
    "restored v0.33.5 falling sequence",
)
for removed in (
    "falling_airborne_v2",
    "candidate_e_throw_landing/falling_v2.png",
    '"BOUNCING"',
    "floorContact",
):
    assert removed not in pet + skin + physics, removed

doc = read("docs/PET_FALLING_VISUAL_ROLLBACK_D3_1_2_v0.33.7.md")
require(
    doc,
    [
        "恢复 v0.33.5",
        "不使用 `walk_side_stand`",
        "daily_transition_00",
        "sleepy_yawn",
        "哈欠动作继续保留",
    ],
    "corrected action decisions",
)

workflow = read("../.github/workflows/build-apk.yml")
require(
    workflow,
    [
        "Build AI Companion v0.34.6+71 APK (Lock Resume)",
        "python3 tools/validate_v0337_pet_falling_visual_rollback.py",
        "AI-Companion-v0.34.6-71-Lock-Resume-APK",
    ],
    "workflow",
)

print("v0.33.7 D3.1.2 validated: exact single FALLING rollback, original landing timing, no side-stand plan, yawn retained.")
