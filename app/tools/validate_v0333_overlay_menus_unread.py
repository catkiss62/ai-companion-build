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


assert "version: 0.33.3+58" in read("pubspec.yaml")

pet = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
require(
    pet,
    [
        "ScrollView(context)",
        'optionButton("贴边缩进")',
        'optionButton("关闭菜单") { closeOptions(resumeMotion = true) }',
        "gravityResumePending = gravityResumePending || physics.active",
        "private fun resumeFallIfPending",
        'reason = "pet_overlay_resume_fall"',
        "private fun dockToNearestEdge()",
        "private fun motionArea(layout: WindowManager.LayoutParams)",
        "windowManager.currentWindowMetrics.bounds",
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
        'text = "悬浮球选项"',
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
        "Build AI Companion v0.33.3+58 APK",
        "python3 tools/validate_v0333_overlay_menus_unread.py",
        "AI-Companion-v0.33.3-58-Overlay-UX-D2-1-APK",
    ],
    "workflow",
)

print(
    "v0.33.3 overlay D2.1 validated: scrollable menus, bubble mode switch/retract, "
    "reply-completion unread, resumed airborne fall, and full-display pet motion bounds."
)
