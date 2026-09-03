#!/usr/bin/env python3
"""Static contracts for v0.41.28 immersive identity/rendering runtime."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
self_reader = read("lib/core/agent/agent_self_reader.dart")
database = read("lib/core/database/app_database.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
intimacy = read("lib/core/rules/rule_layer_content_v04128.dart")
immersive_rules = read("lib/core/rules/rule_layer_content_immersive.dart")
immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
immersive_router = read("lib/core/immersive/immersive_nsfw_router.dart")
controller = read("lib/core/immersive/immersive_room_controller.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
proactive_presentation = read("lib/core/desire/proactive_presentation.dart")
somatic = read("lib/core/somatic/somatic_policy.dart")
worldbook = read("lib/core/reference/world_book_presets.dart")
reference = read("lib/core/reference/reference_library.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
rendering = read("lib/widgets/action_tint_text.dart")
overlay_rendering = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert "version: 0.41.28+167" in pubspec
assert "buildLabel = 'v0.41.28+167'" in self_reader
assert "static const int schemaVersion = 45" in database

for token in (
    "buildIntimacyCoreV04128",
    "不得把男性用户的肉棒",
    "自然停顿与后续衔接",
    "不得为了“连续”自动消费下一阶段",
):
    assert token in (intimacy + defaults), token

for token in (
    "deterministicClimaxEvent",
    "hasUnresolvedUserNear",
    "user_near",
    "user_release",
    "ai_release",
    "hold",
):
    assert token in immersive_router, token

for token in (
    "SomaticEngine",
    "captureUserTurn",
    "buildPromptSection",
):
    assert token in (controller + immersive_prompt), token
assert "触碰|碰触|碰了碰|碰一下|碰" in somatic

for token in (
    "worldBookOptimizedHumorV04128",
    "worldbook_humor_cleanup_v04128_applied",
    "worldbook_daily_rendering_v04128_applied",
    "worldBookDailyConversationV04128",
    "chat|proactive",
    "禁止用性别错位",
):
    assert token in (worldbook + database), token
assert "priority 也只排序表达模块" in reference

for token in (
    "中文弯引号“”",
    "每段对白独占一个自然段",
    "5至9个自然段",
    "continuationBoundary",
):
    assert token in (immersive_rules + immersive_prompt), token

for token in (
    "sourceStartsWithAction",
    "splitNovelDialogueText",
    "trimmed.startsWith('“')",
):
    assert token in rendering, token
assert "生成源必须把动作独占一行并写成（动作）" in prompt
for token in ("sourceStartsWithAction", "sourceStartsWithAction: Boolean = false"):
    assert token in overlay_rendering, token

for token in (
    "startsFreshTopic",
    "const <ChatMessage>[]",
    "ANSWERED CHAT HISTORY 已从写作上下文移除",
):
    assert token in (proactive + proactive_presentation), token

for token in (
    "Build AI Companion v0.41.28+167 APK (Immersive Identity Rendering)",
    "agent/v04128-immersive-identity-rendering",
    "AI-Companion-v0.41.28-167-Immersive-Identity-Rendering-APK",
    "validate_v04128_immersive_identity_rendering.py",
    ".ci/v04128-monitor.txt",
):
    assert token in workflow, token

print("v0.41.28 immersive identity/rendering validation passed")
