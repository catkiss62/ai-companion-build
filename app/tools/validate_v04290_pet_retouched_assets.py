#!/usr/bin/env python3
"""Verify revised files cover the existing runtime frame references exactly."""
import json
from prepare_retouched_pet_frames import APP, DESTINATION, read_index, validate

outputs = validate(read_index())
manifest = json.loads((DESTINATION / "assets/manifests/actions.json").read_text())
# These four upstream groups are not played: right gait mirrors left; sleep holds
# the last sleep_enter frame. All other referenced groups are retained in order.
unused = {"sleep", "walk_side_right", "walk_start_right", "walk_stop_right"}
expected = {p for key, asset in manifest["assets"].items() if key not in unused
            for frames in asset["frames"].values() for p in frames}
expected |= {f"runtime_overrides/yawning/sleepy_yawn_{s}.png" for s in (187, 238, 306)}
assert {o["target"] for o in outputs} == expected
workflow = (APP.parent / ".github/workflows/build-apk.yml").read_text()
assert workflow.index("python3 tools/run_validation_suite.py") < workflow.index(
    "python3 tools/prepare_retouched_pet_frames.py --apply") < workflow.index("run: flutter build apk")
assert "prepare_retouched_pet_frames.py --verify-apk" in workflow
print("v0.42.90 pet revision: complete existing frame coverage and build/verify order OK")
