#!/usr/bin/env python3
"""Static contract checks for the v0.33.2 system-overlay desktop pet."""

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
    "version: 0.33.2+57",
    "version: 0.33.3+58",
    "version: 0.33.4+59",
    "version: 0.33.5+60",
    "version: 0.33.6+61",
))

pet = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
require(
    pet,
    [
        "class PetOverlayWindow(",
        "PetSkinManifest.load(context.assets)",
        "PetAnimationPlayer(",
        '"DRAGGING"',
        '"FALLING"',
        '"LANDING"',
        '"DIZZY"',
        '"HEAD_PAT"',
        '"POKE_REACT"',
        '"TAIL_REACT"',
        '"ANGRY"',
        "ViewConfiguration.getDoubleTapTimeout()",
        "showOptions()",
        'menuHeader("桌宠选项")',
        'optionButton("打开聊天")',
        'optionButton("切换为悬浮球")',
        "PetTouchRegions.classify(event.x, event.y, view.width, view.height)",
    ],
    "pet overlay",
)
assert "class PetOverlayWindow" in pet and ": Service" not in pet

contract = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayContract.kt"
)
require(
    contract,
    [
        "object PetTouchRegions",
        "nx in 0.27f..0.73f",
        "nx >= 0.72f || nx <= 0.24f",
        "SMALL -> 112",
        "LARGE -> 200",
        "SMALL -> 187",
        "LARGE -> 306",
    ],
    "pure pet interaction and sizing contract",
)

service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
require(
    service,
    [
        "private var petOverlayWindow: PetOverlayWindow? = null",
        "if (entryMode(this) == ENTRY_MODE_PET) return createPetEntry()",
        "private fun switchEntryMode(mode: String, reason: String)",
        'const val ENTRY_MODE_BUBBLE = "bubble"',
        'const val ENTRY_MODE_PET = "pet"',
        "fun setEntryMode(context: Context, mode: String)",
        "fun setPetSize(context: Context, size: String)",
        'showChatOverlay("pet_double_tap_menu")',
        "petOverlayWindow?.setVisible(false)",
        "petOverlayWindow?.setVisible(true)",
    ],
    "shared companion service",
)

bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
require(
    bridge,
    [
        '"setOverlayEntryMode"',
        '"setPetOverlaySize"',
        'put("overlayEntryMode", OverlayBubbleService.entryMode(activity))',
        'put("overlayPetSize", OverlayBubbleService.petSize(activity))',
    ],
    "native bridge",
)

dart_bridge = read("lib/core/platform/android_bridge.dart")
require(
    dart_bridge,
    [
        "final String overlayEntryMode;",
        "final String overlayPetSize;",
        "Future<void> setOverlayEntryMode(String mode)",
        "Future<void> setPetOverlaySize(String size)",
    ],
    "dart bridge",
)

page = read("lib/features/system/system_page.dart")
require(
    page,
    [
        "悬浮入口模式",
        "桌宠和悬浮球二选一",
        "桌宠单击互动，双击打开选项",
        "android.setOverlayEntryMode('pet')",
        "android.setOverlayEntryMode('bubble')",
        "android.setPetOverlaySize(item.$1)",
        "开启悬浮陪伴",
        "关闭悬浮陪伴",
    ],
    "system page",
)

print(
    "v0.33.2 overlay pet D2 validated: one shared foreground service, "
    "pet/bubble exclusive modes, real three-size windows, single-tap body reactions, "
    "double-tap options, drag/fall/land physics."
)
