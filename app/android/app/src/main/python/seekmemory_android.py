"""Run the unmodified upstream entry point on private bundled test data."""
import importlib
import json
from pathlib import Path
import sys
import tempfile
import zipfile

REVISION = "4ae154ba5b763a86fdc8a546152be1bd45f65416"

def run(archive, cache):
    # Production modules retain their absolute file names between runs.
    # Keep one immutable source path per revision, with fresh SQLite stores
    # and a fresh report directory for every invocation.
    root = Path(cache) / ("seekmemory-source-" + REVISION)
    root.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as package:
        package.extractall(root)
    sys.path.insert(0, str(root))
    try:
        runner = importlib.import_module("benchmarks.run")
        with tempfile.TemporaryDirectory(dir=cache) as temporary:
            output = Path(temporary) / "report"
            runner.main(["--repo", str(root), "--revision", REVISION, "--output-dir", str(output)])
            return (output / "memory.json").read_text(encoding="utf-8")
    finally:
        sys.path.remove(str(root))
