#!/usr/bin/env python3
"""Static contract checks for v0.33.3 overlay interaction reliability."""

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
    "version: 0.33.3+58",
    "version: 0.33.4+59",
    "version: 0.33.5+60",
    "version: 0.33.6+61",
    "version: 0.33.7+62",
    "version: 0.33.9+64", "version: 0.34.0+65",
))

pet = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
require(
    pet,
    [
        "ScrollView(context)",
        'optionButton(selectedLabel("贴边模式"',
        'menuHeader("桌宠选项")',
        "gravityResumePending = gravityResumePending || physics.active",
        "private fun resumeFallIfPending",
        'reason = "pet_overlay_resume_fall"',
        "private fun dockToNearestEdge()",
        "private fun motionArea(layout: WindowManager.LayoutParams)",
        "windowManager.currentWindowMetrics",
        "EDGE_OVERSCAN_RATIO = 0.06f",
        "private fun menuSafeArea()",
    ],
    "pet D2.1 interaction",
)

service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
require(
    service,
    [
        "private var bubbleOptionsRoot: View? = null",
        "ViewConfiguration.getDoubleTapTimeout()",
        "private fun showBubbleOptions()",
        'bubbleMenuHeader("悬浮球选项")',
        'bubbleOptionButton("切换为桌宠")',
        'bubbleOptionButton("缩进左侧")',
        "private fun retractBubbleToLeft()",
        "private fun expandBubbleFromLeft()",
        "KEY_BUBBLE_RETRACTED",
        "BUBBLE_RETRACTED_VISIBLE_DP = 24",
        "if (ok && !chatExpanded) setUnread(readUnread() + 1)",
        "ScrollView(this)",
    ],
    "bubble menu, retract, and completion unread",
)

workflow = read("../.github/workflows/build-apk.yml")
require(
    workflow,
    [
        "Build AI Companion v0.34.0+65 APK (Image Messages Phase 1)",
        "python3 tools/validate_v0333_overlay_menus_unread.py",
        "AI-Companion-v0.34.0-65-Image-Messages-Phase-1-APK",
    ],
    "workflow",
)

print(
    "v0.33.3 overlay D2.1 validated: scrollable menus, bubble mode switch/retract, "
    "reply-completion unread, resumed airborne fall, and full-display pet motion bounds."
)
