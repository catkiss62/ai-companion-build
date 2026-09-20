#!/usr/bin/env python3
"""Source gate for v0.41.93 Cedar game-state reality grounding."""

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


require("pubspec.yaml", "version: 0.41.94+238")
require("lib/core/agent/agent_self_reader.dart", "v0.41.94+238")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.93'")
require(
    "lib/core/grounding/operational_claim_grounding_guard.dart",
    "_cedarLiveStateClaim",
    "_cedarHistoricalAnchor",
    "_cedarNonExecutionFraming",
    "ungrounded_cedar_live_state",
    "Fishing `cast` resolves atomically",
)
require(
    "lib/core/ai/prompt_builder.dart",
    "未完成事项、Thought 和旧 ASSISTANT_HISTORY",
    "钓鱼抛竿等 Cedar 动作是一次调用一次结算",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "UserReplyLivenessPolicy.choose",
    "grounded_reply_retry_degraded_pass",
)
require(
    "lib/core/desire/proactive_engine.dart",
    "pendingGameThreadContract",
    "当前没有该游戏的 Cedar Outcome",
    "尚未实际去玩",
    "removeUnsupportedSentences",
    "return blockGrounding(operationGuard.reason)",
)
require(
    "lib/core/desire/proactive_selection_policy.dart",
    "normalizeLegacyGameThreadIntent",
    "isGameTopic",
    "DriveKey.curiosity",
    "check_in",
)
require(
    "lib/core/database/app_database.dart",
    "repairLegacySelfDriveGameThoughtDrives",
    "source = 'self_drive/thread' AND drive_key = 'attachment'",
    "DriveKey.curiosity.name",
)
require(
    "test/game_reality_grounding_v04193_test.dart",
    "fishing ambience cannot masquerade as a running Cedar action",
    "not played, future intent and historical time remain honest",
    "a current successful Cedar outcome grounds current play",
    "a recent stored outcome cannot license a different live scene",
    "pre-upgrade attachment game thought is curiosity at selection",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04193-game-reality-grounding",
    "AI-Companion-v0.41.93-237-Game-Reality-Grounding-APK",
    "v0.41.93-game-reality-grounding-test",
)
require(
    "AI_Companion_当前总账.md",
    "6.10 v0.41.93+237 游戏进行时事实接地",
    "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require(
    "tools/validation_suite.txt",
    "validate_v04193_game_reality_grounding.py",
)

print("v0.41.93 game reality-grounding validation passed")
