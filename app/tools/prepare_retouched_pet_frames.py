#!/usr/bin/env python3
"""Validate/apply the visible PNG revision without changing the frozen source pack.

CI uses only the standard library. Pillow is needed only for --regenerate.
Run historical source-pack checks BEFORE --apply; verify the actual APK afterwards.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import struct
import zipfile

APP = Path(__file__).resolve().parents[1]
PACK = APP / "asset_packs/dafeiyu_retouched"
INDEX = PACK / "manifest.json"
DESTINATION = APP / "android/app/src/main/assets/pets/dafeiyu/source"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def png_canvas(data: bytes) -> list[int]:
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("Invalid PNG")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if depth != 8 or color != 6 or not (0 < width <= 1024 and 0 < height <= 1024):
        raise ValueError("Expected bounded 8-bit RGBA PNG")
    return [width, height]


def safe_path(base: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or "\\" in relative:
        raise ValueError(f"Unsafe path: {relative}")
    result = base.joinpath(*path.parts)
    if not result.resolve().is_relative_to(base.resolve()):
        raise ValueError(f"Path escapes root: {relative}")
    return result


def read_index() -> dict:
    index = json.loads(INDEX.read_text(encoding="utf-8"))
    if index["schema"] != 1 or len(index["frames"]) != 59:
        raise ValueError("Unexpected revision schema/frame count")
    return index


def validate(index: dict) -> list[dict]:
    outputs = []
    sources = set()
    targets = set()
    files = set()
    for frame in index["frames"]:
        source = frame["source"]
        if not source.startswith("frames/") or source in sources or "_306" not in source:
            raise ValueError(f"Invalid/duplicate 306 source: {source}")
        sources.add(source)
        raw = safe_path(PACK, source).read_bytes()
        if sha(raw) != frame["source_sha256"] or png_canvas(raw) != frame["canvas"]:
            raise ValueError(f"Changed source; review then run --regenerate: {source}")
        if [o["tier"] for o in frame["outputs"]] != [187, 238, 306]:
            raise ValueError(f"Missing/duplicate tier: {source}")
        reference = frame["outputs"][2]["target"]
        for output in frame["outputs"]:
            target, filename = output["target"], output["file"]
            if target in targets or filename in files or not filename.startswith("frames/"):
                raise ValueError(f"Duplicate/invalid output: {target}")
            if not (target.startswith("assets/processed/runtime/states/") or
                    target.startswith("runtime_overrides/yawning/")) or not target.endswith(".png"):
                raise ValueError(f"Replacement outside PNG allowlist: {target}")
            safe_path(DESTINATION, target)
            if target != reference.replace("_306", f"_{output['tier']}"):
                raise ValueError(f"Frame order/name changed: {target}")
            data = safe_path(PACK, filename).read_bytes()
            if png_canvas(data) != output["canvas"] or sha(data) != output["sha256"]:
                raise ValueError(f"Wrong output pixels/dimensions: {filename}")
            if output["tier"] == 306 and (filename != source or data != raw):
                raise ValueError(f"306 source was resampled: {filename}")
            targets.add(target)
            files.add(filename)
            outputs.append(output)
    actual = {p.relative_to(PACK).as_posix() for p in (PACK / "frames").rglob("*.png")}
    if actual != files or len(outputs) != 177:
        raise ValueError("Unexpected/missing revision PNG files")
    return outputs


def apply(outputs: list[dict], destination: Path) -> None:
    # Check every destination before any write. Permit an idempotent re-apply.
    for output in outputs:
        old = safe_path(destination, output["target"]).read_bytes()
        if sha(old) not in (output["original_sha256"], output["sha256"]):
            raise ValueError(f"Unknown pre-existing artwork: {output['target']}")
        if png_canvas(old) != output["canvas"]:
            raise ValueError(f"Canvas changed: {output['target']}")
    for output in outputs:
        target = safe_path(destination, output["target"])
        temporary = target.with_suffix(".png.retouch-tmp")
        shutil.copyfile(safe_path(PACK, output["file"]), temporary)
        temporary.replace(target)
    for output in outputs:
        if sha(safe_path(destination, output["target"]).read_bytes()) != output["sha256"]:
            raise ValueError(f"Failed replacement: {output['target']}")


def verify_apk(outputs: list[dict], apk: Path, destination: Path) -> None:
    prefix = "assets/pets/dafeiyu/source/"
    with zipfile.ZipFile(apk) as archive:
        for output in outputs:
            packed = archive.read(prefix + output["target"])
            if sha(packed) != output["sha256"] or png_canvas(packed) != output["canvas"]:
                raise ValueError(f"Stale/missing retouched APK frame: {output['target']}")
        # Also verify every unmodified file and the action manifest, not just the patch.
        expected = {p.relative_to(destination).as_posix(): p for p in
                    (destination / "assets").rglob("*") if p.is_file()}
        names = {n.removeprefix(prefix) for n in archive.namelist()
                 if n.startswith(prefix + "assets/") and not n.endswith("/")}
        if len(expected) != 417 or names != set(expected):
            raise ValueError("APK source-pack file inventory changed")
        for name, local in expected.items():
            if archive.read(prefix + name) != local.read_bytes():
                raise ValueError(f"APK source-pack bytes changed: {name}")


def regenerate(index: dict) -> None:
    from PIL import Image, __version__
    if __version__ != "12.3.0":
        raise ValueError("Regeneration requires Pillow==12.3.0")
    # Preflight all sources before changing any generated files.
    for frame in index["frames"]:
        if png_canvas(safe_path(PACK, frame["source"]).read_bytes()) != frame["canvas"]:
            raise ValueError(f"Source canvas changed: {frame['source']}")
    for frame in index["frames"]:
        raw = safe_path(PACK, frame["source"]).read_bytes()
        frame["source_sha256"] = sha(raw)
        with Image.open(io.BytesIO(raw)) as image:
            for output in frame["outputs"]:
                if output["tier"] == 306:
                    data = raw
                else:
                    buffer = io.BytesIO()
                    image.convert("RGBa").resize(tuple(output["canvas"]), Image.Resampling.LANCZOS
                        ).convert("RGBA").save(buffer, format="PNG", compress_level=9)
                    data = buffer.getvalue()
                    safe_path(PACK, output["file"]).write_bytes(data)
                output["sha256"] = sha(data)
    INDEX.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--regenerate", action="store_true")
    mode.add_argument("--verify-apk", type=Path)
    parser.add_argument("--destination", type=Path, default=DESTINATION)
    args = parser.parse_args()
    index = read_index()
    if args.regenerate:
        regenerate(index)
    outputs = validate(index)
    if args.apply:
        apply(outputs, args.destination)
    if args.verify_apk:
        verify_apk(outputs, args.verify_apk, args.destination)
    print("Pet retouch: 59 preserved 306 sources, 118 derived frames, 177 PNGs verified.")


if __name__ == "__main__":
    main()
