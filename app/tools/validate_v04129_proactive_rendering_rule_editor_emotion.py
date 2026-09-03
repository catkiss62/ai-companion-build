#!/usr/bin/env python3
"""Static contracts for v0.41.29 proactive/rendering/editor/emotion fixes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
self_reader = read("lib/core/agent/agent_self_reader.dart")
database = read("lib/core/database/app_database.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
presentation = read("lib/core/presentation/chat_visuals.dart")
rendering = read("lib/widgets/action_tint_text.dart")
immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
immersive_rules = read("lib/core/rules/rule_layer_content_immersive.dart")
editor = read("lib/features/settings/rule_layers_page.dart")
editor_codec = read("lib/core/rules/rule_layer_group_editor_codec.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
chat_controller = read("lib/features/chat/chat_controller.dart")
tts = read("lib/core/tts/tts_service.dart")
emotion_sound = read("lib/core/tts/emotion_sound_service.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert any(
    version in pubspec
    for version in (
        "version: 0.41.29+168",
        "version: 0.41.30+169",
        "version: 0.41.31+170",
    )
)
assert any(
    version in self_reader
    for version in (
        "buildLabel = 'v0.41.29+168'",
        "buildLabel = 'v0.41.30+169'",
        "buildLabel = 'v0.41.31+170'",
    )
)
assert "static const int schemaVersion = 45" in database

for token in (
    "主动消息若发送，最终正文只允许两种可见段",
    "必须独占一行并写成（动作）",
    "必须独占一行并写成「对白」",
    "且至少有一段对白",
    "不要输出无括号旁白、私下心声或裸露自然语言",
):
    assert token in prompt, token

assert "return '（${segment.text}）';" in presentation
assert presentation.count("size: .50") == 2
assert "isDialogue: trimmed.startsWith('“')" in rendering
assert "trimmed.startsWith('「')" not in rendering
for token in ("中文弯引号“”", "5至9个自然段"):
    assert token in (immersive_prompt + immersive_rules), token
assert "引号只是叙述的一部分" in immersive_rules

for token in (
    "composeEditableRuleLayerGroup",
    "parseEditableRuleLayerGroup",
    "defaultEmptyKeys.contains(layer.key)",
    "layer.content.trim().isEmpty",
    "正文不能为空",
):
    assert token in editor_codec, token
assert "firstWhere((content) => content.isNotEmpty" in editor
assert "（暂无正文）" in editor

for token in (
    "EmotionSoundService? emotionSoundService",
    "final emotionLeadIn = emotionSounds.play(visual)",
    "leadIn: emotionLeadIn",
):
    assert token in (proactive + chat_controller), token
for token in ("Future<void>? leadIn", "leadIn: leadIn"):
    assert token in tts, token
assert "if (asset == null" in emotion_sound
assert "emotion_sound_enabled" in emotion_sound
for token in (
    "backgroundEmotionSoundBridge",
    "EmotionSoundBridge(applicationContext, createdEngine)",
    "backgroundEmotionSoundBridge?.dispose()",
):
    assert token in overlay, token

assert "validate_v04129_proactive_rendering_rule_editor_emotion.py" in workflow
assert any(
    branch in workflow
    for branch in (
        "agent/v04129-proactive-rendering-rule-editor-emotion",
        "agent/v04130-presentation-ablation-upload-diagnostics",
    )
)

print("v0.41.29 proactive/rendering/editor/emotion validation passed")
