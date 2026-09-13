#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith(".github/") or path.startswith("AI_") else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"


assert any(
    version in read("pubspec.yaml")
    for version in ("version: 0.41.68+212", "version: 0.41.69+213")
)
assert any(
    version in read("lib/core/agent/agent_self_reader.dart")
    for version in ("v0.41.68+212", "v0.41.69+213")
)
require(
    "lib/core/mcp/mcp_protocol.dart",
    "class McpServerConfig",
    "enum McpContentKind",
    "McpContentKind.image",
    "structuredContent",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "maxGuidePromptChars = 120000",
    "CedarParticipationMode",
    "awaitingInvitation",
    "viewerUrl",
    "完整真实指南",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "wantAction" if False else "CedarToyAutonomyEngine",
    "DeepSeekModelProfile.flash",
    "jsonCompletion",
    "每次只推进一步",
    "mcp/cedar_game:",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "cedar_invitation_required",
    "prepareImageBytes",
    "assistant_mcp_image:cedar:",
    "cedar_guide_too_long",
)
require(
    "lib/core/desire/proactive_engine.dart",
    "wantAction: 'play_game'",
    "game_share:",
    "isImmersiveChatPageVisible",
    "Duration(minutes: 45)",
)
require(
    "lib/features/chat/cedar_toy_activity_window.dart",
    "CedarToyActivityWindow",
    "onPanUpdate",
    "最小化",
    "暂停自主游戏",
    "继续游戏活动",
    "打开游戏返回的查看页",
)
require(
    "lib/features/chat/chat_page.dart",
    "title: '沉浸房间'",
    "title: '游戏厅活动窗'",
    "CedarToyActivityWindow",
)
v2 = read("lib/features/chat/chat_page.dart")
assert v2.index("title: '沉浸房间'") < v2.index("title: '游戏厅活动窗'")
require(
    "lib/core/emotion/emotion_contract.dart",
    "_bareAngleTag",
    "supported.any((label) => label.startsWith(candidatePrefix))",
)
require(
    "lib/features/immersive/immersive_room_page.dart",
    "setImmersiveChatPageVisible(true)",
    "setImmersiveChatPageVisible(false)",
)
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt",
    "immersiveChatPageVisible",
    "setImmersiveChatPageVisible",
)
workflow = read(".github/workflows/build-apk.yml")
assert "validate_v04168_cedar_game_experience.py" in workflow
assert (
    "agent/v04168-cedar-game-experience" in workflow
    or "agent/v04169-cedar-game-switching" in workflow
)
assert (
    "AI-Companion-v0.41.68-212-Cedar-Game-Experience-APK" in workflow
    or "AI-Companion-v0.41.69-213-Cedar-Game-Switching-APK" in workflow
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.68+212",
    "游戏厅活动窗",
    "沉浸房间聊天页面",
)

print("v0.41.68+212 Cedar game experience validation passed.")
