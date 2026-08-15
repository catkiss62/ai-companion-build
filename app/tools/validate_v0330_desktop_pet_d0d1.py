#!/usr/bin/env python3
"""Static and asset-contract checks for Android desktop-pet D0/D1."""

from __future__ import annotations

import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PET_ROOT = ROOT / "android/app/src/main/assets/pets/dafeiyu"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"ERROR: missing {label}: {token}")


def png_header(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()[:26]
    if len(data) != 26 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise SystemExit(f"ERROR: invalid PNG header: {path}")
    width, height, _, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, color_type


def main() -> int:
    require(read("pubspec.yaml"), "version: 0.33.0+55", "release version")
    manifest_path = PET_ROOT / "pet.json"
    attribution = (PET_ROOT / "ATTRIBUTION.md").read_text(encoding="utf-8")
    license_text = (PET_ROOT / "LICENSE.txt").read_text(encoding="utf-8")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    assert manifest["format_version"] == 1
    assert manifest["redistribution_allowed"] is False
    assert manifest["usage_scope"] == "private_noncommercial_ai_companion_only"
    actions = manifest["actions"]
    assert len(actions) == 27
    for required in (
        "idle", "blink", "walk_left", "walk_right", "dragging", "falling",
        "landing", "sleep", "talk", "happy", "head_pat", "poke",
    ):
        assert required in actions, required

    referenced: set[str] = set()
    total_bytes = 0
    for action, spec in actions.items():
        assert 1 <= int(spec["fps"]) <= 30, action
        assert 1 <= len(spec["frames"]) <= 48, action
        for relative in spec["frames"]:
            assert relative.startswith("actions/") and ".." not in relative, relative
            frame = PET_ROOT / relative
            assert frame.is_file(), relative
            width, height, color_type = png_header(frame)
            assert 32 <= width <= 512 and 32 <= height <= 512, relative
            assert color_type in (4, 6), f"alpha channel required: {relative}"
            referenced.add(relative)
            total_bytes += frame.stat().st_size

    actual = {
        path.relative_to(PET_ROOT).as_posix()
        for path in (PET_ROOT / "actions").rglob("*.png")
    }
    assert actual == referenced, f"unreferenced={sorted(actual-referenced)} missing={sorted(referenced-actual)}"
    assert len(actual) == 66
    assert total_bytes < 6 * 1024 * 1024
    assert "QCYTSN/ds-local-pet" in attribution
    assert "private" in attribution.lower()
    assert "No permission is asserted for public redistribution" in license_text

    skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")
    state = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetActionStateMachine.kt")
    player = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAnimationPlayer.kt")
    preview = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetPreviewActivity.kt")
    bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
    dart_bridge = read("lib/core/platform/android_bridge.dart")
    system_page = read("lib/features/system/system_page.dart")
    android_manifest = read("android/app/src/main/AndroidManifest.xml")

    require(skin, 'MAX_FRAMES_PER_ACTION = 48', "bounded frame count")
    require(skin, 'normalized.contains("..")', "path traversal rejection")
    require(state, "DRAG(100)", "drag priority")
    require(state, "if (paused && source != PetActionSource.SYSTEM)", "pause gate")
    require(player, "1000L / clip.fps.coerceAtLeast(1)", "per-action frame clock")
    require(preview, "PetSkinManifest.load(assets)", "isolated Activity loader")
    require(preview, "player?.setPaused(true)", "background pause")
    require(bridge, '"openDesktopPetPreview"', "native preview route")
    require(dart_bridge, "openDesktopPetPreview", "Flutter preview bridge")
    require(system_page, "桌宠播放器预览", "system-page preview entry")
    require(android_manifest, ".pet.PetPreviewActivity", "preview Activity registration")

    print(
        f"v0.33.0 desktop-pet D0/D1 validated: {len(actions)} actions, "
        f"{len(actual)} RGBA frames, {total_bytes} bytes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
