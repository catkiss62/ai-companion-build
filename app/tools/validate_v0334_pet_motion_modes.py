#!/usr/bin/env python3
"""Static contract checks for v0.33.4 desktop-pet motion modes D2.2."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


pubspec = read("pubspec.yaml")
assert any(version in pubspec for version in (
    "version: 0.33.4+59", "version: 0.33.5+60", "version: 0.33.6+61", "version: 0.33.7+62", "version: 0.33.8+63", "version: 0.33.9+64", "version: 0.34.1+66", "version: 0.34.3+68",
))

contract = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayContract.kt"
)
require(
    contract,
    [
        "object PetMotionPolicy",
        'const val FREE = "free"',
        'const val EDGE = "edge"',
        'const val HALF_TOP = "half_top"',
        'const val HALF_BOTTOM = "half_bottom"',
        'const val HALF_LEFT = "half_left"',
        'const val HALF_RIGHT = "half_right"',
        "fun shouldThrow(",
        "speedDpPerSecond >= 650f",
        "recentTravelDp >= 30f",
        "totalDisplacementDp >= 48f",
        "!tailStable",
    ],
    "pure motion policy",
)

pet = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
require(
    pet,
    [
        'selectedLabel("自由模式"',
        'selectedLabel("贴边模式"',
        'sectionLabel("半屏模式")',
        "PetMotionPolicy.HALF_TOP to \"上\"",
        "PetMotionPolicy.HALF_BOTTOM to \"下\"",
        "PetMotionPolicy.HALF_LEFT to \"左\"",
        "PetMotionPolicy.HALF_RIGHT to \"右\"",
        "private fun handleDragRelease(",
        "private fun releaseGesture()",
        "PetMotionPolicy.shouldThrow(",
        "private fun dockToNearestEdge()",
        "private fun activeArea(",
        "val centerX = full.left + full.width / 2",
        "val centerY = full.top + full.height / 2",
        "if (landscape) insets.left else 0",
        "bounds.bottom - insets.bottom - dp(PORTRAIT_BOTTOM_MARGIN_DP)",
        'menuHeader("桌宠选项")',
        "clipToOutline = true",
        "minHeight = 0",
    ],
    "desktop-pet D2.2 behavior",
)
assert 'optionButton("贴边缩进")' not in pet
assert 'optionButton("关闭菜单")' not in pet

service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
require(
    service,
    [
        'bubbleMenuHeader("悬浮球选项")',
        "private fun bubbleMenuHeader(",
        "clipToOutline = true",
        "minHeight = 0",
    ],
    "bubble menu containment",
)
assert 'bubbleOptionButton("关闭菜单")' not in service

tests = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)
require(
    tests,
    [
        "motionModesDefaultToFreeAndKeepEveryHalfDistinct",
        "throwNeedsSpeedTravelDistanceAndAnUnstableTail",
    ],
    "motion policy unit tests",
)

workflow = read("../.github/workflows/build-apk.yml")
require(
    workflow,
    [
        "Build AI Companion v0.34.3+68 APK (Lifelike Rules and Overlay Polish)",
        "python3 tools/validate_v0334_pet_motion_modes.py",
        "AI-Companion-v0.34.3-68-Lifelike-Rules-Overlay-APK",
    ],
    "workflow",
)

print(
    "v0.33.4 pet motion D2.2 validated: persistent free/edge/half modes, "
    "gentle-place versus throw policy, adaptive landscape shift, restored portrait "
    "bottom inset, and contained header-close menus."
)
