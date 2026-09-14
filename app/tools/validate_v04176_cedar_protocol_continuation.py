#!/usr/bin/env python3
"""Static contracts for +220 Cedar protocol discovery and continuation recovery."""

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


require("pubspec.yaml", "version: 0.41.76+220")
require(
    "lib/core/mcp/cedar_toy_client.dart",
    "getPlayerPlayProtocol",
    "playerSafePlayProtocol",
    "tool.name != 'play'",
    "input_schema",
    "playerSafeGuide",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "cedar_toy_play_protocol_v2",
    "savePlayProtocol",
    "loadPlayProtocol",
    "Cedar 实时玩家操作 schema",
    "CedarPlayerProtocolContract.actionSignaturesFor",
)
require(
    "lib/core/mcp/cedar_game_protocol.dart",
    "class CedarPlayerProtocolContract",
    "玩家动作参数签名补充 · 不是攻略",
    "game_type 必填",
    "human_first 或 ai_first",
    "不得自行填写或换人",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "cedarNoCallRetryUsed",
    "shouldReconsiderNoCall",
    "noCallReconsiderationInstruction",
    "remainingAfterNoCall",
    "loadPlayProtocol",
    "cedar_toy_no_call_recheck_count",
)
require(
    "lib/core/mcp/cedar_toy_arcade_skill.dart",
    "Cedar 目标完成度复核",
    "当前整轮仍有",
    "并没有用尽",
    "不得用“正在做、马上开、等我”代替真实 Outcome",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "class CedarJsonDecisionRetryPolicy",
    "static const maxAttempts = 2",
    "error is FormatException",
    "FinalReplyFailurePolicy.isTransient(error)",
    "empty_cedar_json_decision",
    "CedarJsonDecisionRetryPolicy.retryDelay",
    "cedar_toy_json_retry_count",
)
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "playerProtocolCached",
    "noCallRecheckCount",
    "jsonRetryCount",
    "jsonRetryLastCategory",
    "roomMessageBodiesIncluded",
)
require(
    "test/cedar_game_hall_protocol_v04174_test.dart",
    "live player protocol keeps action fields but strips source pointers",
    "duel appendix is a parameter signature rather than play strategy",
    "Cedar discovery can reconsider one premature no-call response",
    "background Cedar JSON retry is narrow",
    "DeepSeekException(401",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.76+220 Cedar 玩家协议与后台连续行动真机验收增量",
    "playerProtocolCached=true",
    "jsonRetryCount",
    "noCallRecheckCount",
    "不包含棋谱、落点策略、题目答案或隐藏状态",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04176-cedar-protocol-continuation",
    "AI-Companion-v0.41.76-220-Cedar-Protocol-Continuation-APK",
    "validate_v04176_cedar_protocol_continuation.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.76+220",
    "Cedar 玩家协议与后台连续行动收口",
    "Unexpected end of input",
    "IMPLEMENTED LOCALLY",
)

print("v0.41.76+220 Cedar protocol-continuation validation passed.")
