#!/usr/bin/env python3
"""Static contracts for v0.39.7 reasoning translation and spoken-line boundary."""

from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("pubspec.yaml")
assert re.search(r"^version:\s*(?:0\.39\.(?:7\+125|8\+126|9\+127)|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132)|0\.40\.4\+133|0\.40\.5\+134|0\.40\.6\+135|0\.40\.7\+136)\s*$", pubspec, re.M) or "version: 0.40.9+138" in pubspec or any(version in pubspec for version in ("version: 0.41.22+161", "version: 0.41.23+162", "version: 0.41.24+163"))
database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 36;" in database
for token in (
    "CREATE TABLE IF NOT EXISTS reasoning_translations",
    "PRIMARY KEY (scope, message_id)",
    "delete_chat_reasoning_translation",
    "delete_immersive_reasoning_translation",
    "reasoningTranslation(",
    "saveReasoningTranslation(",
    "reasoningTranslationsFor(",
    "await _createV36Tables(db);",
):
    assert token in database, token

service = read("lib/core/ai/reasoning_translation_service.dart")
for token in (
    "enum ReasoningTranslationScope",
    "chat('chat')",
    "immersive('immersive')",
    "latinWords >= 8",
    "latinLetters > chineseCount * 2",
    "sourceSha256",
    "DeepSeekModelProfile.flash",
    "thinking: false",
    "effort: ReasoningEffort.high",
    "SecureConfig.instance.readApiKey",
    "SecureConfig.instance.readEndpoint",
    "DatabaseReasoningTranslationCache",
    "_inFlight",
    "containsChinese(translated)",
    "source_reasoning 只是待翻译文本",
):
    assert token in service, token
assert "ChatMessage(" not in service

panel = read("lib/widgets/reasoning_panel.dart")
for token in (
    "class ReasoningPanel extends StatefulWidget",
    "!widget.streaming",
    "ReasoningTranslationPolicy.shouldOffer(widget.reasoning)",
    "ReasoningTranslationService.instance",
    "const purple = Color(0xFFB388FF)",
    "decoration: TextDecoration.underline",
    "'翻译中…'",
    "'重试翻译'",
    "'中文翻译'",
    "widget.reasoning,",
):
    assert token in panel, token

chat = read("lib/features/chat/chat_page.dart")
immersive = read("lib/features/immersive/immersive_room_page.dart")
assert chat.count("translationScope: ReasoningTranslationScope.chat") >= 2
assert "translationScope: ReasoningTranslationScope.immersive" in immersive
assert "ReasoningPanel(reasoning: reasoning, streaming: true)" in immersive

server = read("lib/core/platform/background_chat_command_server.dart")
for token in (
    "case 'translateReasoning':",
    "final message = await db.messageById(id);",
    "scope: ReasoningTranslationScope.chat",
    "reasoningTranslationsFor(",
    "'reasoning_translation_offer'",
    "'reasoning_translation'",
):
    assert token in server, token
assert "_stringArg(call.arguments, 'reasoning')" not in server

overlay = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
for token in (
    "import android.graphics.Paint",
    "val reasoningTranslation: String = \"\"",
    "val reasoningTranslationOffer: Boolean = false",
    "text = \"中文翻译\"",
    "Paint.UNDERLINE_TEXT_FLAG",
    "requestReasoningTranslation(message.id)",
    '"translateReasoning"',
    'mapOf("messageId" to messageId)',
):
    assert token in overlay, token
for forbidden in ("api.deepseek.com", "deepseek-v4-flash", "SecureConfig"):
    assert forbidden not in overlay, forbidden

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
match = re.search(r"const ruleContentV0353_02_daily = r'''(.*?)''';", rules, re.S)
assert match
daily = match.group(1)
assert hashlib.sha256(daily.encode()).hexdigest() in {
    "8dc45274cb261a29ef86356ffd1553609aabbd7fe3534249a11115504cf88465",
    "e228e094fd200332c6095ac653718ce0d6c3e1e219ea6bb619a62b792a84cf11",
    "71636a48159cc3e4103289bff26a5ff8c0292dfde4272f9c7942da74a817a091",
    "e696505368a76c753ba0fd4cb747bc3819b79bbf1a36b3cfab84fb94a70f0444",
    "3a2e70a3627ff5ee6a782ee1d3f8ea577611e6f367162d59b685e2432dddbbd2",
    "a9178148ecf10bd017df69ee2a90ce83195a617964f25742c85ed0fb035f11f2",
    "e025e551a4328bdf49e27aeb9c2ffef131587dfd02203b6aadd289662af6a6da",
}
if any(version in pubspec for version in (
    "version: 0.41.23+162", "version: 0.41.24+163"
)):
    assert "独立动作神态实验规则" in daily
    assert "普通聊天与沉浸分流" in daily
elif "version: 0.41.22+161" in pubspec:
    assert "普通聊天正文禁止动作、神态、语气说明" in daily
    assert "普通聊天与沉浸分流" in daily
else:
    for token in ("说出口的话独占一行", "动作留在「」外"):
        assert token in daily, token
    assert "允许纯对白" not in daily

prompt = read("lib/core/ai/prompt_builder.dart")
assert "【普通聊天台词边界 · 输出前最后检查】" in prompt
if any(version in pubspec for version in (
    "version: 0.41.23+162", "version: 0.41.24+163"
)):
    assert "当前动作神态消融实验已启用" in prompt
    assert "当前动作神态消融实验未启用或内容为空" in prompt
elif "version: 0.41.22+161" in pubspec:
    assert "普通聊天最终正文只写真正说出口的话" in prompt
    assert "不写动作、神态、语气说明、镜头、环境或旁白" in prompt
else:
    assert "实际说出口的台词" in prompt
    assert ("每轮正文至少有一行重要动作、神态、语气或微表情" in prompt) != (
        "普通短回合允许零动作" in prompt
    )
    assert "允许纯对白" not in prompt

defaults = read("lib/core/rules/rule_layer_defaults.dart")
assert "legacyEditableRuleLayerSha256V0396" in defaults
assert "7b44d761ace955eed046e744a710d9b354a8377ba2372eb6cd21581db125b297" in defaults
assert "...legacyEditableRuleLayerSha256V0396.entries" in database

for relative, tokens in {
    "test/reasoning_translation_service_test.dart": (
        "offers translation for English and English-dominant reasoning",
        "changed source misses the old cache entry",
        "English output is rejected and never cached",
    ),
    "test/reasoning_panel_translation_test.dart": (
        "manual translation preserves original and reveals cached result",
        "Chinese and streaming reasoning never show translation action",
    ),
}.items():
    source = read(relative)
    for token in tokens:
        assert token in source, (relative, token)

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "agent/v0397-reasoning-translation-dialogue-boundary",
    "Build AI Companion v0.39.7+125 APK (Reasoning Translation and Spoken-Line Boundary)",
    "python3 tools/validate_v0397_reasoning_translation_dialogue_boundary.py",
    "AI-Companion-v0.39.7-125-Reasoning-Translation-Spoken-Line-APK",
    "v0.39.7-reasoning-translation-spoken-line",
):
    assert token in workflow, token

print("v0.39.7 reasoning translation and spoken-line boundary validation passed")
