#!/usr/bin/env python3
"""Guard the two regressions that previously passed gesture and import tests."""

from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
pet = (app / "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt").read_text()
caicai = (app / "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt").read_text()
chat = (app / "lib/features/chat/chat_page.dart").read_text()
service = (app / "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt").read_text()
jev = (app / "lib/core/ai/jev_decision_gateway.dart").read_text()
cedar = (app / "lib/core/mcp/cedar_toy_arcade_skill.dart").read_text()
runner = (app / "lib/core/ai/durable_generation_runner.dart").read_text()
context_judge = (app / "lib/core/mcp/cedar_context_intent_judge.dart").read_text()
diagnostics = (app / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()

# Use one wide drawing window. Its original idle-front alpha is the fixed
# system-level input region even while larger action frames are displayed.
assert re.search(r"WindowManager\.LayoutParams\(\s*visualWidthPx,\s*visualHeightPx,", pet)
assert "val nextWidth = maxOf(dp(PetOverlaySizing.visualWidthDp(normalized))" in pet
assert "petView.setOverflowGeometry(windowPx, paddingX, paddingY)" in pet
assert "TYPE_ACCESSIBILITY_OVERLAY" not in pet
assert "setTouchableRegion(region)" in pet and "FLAG_NOT_TOUCHABLE" in pet
assert "installStandingReference(petView, manifest, frameCache, size)" in pet
assert "disableUnmaskedInput(" in pet
assert 'keepPetAboveChat("chat_input_enter")' not in service
assert 'keepPetAboveChat("chat_input_exit")' not in service
assert "private fun removeOwnedEntryWindow(view: View): Boolean" in service
assert "if (bubble != null && !removeOwnedEntryWindow(bubble))" in service
assert "widget.active &&" in chat and "live2dOnScreen" in chat
assert "companion.visibility = View.GONE" in caicai
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
print("single pet layer, fixed idle-alpha input, deferred Caicai load and Jev guard passed")
