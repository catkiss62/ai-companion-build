#!/usr/bin/env python3
"""Wiring gate paired with native Android and HTTP behavior tests."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
host = read("android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiCompanionView.java")
assert "extends GLSurfaceView" in host
assert "readyAfterDraw" in host and "releaseComplete.await" in host
assert "33_333_333L" in host
assert not (app / "android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiTextureSurface.java").exists()
repo = read("android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiModelRepository.kt")
assert '"caicai-live2d").canonicalFile' in repo
assert "CaicaiModelPaths.relative(staging, maid)" in repo
assert "CaicaiModelPaths.relative(current, maid)" in repo
assert "relativeTo(staging)" not in repo
stage = read("lib/widgets/caicai_live2d_stage.dart")
assert "_watchLoading" in stage and "画面加载未完成" in stage
assert "exists ? '已导入模型'" not in stage
for p in ["ai/durable_generation_runner.dart", "desire/proactive_engine.dart",
          "immersive/immersive_room_controller.dart", "mcp/cedar_toy_autonomy_engine.dart",
          "phone/calendar_reminder_followup.dart"]:
    source = read("lib/core/" + p)
    assert "FinalReplyRoute(" in source and "finalRoute.useSecondChannel" in source, p
    assert "finalRoute.recordFailure(" in source, p
proactive = read("lib/core/desire/proactive_engine.dart")
assert "geminiAttempted" not in proactive and "geminiSucceeded" not in proactive
assert proactive.count("await generateCandidate(retryContext)") == 2
assert "generated = await generateFinal(correctionMessages)" in read("lib/core/ai/durable_generation_runner.dart")
assert "if (!finalProvider.isGeminiRelay && streamedToolPreamble.isNotEmpty)" in read("lib/core/ai/durable_generation_runner.dart")
assert "FinalReplyRoute.prepareMessages(messages)" in read("lib/core/ai/deepseek_client.dart")
pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetExperimentalCalibration.kt")
for token in ["scale: Float = 1.51f", "widthScale: Float = 0.91f", "yDp: Float = 1f",
              "gamma: Float = 0.86f", "whitePoint: Int = 230", "saturation: Float = 1f"]:
    assert token in pet, token
print("Caicai native host, canonical import, visible final-reply routes and screenshot defaults wired")
