#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert "version: 0.37.4+93" in read("pubspec.yaml")
assert "static const int schemaVersion = 28;" in read(
    "lib/core/database/app_database.dart"
)

sound = read("lib/core/tts/emotion_sound_service.dart")
assert "ai_companion/emotion_sound" in sound
assert "NativeTtsProvider" not in sound
assert "auto_tts" not in sound
assert "await player.play(base64Encode(bytes))" in sound

bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/EmotionSoundBridge.kt"
)
for token in (
    "MediaPlayer",
    "USAGE_ASSISTANCE_SONIFICATION",
    "setOnCompletionListener",
    "result.success(null)",
    "emotion-sound-io",
):
    assert token in bridge, token

main = read("android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt")
assert "EmotionSoundBridge(this, flutterEngine)" in main
assert "emotionSoundBridge?.dispose()" in main

queue = read("lib/core/tts/tts_playback_queue.dart")
assert queue.count("Future<void>? leadIn") >= 3
assert "await session.waitForLeadIn();" in queue
assert "if (!_isActive(session)) return;" in queue

runner = read("lib/core/ai/durable_generation_runner.dart")
assert "onEmotionCue?.call(emotionKey)" in runner
assert "preserveProviderReasoning(generated.reasoning)" in runner
assert "latinWords >= 6" not in runner

controller = read("lib/features/chat/chat_controller.dart")
for token in (
    "onEmotionCue: startEmotionCue",
    "streamLeadIn = Completer<void>()",
    "leadIn: streamLeadIn!.future",
    "leadIn: leadIn",
    "emotionSounds.play(visual)",
    "Future.wait<void>",
):
    assert token in controller, token

chat = read("lib/features/chat/chat_page.dart")
for token in (
    "chat_last_presented_assistant_id",
    "_restorePresentationCursor",
    "_SingleBubbleTypewriterText",
    "message.isProactive && animateSegments",
):
    assert token in chat, token
assert "onEmotionSound" not in chat

tint = read("lib/widgets/action_tint_text.dart")
# Compatibility contract: v0.39.3 replaced the one-level regex with a balanced scanner so quoted
# phrases inside dialogue do not terminate the highlighted outer dialogue.
for token in (
    "List<DialogueTextSegment> splitDialogueText(String text)",
    "var depth = 1;",
    "final reachedEnd = index == text.length;",
):
    assert token in tint, token

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
assert any(token in overlay for token in (
    "ForegroundColorSpan(Color.rgb(253, 230, 138))",
    "ForegroundColorSpan(dialogueTintColor())",
))
assert "Color.rgb(253, 230, 138)" in overlay
assert "OverlayDialogueFormatter.dialogueRanges(visible)" in overlay
assert "OverlayDialogueFormatter.visibleText(value)" in overlay

prompt = read("lib/core/ai/prompt_builder.dart")
if any(
    version in read("pubspec.yaml")
    for version in (
        "version: 0.41.27+166",
        "version: 0.41.28+167",
        "version: 0.41.29+168",
        "version: 0.41.30+169",
        "version: 0.41.31+170",
    )
):
    assert "没打算给任何人看的当下心声" in prompt
else:
    assert "reasoning_content 使用自然简体中文，写成第一人称正在发生的内心" in prompt
assert "技术、事实与复杂任务直接推演证据、代码、因果和不确定处" in prompt

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.37.4+93 APK (Audio & Presentation Stabilization)",
    "validate_v0374_audio_presentation_stabilization.py",
    "AI-Companion-v0.37.4-93-Audio-Presentation-Stabilization-APK.apk",
    ".ci/v0374-monitor.txt",
):
    assert token in workflow, token

print("v0.37.4 audio, presentation cursor and rendering validation passed")
