#!/usr/bin/env python3
"""Static end-to-end contract for v0.38.17 final-body single playback."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat = read("lib/features/chat/chat_page.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
presentation_policy = read(
    "lib/core/presentation/generation_presentation_policy.dart"
)
text = read("lib/widgets/action_tint_text.dart")
segments = read("lib/core/models/chat_segment.dart")
tts = read("lib/core/tts/tts_text_processor.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
rule_defaults = read("lib/core/rules/rule_layer_defaults.dart")
background = read("lib/core/platform/background_chat_command_server.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
overlay_formatter = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
phone = read("lib/features/phone/simulated_phone_page.dart")
visual_tests = read("test/chat_visuals_test.dart")
text_tests = read("test/action_tint_text_test.dart")
emotion_tests = read("test/emotion_contract_test.dart")
tts_tests = read("test/tts_text_processor_test.dart")
presentation_tests = read("test/generation_presentation_policy_test.dart")
snapshot_tests = read("test/overlay_generation_snapshot_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.17+116" in pubspec
assert "static const int schemaVersion = 33;" in database

# Reasoning is still provider-streamed, while every candidate body stays
# buffered until the emotion envelope and service guard approve one answer.
assert runner.count("emitDeltas: false,") >= 3
assert "if (!emitDeltas && delta.reasoning.isNotEmpty)" in runner
assert "onDelta?.call(DeepSeekDelta(reasoning: delta.reasoning))" in runner
assert "visibleAnswerStreamed" not in runner
assert "action: 'stream_preserved'" not in runner
assert "onDelta?.call(DeepSeekDelta(content: finalContent))" not in runner
assert "action: 'rewrite'" in runner

# The transient reasoning row yields atomically to the durable message. The
# final body uses its raw source for first playback and restored presentation.
assert "showGenerationDraft" in controller
assert "GenerationPresentationPolicy.showDraft(" in controller
assert "committedMessageIds.contains(id)" in presentation_policy
assert "controller.showGenerationDraft" in chat
assert "assistantTranscriptBlocks(message.content)" in chat
assert "message.displaySegments" not in chat
assert "ChatVisualResolver.chunks(" not in chat
assert "class _AssistantTranscriptSequence" in chat
assert "class _AssistantSegmentDivider" in chat
assert "padding: const EdgeInsets.symmetric(vertical: 16)" in chat
streaming_start = chat.index("class _StreamingBubble")
streaming_body = chat[streaming_start:]
assert "controller.streamingContent" not in streaming_body
assert "assistantStreamingTranscriptBlocks(content)" not in streaming_body
assert "List<String> assistantTranscriptBlocks(String text)" in visuals
assert "does not classify action vs dialogue" in visuals

# index(1).html novel presentation: dialogue is pale yellow and normal;
# everything outside corner quotes is visible white/ambient italic narration.
assert "const chatDialogueGold = Color(0xFFFDE68A);" in text
assert "fontStyle: FontStyle.italic" in text
assert "fontStyle: FontStyle.normal" in text
assert "style: segment.isDialogue ? dialogue : action" in text
assert "stripActionDelimitersForDisplay" in text
assert "subjectless narration remains visible and italic" in text_tests
assert "final transcript preserves subjectless narration without classification" in visual_tests

# Emotion metadata is parsed independently; it never classifies or rewrites
# narration. The model-facing contract requires subjectless action lines.
assert "EmotionEnvelope.parse(generated.content)" in runner
assert "emotion envelope stays independent from subjectless novel body" in emotion_tests
assert prompt.count("不写“我/她/角色名") >= 2
assert rules.count("默认省略主语") >= 3
assert "歪头看你，尾巴在身后轻轻扫了一下。" in prompt
assert "歪头看你，尾巴在身后轻轻扫了一下。" in rules
assert "legacyEditableRuleLayerSha256V03816" in rule_defaults
assert "...legacyEditableRuleLayerSha256V03816.entries" in database

# Dialogue-only TTS reads quoted speech directly and cannot lose subjectless
# narration through the legacy semantic segment parser.
assert "quotedDialogueParts" in segments
assert "final quoted = ChatSegmentCodec.quotedDialogueParts(text);" in tts
assert "subjectless novel narration is skipped while corner dialogue is read" in tts_tests

# The native overlay follows the same raw-body typography and never exposes a
# cross-engine checkpoint body before durable commit.
assert "content: ''," in background
assert "unfinished snapshots can share reasoning without a candidate body" in snapshot_tests
assert "OverlayDialogueFormatter.actionRanges(visible)" in overlay
assert "StyleSpan(Typeface.ITALIC)" in overlay
assert "ForegroundColorSpan(Color.rgb(253, 230, 138))" in overlay
assert "fun dialogueRanges(value: String)" in overlay_formatter
assert 'onOpenChat = { showChatOverlay("pet_double_tap_menu") }' in overlay
assert 'smallButton("打开") { openFullApp(openChat = true) }' in overlay

# Preserve already accepted UI settings and keep later work out of this batch.
assert "double _panelOpacity = 0.75;" in chat
assert "horizontal: 14" in chat and "vertical: 11" in chat
assert "class ReferenceUnlockControl" in phone
assert "static const double slideDistance = 100" in phone
assert "reasoning_translation" not in database

assert "python3 tools/validate_v03817_final_body_single_playback.py" in workflow
assert "grep -Fqx 'version: 0.38.17+116' app/pubspec.yaml" in workflow
assert "AI-Companion-v0.38.17-116-Final-Body-Single-Playback-APK" in workflow
assert "agent/v03817-final-body-single-playback" in workflow

print("v0.38.17 final-body single playback validated")
