#!/usr/bin/env python3
"""Static contracts for v0.39.4 Rule 02 and immersive chat UI/TTS."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


assert "version: 0.39.4+122" in read("pubspec.yaml")
assert "static const int schemaVersion = 35;" in read(
    "lib/core/database/app_database.dart"
)

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
for token in (
    "不加括号并默认省略主语",
    "不要写“我/她/角色名歪头看你”",
    "省略主语的动作默认只描述自己",
    "不替他编写动作、台词、内心或没有真实提供的反应",
    "严格遵守规则02【动作与神态格式】",
):
    assert token in rules, token

defaults = read("lib/core/rules/rule_layer_defaults.dart")
database = read("lib/core/database/app_database.dart")
assert "legacyEditableRuleLayerSha256V0393" in defaults
assert "...legacyEditableRuleLayerSha256V0393.entries" in database

prompt = read("lib/core/ai/prompt_builder.dart")
assert "普通聊天正文的人称与可见 reasoning 分开" not in prompt

formatter = read("lib/widgets/action_tint_text.dart")
formatter_test = read("test/action_tint_text_test.dart")
for token in (
    "splitNovelDialogueText",
    "'“': '”'",
    "'\"': '\"'",
    "expectedClosers",
):
    assert token in formatter, token
for token in (
    "immersive prose recognizes curly and ASCII dialogue quotes",
    "immersive prose keeps mixed nested quotes in one dialogue span",
    "immersive curly quote remains tinted while streaming",
):
    assert token in formatter_test, token

controller = read("lib/core/immersive/immersive_room_controller.dart")
for token in (
    "TtsService(db: this.db)",
    "TtsPlaybackQueue(",
    "TtsPlaybackPhase ttsPhaseForMessage",
    "Future<void> speakMessage(ImmersiveMessage message)",
    "Future<void> stopSpeech()",
    "await ttsPlayback.stop();",
):
    assert token in controller, token

page = read("lib/features/immersive/immersive_room_page.dart")
for token in (
    "ChatTimestampFormatter.shouldShowDateSeparator",
    "ChatTimestampFormatter.time(message.createdAt)",
    "_ImmersiveUserBubbleSurface",
    "_ImmersiveSpeechActionButton",
    "opacity.clamp(0.18, 1)",
    "bottomRight: Radius.circular(4)",
    "child: const Text('NSFW')",
    "直接删除不会执行“整理并结束”",
    "不会新增长期记忆",
):
    assert token in page, token
assert "child: controller.nsfwRouting" not in page

workflow = read("../.github/workflows/build-apk.yml")
assert "python3 tools/validate_v0394_immersive_chat_ui_tts.py" in workflow
assert "agent/v0394-immersive-chat-ui-tts" in workflow
assert "AI-Companion-v0.39.4-122-Immersive-Chat-UI-TTS-APK" in workflow

print("v0.39.4 immersive chat UI/TTS contracts passed")
