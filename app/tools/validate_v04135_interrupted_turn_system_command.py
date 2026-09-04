#!/usr/bin/env python3
"""Static contracts for v0.41.35 interrupted turns and system command."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
model = read("app/lib/core/models/generation_job.dart")
chat = read("app/lib/features/chat/chat_page.dart")
immersive_controller = read(
    "app/lib/core/immersive/immersive_room_controller.dart"
)
immersive_page = read("app/lib/features/immersive/immersive_room_page.dart")
prompt = read("app/lib/core/immersive/immersive_prompt_builder.dart")
snapshot = read("app/lib/core/sync/snapshot_service.dart")
bridge = read("app/lib/core/platform/background_chat_command_server.dart")
overlay = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
planner = read("app/lib/core/agent/agent_tool_planner.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert "version: 0.41.35+174" in pubspec
assert "static const int schemaVersion = 48;" in database
for token in (
    "CREATE TABLE IF NOT EXISTS interrupted_turn_displays",
    "surface TEXT NOT NULL",
    "user_content TEXT NOT NULL",
    "_createV48InterruptedTurnDisplays",
    "interruptImmersiveUserMessageForDisplay",
    "rawTables['interrupted_turn_displays']",
):
    assert token in database, token
for token in (
    "hasDisplayOnlyUserContent",
    "userContent",
    "已停止生成",
):
    assert token in model + chat, token
assert "interrupted_turn_displays" not in prompt
assert "schema 48 状态包缺少中断回合显示表" in snapshot
assert "interruptUserMessageForDisplay" in immersive_controller
cancel_start = immersive_controller.index(
    "} on GenerationCancelledByUserException {"
)
cancel_end = immersive_controller.index("} catch (exception)", cancel_start)
cancel_block = immersive_controller[cancel_start:cancel_end]
assert "_commitVisiblePartial" not in cancel_block
assert "interruptionsForRoom" in immersive_controller
assert "_ImmersiveInterruptedTurn" in immersive_page
assert "'interrupted_user'" in bridge
assert 'message.role == "interrupted_user"' in overlay
assert 'text = "重新编辑"' in overlay

for token in (
    "const systemCommand = '【检查系统】'",
    "text.startsWith(systemCommand)",
    "explicit_system_command",
):
    assert token in planner, token
for token in (
    "本轮真实执行的本地只读接口",
    "没有列出的能力说“本次结果无法确认”",
    "标记 not_implemented 的能力说“尚未实现”",
):
    assert token in self_reader, token

for token in (
    "agent/v04135-interrupted-turn-system-command",
    "Build AI Companion v0.41.35+174 APK",
    "AI-Companion-v0.41.35-174-Interrupted-Turn-System-Command-APK",
    "validate_v04135_interrupted_turn_system_command.py",
):
    assert token in workflow, token
for token in (
    "v0.41.35",
    "中断回合显示层",
    "Token 命中/缓存优化",
):
    assert token in ledger, token

print("v0.41.35 interrupted turn and system command validation passed")
