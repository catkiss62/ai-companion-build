#!/usr/bin/env python3
"""Static contracts for v0.41.33 competence, curation and emotion fixes."""

from pathlib import Path


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
dialogue = read("app/lib/core/ai/dialogue_expression_plan.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
qwen = read("app/lib/core/ai/qwen_vision_client.dart")
album_engine = read(
    "app/lib/core/phone/companion_album_discovery_engine.dart"
)
chat_controller = read("app/lib/features/chat/chat_controller.dart")
database = read("app/lib/core/database/app_database.dart")
portrait = read("app/lib/widgets/chat_portrait_stage.dart")
visuals = read("app/lib/core/presentation/chat_visuals.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
dialogue_test = read("app/test/dialogue_expression_plan_test.dart")
vision_test = read("app/test/image_vision_test.dart")
visual_test = read("app/test/chat_visuals_test.dart")
prompt_test = read("app/test/prompt_generation_reminder_test.dart")
shape_test = read(
    "app/test/conversation_initiative_ablation_telemetry_test.dart"
)
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert "version: 0.41.33+172" in pubspec
assert "static const int schemaVersion = 46;" in database
assert "buildLabel = 'v0.41.33+172'" in self_reader

for token in (
    "DialogueResponseMode.challenge",
    "太简单",
    "别总代入自己",
    "跳脱一点",
    "猜谜",
    "题面没有直接暴露答案",
    "不能只用角色语气认错后重复同一结构",
    "不要改写成标准助手答题模板",
):
    assert token in dialogue, token

assert prompt.count("'content': dialogueExpressionPlan.render(),") == 3
assert prompt.count("'content': visibleChineseGenerationReminder(") == 3
for token in (
    "【能力与人格边界】",
    "不得降低事实判断、推理、任务质量、工具使用",
    "普通闲聊不必表现成助手",
    "不要先生成一份中性助手答案",
    "不要把用户写成第三人称“她”或“他”",
):
    assert token in prompt, token

for token in (
    "riddles and explicit creative challenges use quality-first routing",
    "casual guessing and ordinary games do not become task mode",
    "competence is a floor while personality still chooses expression",
    "layers['dialogueExpressionPlan'], isTrue",
):
    assert token in dialogue_test + prompt_test + shape_test, token

for token in (
    "像策展人一样判断",
    "氛围与情绪表达",
    "非模板化程度",
    "独立欣赏或共同回忆价值",
    "置信度至少 0.8",
    "普通功能性图片即使制作规范，也不自动等于收藏级画面",
    "albumSave: assessForAlbum && album['save'] == true",
):
    assert token in qwen, token
for forbidden in (
    "纯色或渐变横幅",
    "明确成人向或裸露图片必须 save=false",
    "assessForAlbum && !adultContent",
    "App 图标",
    "Logo",
    "水印",
    "AI 生成",
):
    assert forbidden not in qwen, forbidden

assert "caption: visionContext" in album_engine
assert "normalized.length <= 600" in album_engine
assert "bounded_untrusted_context_v04133" in database
assert "adult_rejected" not in album_engine
assert "adult_rejected" not in chat_controller
assert "adult metadata does not override a positive album decision" in vision_test
assert "expect(result.albumSave, isTrue)" in vision_test

assert "final effectExtent = ChatPortraitStage.effectExtentFor" in portrait
assert "width: effectExtent" in portrait
assert "height: effectExtent" in portrait
assert "height: constraints.maxHeight * anchor.size" not in portrait
assert visuals.count("size: .50") == 2
assert visuals.count("left: .25") == 2
assert "enlarged emotion effect remains a width-derived square" in visual_test

for token in (
    "agent/v04133-competence-curation-emotion",
    "Build AI Companion v0.41.33+172 APK",
    "AI-Companion-v0.41.33-172-Competence-Curation-Emotion-APK",
    "validate_v04133_competence_curation_emotion.py",
):
    assert token in workflow, token

assert "v0.41.33 能力—人格解耦、视觉策展与情绪特效收口" in ledger
assert "不修改或复制其正文" in ledger
assert "原始备份、聊天正文、附件与 API 配置不得提交" in ledger

print("v0.41.33 competence curation emotion validation passed")
