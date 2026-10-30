#!/usr/bin/env python3
"""Wiring gate paired with native Android and HTTP behavior tests."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
host = read("android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiCompanionView.java")
assert "extends GLSurfaceView" in host
assert "readyAfterDraw" in host and "releaseComplete.await" in host
assert "16_666_667L" in host
assert not (app / "android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiTextureSurface.java").exists()
repo = read("android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiModelRepository.kt")
assert 'Live2DProfiles.directory(profile)).canonicalFile' in repo
profiles = read("android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/Live2DProfiles.kt")
assert 'if (profile == CAICAI) "caicai-live2d" else "deepseek-live2d"' in profiles
assert "CaicaiModelPaths.relative(staging, maid)" in repo
assert "CaicaiModelPaths.relative(current, maid)" in repo
assert "relativeTo(staging)" not in repo
stage = read("lib/widgets/caicai_live2d_stage.dart")
assert "_watchLoading" in stage and "画面加载未完成" in stage
assert "exists ? '已导入模型'" not in stage
for p in ["ai/durable_generation_runner.dart",
          "immersive/immersive_room_controller.dart", "mcp/cedar_toy_autonomy_engine.dart",
          "phone/calendar_reminder_followup.dart"]:
    source = read("lib/core/" + p)
    assert "FinalReplyRoute(" in source and "finalRoute.useSecondChannel" in source, p
    assert "finalRoute.recordFailure(" in source, p
proactive = read("lib/core/desire/proactive_engine.dart")
# +347: proactive routing now lives in a candidate-only helper. Verify the
# actual delegation and its bounded retry rather than requiring obsolete
# inline route mutations. HTTP/cancellation/lease behavior is tested in Dart.
for token in ["FinalReplyRoute(secondChannelEnabled: finalProvider.isGeminiRelay,",
              "ProactiveFinalReplyRetry.generate<_ProactiveGenerationCandidate>",
              "route: finalRoute", "secondChannelConfigured: finalApiKey.isNotEmpty",
              "canContinue: proactiveRequestAllowed",
              "request: ({required bool secondChannel}) => request(gemini: secondChannel)",
              "validateSecondChannel: (result)",
              "FinalReplyFailurePolicy.incompleteResponseFailure(",
              "if (result.content.isEmpty) throw const EmptyFinalReplyException()"]:
    assert token in proactive, token
retry = read("lib/core/desire/proactive_final_reply_retry.dart")
policy = read("lib/core/ai/final_reply_failure_policy.dart")
assert "static const int maxGeminiAttempts = 2;" in policy
for token in ["if (route.useSecondChannel)", "if (!secondChannelConfigured)",
              "missing_gemini_final_reply_key",
              "attempt <= FinalReplyFailurePolicy.maxGeminiAttempts",
              "validateSecondChannel(candidate)",
              "if (candidate == null) return null",
              "on GenerationSuspendedByRuntimeGateException {\n            rethrow;",
              "on GenerationCancelledByUserException {\n            rethrow;",
              "route.recordFailure(failures.last)"]:
    assert token in retry, token
assert "FinalReplyFailurePolicy.isTransient" not in retry
assert retry.count("request(secondChannel: true)") == 1
assert retry.count("request(secondChannel: false)") == 1
success = retry.index("if (accepted)")
failure = retry.index("route.recordFailure(failures.last)")
fallback = retry.index("request(secondChannel: false)")
assert retry.index("request(secondChannel: true)") < success < failure < fallback
assert "return ProactiveReplyResult(" in retry[success:failure]
assert "if (!await canContinue()) return null;" in retry[failure:fallback]
assert retry.count("if (!await canContinue()) return null;") >= 3
assert "commitProactiveMessageIfCurrent" not in retry
assert (app / "test/proactive_final_reply_retry_test.dart").is_file()
assert "geminiAttempted" not in proactive and "geminiSucceeded" not in proactive
assert proactive.count("await generateCandidate(retryContext)") == 2
assert "generated = await generateFinal(correctionMessages)" in read("lib/core/ai/durable_generation_runner.dart")
assert "if (!finalProvider.isGeminiRelay && streamedToolPreamble.isNotEmpty && turnGoals.isEmpty)" in read("lib/core/ai/durable_generation_runner.dart")
assert "partialContent: usageLane == 'agent_tool_planning' ? '' : EmotionEnvelope.streamingVisible(content)" in read("lib/core/ai/durable_generation_runner.dart")
assert "FinalReplyRoute.prepareMessages(messages)" in read("lib/core/ai/deepseek_client.dart")
pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetExperimentalCalibration.kt")
for token in ["scale: Float = 1.51f", "widthScale: Float = 0.91f", "yDp: Float = 1f",
              "gamma: Float = 0.86f", "whitePoint: Int = 230", "saturation: Float = 1f"]:
    assert token in pet, token
print("Caicai native host, canonical import, visible final-reply routes and screenshot defaults wired")
