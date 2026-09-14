#!/usr/bin/env python3
"""Static contracts for +218 Cedar game-hall protocol integration."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"


require("pubspec.yaml", "version: 0.41.78+222")
require(
    "lib/core/mcp/cedar_game_protocol.dart",
    "class CedarCatalogParser",
    "'rest', 'announcements', 'vote'",
    "class CedarGameAdvicePolicy",
    "isReadOnly",
)
require(
    "lib/core/mcp/mcp_turn_state_resolver.dart",
    "final yourTurn = map['your_turn']",
    "structured_your_turn",
    "'available_actions'",
    "structured_legal_actions",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "adviceNotes",
    "bool get requiresInvitation => this == coPlay || this == multiplayer",
    "supportsSharedParticipation",
    "recordPlatformAction",
    "latest_platform_event",
    "catalogTitle.isNotEmpty",
    "pauseAndRelease",
    "resumeGame",
    "rememberUserAdvice",
    "_repairCatalogTitles",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "CedarPlatformActionPolicy.isPlatformAction(action)",
    "CedarAutonomyProgress('read_only_loop_blocked')",
    "CedarAutonomyProgress('platform_action_loop_blocked')",
    "【近期建议候选】",
    "Room dialogue is a session-local action annotation",
    "apiKey: apiKey",
    "endpoint: endpoint",
)
autonomy = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
assert "readFinalReplyApiKey" not in autonomy
assert "FinalReplyFailurePolicy.maxGeminiAttempts" not in autonomy
assert "final recent = await db.recentMessages(limit: 8)" not in autonomy

require(
    "lib/core/agent/agent_tool_runner.dart",
    "cedarToyManageActivity",
    "_manageCedarActivity",
    "!CedarPlatformActionPolicy.isPlatformAction(action)",
    "recordPlatformAction",
)
require(
    "lib/core/agent/agent_tool_planner.dart",
    "cedar_toy_manage_activity",
    "pause_and_release",
    "allow_self_reset",
)
require(
    "lib/features/chat/cedar_toy_activity_window.dart",
    "游戏活动（",
    "当前活动：",
    "活动中",
    "查看中",
    "恢复这个游戏存档",
)
window = read("lib/features/chat/cedar_toy_activity_window.dart")
assert "_roomProviderNotice" not in window

require(
    "test/cedar_game_hall_protocol_v04174_test.dart",
    "structured_your_turn",
    "strict state machine legal actions",
    "hybrid can start solo",
    "pause_and_release",
    "瓶中生态",
)
matrix = read("docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md")
for game in (
    "mbti", "enneagram", "dnd", "love", "ecr", "humanity",
    "sins_virtues", "bdsmtest", "turtle_soup", "duel", "fishing",
    "bar", "forest", "moonlit", "eco", "ciyuwu", "leek", "delve",
    "travel", "arcade", "burger", "crucible_echoes", "imitator_td",
    "memoria", "white_room", "market", "workkk", "garden_cat",
    "camping_plaza",
):
    assert f"`{game}`" in matrix, game

require(
    ".github/workflows/build-apk.yml",
    "agent/v04178-stop-transfer-interlock",
    "AI-Companion-v0.41.78-222-Stop-Transfer-Interlock-APK",
    "validate_v04174_cedar_game_hall_protocol.py",
)
require(
    "docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md",
    "v0.41.74+218 Cedar 游戏厅全量协议审计与一次性适配",
    "20 个公开小游戏仓库",
)

print("v0.41.74+218 Cedar game-hall protocol validation passed.")
