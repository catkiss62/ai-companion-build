#!/usr/bin/env python3
"""Static contracts for +221 Cedar background room-turn recovery."""

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


require("pubspec.yaml", "version: 0.41.81+225")
require(
    "lib/core/ai/deepseek_client.dart",
    "class EmptyJsonCompletionException",
    "class MalformedJsonCompletionException",
    "content.trim().isEmpty",
    "empty_json_completion_content",
    "malformed_json_completion_content",
)
require(
    "lib/core/diagnostics/runtime_error_category.dart",
    "empty_model_content",
    "malformed_model_json",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "class CedarJsonDecisionExecutor",
    "thinkingForAttempt",
    "attempt <= 1 ? 2400 : 1400",
    "static String errorCategory",
    "上一次没有产生可解析正文",
    "class CedarRoomActionPayload",
    "params = CedarRoomActionPayload.withMessage",
)
require(
    "lib/core/maintenance/recovery_orchestrator.dart",
    "await db.setSetting('cedar_toy_last_continuation_error', '')",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "machineAction: action",
    "final promptAction",
    "真实 $promptAction Outcome",
)
require(
    "test/cedar_game_hall_protocol_v04174_test.dart",
    "empty thinking body retries with a different JSON strategy",
    "stable Cedar JSON authorization error is not retried",
    "web room handoff stays actionable and submits reply with move",
    "EmptyJsonCompletionException",
    "reasoning_content",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.77+221 Cedar 后台换手闭环真机验收增量",
    "连续完成至少三次双方换手",
    "empty_model_content",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04181-cedar-background-agent-tools",
    "AI-Companion-v0.41.81-225-Cedar-Background-Agent-Tools-APK",
    "validate_v04177_cedar_background_turn_loop.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.81+225",
    "Cedar 后台换手闭环",
    "根因已由同一时刻备份、诊断与源码三方证明",
    "Unexpected end of input",
)

print("v0.41.81+225 Cedar background turn-loop validation passed.")
