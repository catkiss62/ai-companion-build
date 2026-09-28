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

# The trusted single window keeps a fixed idle mask; old logical bounds own
# movement and docking while larger action frames may extend past the bounds.
assert re.search(r"WindowManager\.LayoutParams\(\s*visualWidthPx,\s*visualHeightPx,", pet)
assert "maxOf(dp(PetOverlaySizing.visualWidthDp(normalized)), nextHeight + nextPaddingY * 2)" in pet
assert "petView.setOverflowGeometry(windowPx, paddingX, paddingY)" in pet
assert "TYPE_ACCESSIBILITY_OVERLAY" in pet
assert "logicalLimits(activeArea(layout), layout)" in pet
assert "entryWindowManager.addView(container, layout)" in pet
assert "setTouchableRegion(region)" in pet and "FLAG_NOT_TOUCHABLE" in pet
assert "installStandingReference(petView, manifest, frameCache, size)" in pet
assert "disableUnmaskedInput(" in pet
assert 'keepPetAboveChat("chat_input_enter")' not in service
assert 'keepPetAboveChat("chat_input_exit")' not in service
assert "private fun removeOwnedEntryWindow(view: View): Boolean" in service
assert "if (bubble != null && !removeOwnedEntryWindow(bubble))" in service
assert "live2dOnScreen" not in chat
# The native view retains a full-size GL buffer while the keyboard crops the
# visible conversation area. Preserve the scene passed to its camera.
assert "height: _caicaiEnabled ? _caicaiStableHeight : constraints.maxHeight" in chat
assert "sceneSize: Size(constraints.maxWidth, _caicaiStableHeight!)" in chat
viewport = (app / "lib/widgets/caicai_stage_viewport.dart").read_text()
assert "keyboardInset == 0 && availableHeight > _height!" in viewport
assert "AndroidView(" in (app / "lib/widgets/caicai_live2d_stage.dart").read_text()
assert "setZOrderMediaOverlay(true)" not in caicai
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
