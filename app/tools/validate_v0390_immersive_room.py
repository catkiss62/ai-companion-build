#!/usr/bin/env python3
"""Static contracts for the first isolated immersive-room implementation."""

from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 34;" in database
for token in (
    "CREATE TABLE IF NOT EXISTS immersive_rooms",
    "CREATE TABLE IF NOT EXISTS immersive_messages",
    "'immersive_rooms'",
    "'immersive_messages'",
):
    assert token in database, token

grouping = read("lib/core/rules/rule_layer_grouping.dart")
assert "'07 · 沉浸房间'" in grouping
assert "'immersive_07_global': '07'" in grouping
assert "'immersive_07_nsfw_source': '07'" in grouping
assert "layer.key.startsWith('07_') ? '03'" in grouping

defaults = read("lib/core/rules/rule_layer_defaults.dart")
assert "'immersive_07_global'" in defaults
assert "'immersive_07_nsfw_source'" in defaults

rule_source = read("lib/core/rules/rule_layer_content_immersive.dart")
start = "const immersiveNsfwSource = r'''"
exact = rule_source.split(start, 1)[1].rsplit("''';", 1)[0]
expected_hash = "88dfc6c0055b0cda50f459706f67bfc2e7c4e59054e337dc98fb9cfd114faffd"
assert sha256(exact.encode("utf-8")).hexdigest() == expected_hash
assert "legacyEditableRuleLayerSha256V0390" in defaults
assert "...legacyEditableRuleLayerSha256V0390.entries" in database
for token in (
    "1200至1600个可见中文字符",
    "硬下限1000",
    "不替他新增台词、重大动作、关键决定",
    "不得把临时姿势、衣物、地点、角色身份或剧情当成现实事实",
):
    assert token in rule_source, token

chat = read("lib/features/chat/chat_page.dart")
phone_at = chat.index("title: const Text('查手机')")
immersive_at = chat.index("title: const Text('沉浸房间')")
divider_at = chat.index("const Divider(height: 24)", phone_at)
assert phone_at < immersive_at < divider_at
assert "ImmersiveRoomLobbyPage" in chat

controller = read("lib/core/immersive/immersive_room_controller.dart")
for token in (
    "client.streamChat(",
    "maxTokens: 6000",
    "ImmersivePromptBuilder.continuationMessages",
    "repository.endRoom(",
    "showStreamingDraft",
    "原始记录仍完整保留",
):
    assert token in controller, token
assert "AndroidBridge" not in controller
assert "streamingContent += delta.content" in controller

page = read("lib/features/immersive/immersive_room_page.dart")
for token in (
    "Color(0xFFF472B6)",
    "NovelTintText",
    "暂时离开",
    "结束房间",
    "只对本房间生效的小说规则",
):
    assert token in page, token
assert "_AssistantSegmentDivider" not in page
assert "AndroidBridge" not in page

prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
assert "history.skip(room.summarizedMessageCount)" in prompt
assert "characterBudget = 22000" in prompt
assert "'02_daily'" not in prompt
assert "'05_intimacy_rendering'" not in prompt
assert "'06_intimacy_reference'" not in prompt
assert "'immersive_07_global'" in prompt

memory_policy = read("lib/core/immersive/immersive_shared_memory_policy.dart")
assert "static List<String> admit" in memory_policy
assert "[沉浸房间经历·虚构]" in memory_policy
assert "_blockedDetails.any(value.contains)" in memory_policy

runner = read("lib/core/ai/durable_generation_runner.dart")
ordinary = read("lib/features/chat/chat_controller.dart")
background = read("lib/core/platform/background_chat_command_server.dart")
assert "emitDeltas: false" in runner
assert "showGenerationDraft" in ordinary
assert "const nextContent = '';" in ordinary
assert "content: ''" in background

print("v0.39.0 immersive room static contracts passed")
