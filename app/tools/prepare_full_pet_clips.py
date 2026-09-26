#!/usr/bin/env python3
"""Build pinned transparent WebM clips into bounded Android frame packs.

The archive stays in the source Draft Release; the generated packs are build
outputs, not Git blobs. No frame bytes are written to the Actions log.
"""
import argparse
import hashlib
import json
import struct
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1] / "android/app/src/main/assets/pets/dafeiyu/source/runtime_overrides/experimental"
CHUNK_BYTES = 2_000_000


def prepare(archive: Path, limit: int = 0) -> None:
    catalog = json.loads((ROOT / "catalog.json").read_text(encoding="utf-8"))
    actual = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
    if actual != catalog["source_sha256"]:
        raise ValueError(f"Pet source SHA-256 mismatch: {actual}")
    clips = catalog["clips"]
    if len(clips) != 96 or sum(c["frames"] for c in clips) != 23013:
        raise ValueError("Pet catalog count changed")
    new_clips = [c for c in clips if c["folder"].startswith("full_")]
    if len(new_clips) != 91:
        raise ValueError("Pet new-clip count changed")
    if limit:
        new_clips = new_clips[:limit]
    with ZipFile(archive) as source:
        names = source.namelist()
        for number, clip in enumerate(new_clips, 1):
            matches = [n for n in names if n.endswith("/assets/characters/shenshen/" + clip["source"])]
            if len(matches) != 1:
                raise ValueError(f"Missing or duplicated source: {clip['source']}")
            target = ROOT / clip["folder"] / "packed"
            target.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix="pet-clip-") as temp:
                temp = Path(temp)
                video = temp / "source.webm"
                video.write_bytes(source.read(matches[0]))
                output = temp / "frame_%03d.webp"
                command = [
                    "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin",
                    "-c:v", "libvpx-vp9", "-i", str(video),
                    "-vf", "crop=360:360:140:0,scale=224:224:flags=lanczos",
                    "-vsync", "0", "-c:v", "libwebp", "-quality", "65",
                    "-compression_level", "4", "-y", str(output),
                ]
                subprocess.run(command, check=True, capture_output=True)
                frames = sorted(temp.glob("frame_*.webp"))
                if len(frames) != clip["frames"]:
                    raise ValueError(f"Frame count changed: {clip['folder']} {len(frames)}")
                packed = bytearray(b"PETCLIP" + struct.pack(">I", len(frames)))
                for frame in frames:
                    data = frame.read_bytes()
                    if len(data) < 16 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
                        raise ValueError(f"Invalid WebP: {clip['folder']}")
                    packed += struct.pack(">I", len(data)) + data
                for stale in target.glob("*.bin"):
                    stale.unlink()
                for offset in range(0, len(packed), CHUNK_BYTES):
                    (target / f"{offset // CHUNK_BYTES:03d}.bin").write_bytes(
                        packed[offset:offset + CHUNK_BYTES]
                    )
            if number % 10 == 0 or number == len(new_clips):
                print(f"Prepared {number}/{len(new_clips)} new pet clips", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--limit", type=int, default=0, help="Local smoke check only")
    args = parser.parse_args()
    prepare(args.archive, args.limit)
