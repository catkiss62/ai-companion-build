#!/usr/bin/env python3
"""Guard the two regressions that previously passed gesture and import tests."""

from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
pet = (app / "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt").read_text()
caicai = (app / "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt").read_text()
jev = (app / "lib/core/ai/jev_decision_gateway.dart").read_text()
cedar = (app / "lib/core/mcp/cedar_toy_arcade_skill.dart").read_text()
runner = (app / "lib/core/ai/durable_generation_runner.dart").read_text()
context_judge = (app / "lib/core/mcp/cedar_context_intent_judge.dart").read_text()
diagnostics = (app / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()

# HyperOS rejected the hidden insets field. The input window itself is now
# the 112/152/200dp rectangle; a trusted non-touchable window draws wide clips.
assert re.search(r"WindowManager\.LayoutParams\(\s*windowPx,\s*windowPx,", pet)
assert "val nextWidth = nextHeight" in pet
assert "TYPE_ACCESSIBILITY_OVERLAY" in pet and "FLAG_NOT_TOUCHABLE" in pet
assert "visual.setOverflowGeometry(windowPx, visualPadding)" in pet
assert "PetTouchableRegion(container)" not in pet
assert "updateTouchRegionStatus(layout)" in pet

# The native view must wait for Dart's event listener before starting a load.
init = caicai.split("    init {", 1)[1].split("    override fun getView", 1)[0]
assert "loadCurrentModel()" not in init
assert '"start" -> { loadCurrentModel()' in caicai
assert "stale_surface_ready_ignored" in caicai

assert "confidenceFloor" not in jev and "highest_probability_choice" in jev
assert "used_neutral_close_probability" in jev
assert "contextualDecisionCandidate" in cedar
assert "previousAssistantText" in cedar and "activeGameTitle" in cedar
assert "!finalProvider.isGeminiRelay ||" in runner
assert "CedarContextIntentJudge().shouldOfferTools" in runner
assert "usageLane: 'cedar_context_intent'" in context_judge
assert "report['jevShortUsage']" in diagnostics
assert "report['playfulHeatTrace']" in diagnostics
assert "report['caicaiLive2d']" in diagnostics
print("+280 rectangular system input, trusted wide visual, deferred Caicai load and Jev guard passed")
