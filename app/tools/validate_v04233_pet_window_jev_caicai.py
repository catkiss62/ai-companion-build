#!/usr/bin/env python3
"""Guard the two regressions that previously passed gesture and import tests."""

from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
pet = (app / "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt").read_text()
caicai = (app / "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt").read_text()
jev = (app / "lib/core/ai/jev_decision_gateway.dart").read_text()
diagnostics = (app / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()

# +277 square drawing was a visual regression. Preserve wide drawing and
# publish the independent logical input region to WindowManager.
assert re.search(r"WindowManager\.LayoutParams\(\s*visualWidthPx,\s*windowPx,", pet)
assert "val nextWidth = dp(PetOverlaySizing.visualWidthDp(normalized))" in pet
assert "KEY_VISUAL_WIDTH_RESTORED" in pet
region = (app / "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetTouchableRegion.kt").read_text()
assert "touchableRegion" in region and "mode.invoke(data, 3)" in region
assert "overlayPetTouchRegion" in region

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
print("+278 independent pet input region, deferred Caicai load and Jev audit guard passed")
