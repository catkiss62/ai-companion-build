#!/usr/bin/env python3
"""Guard the two regressions that previously passed gesture and import tests."""

from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
pet = (app / "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt").read_text()
caicai = (app / "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt").read_text()
jev = (app / "lib/core/ai/jev_decision_gateway.dart").read_text()
diagnostics = (app / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()

# The old +276 ACTION_DOWN guard did not shrink WindowManager's physical window.
assert re.search(r"WindowManager\.LayoutParams\(\s*windowPx,\s*windowPx,", pet)
assert "val nextWidth = nextHeight" in pet
assert "KEY_SQUARE_WINDOW_POSITION_RESTORED" in pet

# The native view must wait for Dart's event listener before starting a load.
init = caicai.split("    init {", 1)[1].split("    override fun getView", 1)[0]
assert "loadCurrentModel()" not in init
assert '"start" -> { loadCurrentModel()' in caicai
assert "stale_surface_ready_ignored" in caicai

assert "confidenceFloor" not in jev and "highest_probability_choice" in jev
assert "used_neutral_close_probability" in jev
assert "report['jevShortUsage']" in diagnostics
assert "report['playfulHeatTrace']" in diagnostics
assert "report['caicaiLive2d']" in diagnostics
print("+277 physical pet window, deferred Caicai load and Jev audit guard passed")
