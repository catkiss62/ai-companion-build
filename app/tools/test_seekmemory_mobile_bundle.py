"""Execute the exact source archive embedded in the APK, twice in one interpreter."""
import json
from pathlib import Path
import sys
import tempfile

app = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(app / "android/app/src/main/python"))
from seekmemory_android import run, REVISION

fixed = json.loads((app / "assets/memory_benchmark/seekmemory.json").read_text())
with tempfile.TemporaryDirectory() as cache:
    for _ in range(2):
        report = json.loads(run(app / "android/app/src/main/assets/seekmemory-original.zip", cache))
        assert report["acceptance"]["passed"], report["acceptance"]
        assert report["provenance"]["code_revision"] == REVISION == fixed["revision"]
        for key in ("evaluator_sha256", "corpus_sha256"):
            assert report[key] == fixed["reference"][key]
        assert len(report["paths"]["full_pipeline"]["rows"]) == len(fixed["queries"]) == 8
print("Bundled SeekMemory source passed both fresh runs.")
