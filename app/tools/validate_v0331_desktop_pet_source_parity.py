#!/usr/bin/env python3
"""Exact source-pack and action-contract checks for Android desktop-pet v0.33.1."""

from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PET_ROOT = ROOT / "android/app/src/main/assets/pets/dafeiyu"
SOURCE_ASSETS = PET_ROOT / "source" / "assets"
EXPECTED_TREE_HASH = "caa4939627ee3a773566d4c793e355df5de98ad38698ddeb5b67519d03715582"


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


def tree_hash(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix().encode("utf-8")
        data = path.read_bytes()
        digest.update(len(relative).to_bytes(4, "big"))
        digest.update(relative)
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
    return digest.hexdigest()


def main() -> int:
    pubspec = read("pubspec.yaml")
    assert any(version in pubspec for version in (
        "version: 0.33.1+56", "version: 0.33.2+57", "version: 0.33.3+58", "version: 0.33.4+59", "version: 0.33.5+60", "version: 0.33.6+61", "version: 0.33.7+62", "version: 0.33.9+64", "version: 0.34.0+65", "version: 0.34.1+66", "version: 0.34.3+68", "version: 0.34.6+71",
    ))
    files = sorted(item for item in SOURCE_ASSETS.rglob("*") if item.is_file())
    assert len(files) == 417, len(files)
    assert sum(item.stat().st_size for item in files) == 111_962_623
    assert tree_hash(SOURCE_ASSETS) == EXPECTED_TREE_HASH

    manifest_path = SOURCE_ASSETS / "manifests" / "actions.json"
    assert hashlib.sha256(manifest_path.read_bytes()).hexdigest() == (
        "3db9c886c7ebb0a73df996796cc10f1649fda39b0d3e8b86dad053085ac3ac59"
    )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["format_version"] == 4
    assert len(manifest["actions"]) == 18
    assert len(manifest["assets"]) == 28

    expected_actions = {
        "IDLE", "BLINK", "GLANCE", "THINKING", "WALKING", "HAPPY",
        "HEAD_PAT", "TALKING", "ANGRY", "POKE_REACT", "TAIL_REACT",
        "EATING", "SWEEPING", "SLEEPING", "DRAGGING", "FALLING",
        "LANDING", "DIZZY",
    }
    assert set(manifest["actions"]) == expected_actions
    assert manifest["actions"]["WALKING"]["transition"]["enter"]["asset"] == "walk_start_left"
    assert manifest["actions"]["WALKING"]["transition"]["exit"]["asset"] == "walk_stop_left"
    assert manifest["actions"]["SLEEPING"]["transition"]["enter"]["asset"] == "sleep_enter"
    assert manifest["actions"]["SLEEPING"]["transition"]["exit"]["asset"] == "sleep_wake"
    assert manifest["actions"]["FALLING"]["transition"]["enter"]["asset"] == "released_airborne"
    assert manifest["actions"]["DRAGGING"]["duration_ms"] is None
    assert manifest["actions"]["FALLING"]["duration_ms"] is None

    referenced: set[str] = set()
    for asset_id, asset in manifest["assets"].items():
        assert set(asset["frames"]) == {"187", "238", "306"}, asset_id
        assert all(len(frames) == asset["frame_count"] for frames in asset["frames"].values())
        for size, frames in asset["frames"].items():
            for relative in frames:
                assert relative.startswith("assets/processed/runtime/") and ".." not in relative
                frame = PET_ROOT / "source" / relative
                assert frame.is_file(), relative
                width, height, color_type = png_header(frame)
                assert max(width, height) <= 1024, relative
                assert color_type in (4, 6), f"alpha channel required: {relative}"
                assert f"_{size}" in frame.name, relative
                referenced.add(relative)
    assert len(referenced) == 201
    runtime_pngs = set(
        path.relative_to(PET_ROOT / "source").as_posix()
        for path in (SOURCE_ASSETS / "processed" / "runtime").rglob("*.png")
    )
    assert len(runtime_pngs) == 210
    assert referenced <= runtime_pngs
    # Keep the 12 upstream runtime/fallback files that actions.json does not currently read.
    assert len(runtime_pngs - referenced) == 9

    labels = json.loads((PET_ROOT / "action_labels_zh-CN.json").read_text(encoding="utf-8"))
    assert set(labels) == expected_actions
    assert labels["DRAGGING"]["name"] == "抓取中"
    assert labels["FALLING"]["name"] == "落下"

    skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")
    state = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetActionStateMachine.kt")
    player = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAnimationPlayer.kt")
    effects = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetEffectPose.kt")
    physics = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetThrowPhysics.kt")
    preview = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetPreviewActivity.kt")

    require(skin, 'MANIFEST_PATH = "$SOURCE_ROOT/assets/manifests/actions.json"', "upstream manifest path")
    require(skin, "framesNearestTo", "three-size selection")
    require(skin, "PetAnimationPhase.ENTER", "enter/body/exit protocol")
    require(state, "candidate.priority <= active.priority", "upstream priority semantics")
    require(state, "queuedAfter ?: active.returnState", "queued return state")
    require(player, "CROSSFADE_MS = 90L", "upstream crossfade duration")
    require(player, "program.exit", "exit phase dispatch")
    require(effects, '"walk_frames"', "procedural walk effect")
    require(effects, '"landing"', "procedural landing effect")
    require(physics, "1f / 120f", "physics anti-tunnelling substeps")
    require(preview, 'player?.play("DRAGGING"', "drag gesture action")
    require(preview, 'player?.play("FALLING"', "release action")
    require(preview, 'player?.play("LANDING"', "landing action")
    require(preview, 'player?.queueAfterCurrent("DIZZY")', "hard landing chain")

    print(
        "v0.33.1 desktop-pet source parity validated: "
        f"{len(files)} complete source files, {len(manifest['actions'])} actions, "
        f"{len(runtime_pngs)} preserved runtime frames ({len(referenced)} manifest-referenced)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
