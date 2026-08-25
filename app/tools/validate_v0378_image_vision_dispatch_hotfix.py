#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
controller = read("lib/features/chat/chat_controller.dart")
recovery = read("lib/core/ai/durable_generation_recovery.dart")
database = read("lib/core/database/app_database.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
sound = read("lib/core/tts/emotion_sound_service.dart")
bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/EmotionSoundBridge.kt"
)
chat = read("lib/features/chat/chat_page.dart")
volume_tests = read("test/emotion_sound_volume_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.37.8+97" in pubspec
assert "static const int schemaVersion = 31;" in database

image_start = controller.index("Future<void> _analyzeImageMessage")
image_end = controller.index("Future<void> discardPreparedImage", image_start)
image_flow = controller[image_start:image_end]
assert "resumePendingGeneration" not in image_flow
assert (
    "trustedGeneration = await "
    "db.completeAttachmentVisionAndCreateGeneration" in image_flow
)
assert "_runTrustedCurrentProcessGeneration(" in image_flow
assert "leaseAlreadyHeld: true" in image_flow
assert image_flow.index("'chat_turn_lease'") < image_flow.index(
    "trustedGeneration = await"
)

resume_start = controller.index("Future<void> resumePendingGeneration")
resume_end = controller.index("Future<void> _scheduleGenerationRecovery", resume_start)
resume = controller[resume_start:resume_end]
assert "generationRecovery.recoverOne()" in resume
assert "generationRunner.run" not in resume
assert "cancelGenerationJobByUser(job.id)" in recovery
assert "runner.run" not in recovery

assert controller.count("_executeCurrentProcessGeneration(") >= 3
execute_start = controller.index("Future<void> _executeCurrentProcessGeneration")
execute_end = controller.index(
    "Future<void> _runTrustedCurrentProcessGeneration", execute_start
)
execute = controller[execute_start:execute_end]
for token in (
    "generationRunner.run(",
    "onEmotionCue: startEmotionCue",
    "ttsPlayback.beginStream(",
    "ttsPlayback.playText(",
    "memoryExtractor.extractFromTurn(",
    "recentGenerationInterruptions",
):
    assert token in execute, token

assert "Future<GenerationJob> completeAttachmentVisionAndCreateGeneration" in database
for token in (
    "attachmentVisionDiagnosticStats",
    "latestErrorCategory",
    "visionSummaryIncluded",
    "rawErrorIncluded",
):
    assert token in database, token
assert "'imageVision': visionDiagnostics" in diagnostics
for token in (
    "'visionImageBytesIncluded': false",
    "'visionPathsIncluded': false",
    "'visionCaptionIncluded': false",
    "'visionSummaryIncluded': false",
    "'visionRawErrorIncluded': false",
):
    assert token in diagnostics, token

assert database.count("emotion_sound_volume") >= 4
assert "normalizedVolume" in sound
assert "EmotionSoundVolumePlayer" in sound
# Preserve the historical v0.37.4 completion-fenced player contract.
assert "await player.play(base64Encode(bytes))" in sound
assert "'volume': _volume" in sound
assert 'call.argument<Number>("volume")' in bridge
assert "coerceIn(0f, 1f)" in bridge
assert "setVolume(volume, volume)" in bridge
assert "情绪音效音量" in chat
assert "'emotion_sound_volume'" in chat
for title in (
    "emotion cue volume defaults to initial 15 percent",
    "emotion cue volume preserves stored value and clamps safely",
):
    assert title in volume_tests, title

for token in (
    "Build AI Companion v0.37.8+97 APK (Image Vision Dispatch Hotfix)",
    "validate_v0378_image_vision_dispatch_hotfix.py",
    "AI-Companion-v0.37.8-97-Image-Vision-Dispatch-Hotfix-APK.apk",
    "v0.37.8-image-vision-dispatch-hotfix-test",
    ".ci/v0378-monitor.txt",
):
    assert token in workflow, token

print("v0.37.8 image vision dispatch, diagnostics and emotion volume validation passed")
