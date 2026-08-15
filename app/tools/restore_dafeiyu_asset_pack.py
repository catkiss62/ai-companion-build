#!/usr/bin/env python3
"""Restore the exact user-supplied desktop-pet pack from Git-friendly binary chunks."""

from __future__ import annotations

import hashlib
import json
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[1]
PART_ROOT = ROOT / "asset_packs" / "dafeiyu_private.parts"
CONFIG = PART_ROOT / "asset_pack.json"
TARGET = ROOT / "android/app/src/main/assets/pets/dafeiyu/source/assets"


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


def safe_members(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    members = archive.infolist()
    for member in members:
        path = PurePosixPath(member.filename.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"ERROR: unsafe asset member: {member.filename}")
        mode = member.external_attr >> 16
        if stat.S_ISLNK(mode):
            raise SystemExit(f"ERROR: symlink not allowed in asset pack: {member.filename}")
    return members


def main() -> int:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    parts = sorted(PART_ROOT.glob("part-*.bin"))
    if len(parts) != config["chunk_count"]:
        raise SystemExit(f"ERROR: asset chunk count {len(parts)} != {config['chunk_count']}")
    if TARGET.exists():
        raise SystemExit(f"ERROR: restore target already exists: {TARGET}")

    with tempfile.TemporaryDirectory(prefix="dafeiyu-restore-") as folder:
        temporary = Path(folder)
        zip_path = temporary / "asset-pack.zip"
        digest = hashlib.sha256()
        size = 0
        with zip_path.open("wb") as output:
            for index, part in enumerate(parts):
                expected_name = f"part-{index:03d}.bin"
                if part.name != expected_name:
                    raise SystemExit(f"ERROR: expected {expected_name}, found {part.name}")
                data = part.read_bytes()
                output.write(data)
                digest.update(data)
                size += len(data)
        if size != config["zip_size"] or digest.hexdigest() != config["zip_sha256"]:
            raise SystemExit("ERROR: reconstructed asset ZIP checksum mismatch")

        extract_root = temporary / "extracted"
        extract_root.mkdir()
        with zipfile.ZipFile(zip_path) as archive:
            archive.extractall(extract_root, members=safe_members(archive))
        top = [item for item in extract_root.iterdir() if item.is_dir()]
        if len(top) != 1:
            raise SystemExit(f"ERROR: expected one asset root, found {len(top)}")
        files = [item for item in top[0].rglob("*") if item.is_file()]
        if len(files) != config["file_count"]:
            raise SystemExit(f"ERROR: extracted file count {len(files)} != {config['file_count']}")
        if sum(item.stat().st_size for item in files) != config["extracted_size"]:
            raise SystemExit("ERROR: extracted asset size mismatch")
        if tree_hash(top[0]) != config["tree_sha256"]:
            raise SystemExit("ERROR: extracted asset tree checksum mismatch")
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(top[0], TARGET)

    print(
        f"Restored exact desktop-pet pack: {config['file_count']} files, "
        f"{config['extracted_size']} bytes, tree {config['tree_sha256']}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
