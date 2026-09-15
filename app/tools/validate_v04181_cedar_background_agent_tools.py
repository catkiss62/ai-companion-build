#!/usr/bin/env python3
"""Cross-module contracts for +225 native background Cedar Agent tools.

This source-gate file also keeps branch publication on the full APK workflow;
documentation-only updates must not be mistaken for the functional candidate.
"""

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
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.81'")
require("lib/core/agent/agent_self_reader.dart", "v0.41.81+225")
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "class CedarAgentActionPlanner",
    "AgentToolPlanner.nativeToolDefinitionsFor",
    "cedarStageToolIds: const <String>{'cedar_toy.play'}",
    "toolChoice: 'required'",
    "class CedarAgentActionPlanningException",
    "missing_tool_call",
    "wrong_game",
    "non_executable_action",
    "CedarPlatformActionPolicy.isReadOnly(session.lastAction)",
    "CedarPlatformActionPolicy.isReadOnly(candidate)",
    "_recordAgentActionRetry",
)

engine = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
advance = engine.split("Future<CedarAutonomyProgress> _advanceSessionLocked", 1)[1]
advance = advance.split("Future<({String nextActor", 1)[0]
assert "CedarAgentActionPlanner(" in advance
assert "await _judge(" not in advance
assert "client.play(" in advance

require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "agentActionRetryCount",
    "agentActionRetryLastCategory",
    "agentActionRetryLastAt",
)
require(
    "test/cedar_background_agent_tools_v04181_test.dart",
    "native play call with empty model body",
    "repeated read-only state is rejected then replanned as a move",
    "wrong game id is rejected",
    "two invalid tool decisions stop after the bounded retry",
    "provider object params are accepted defensively",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.81+225 Cedar 后台原生 Agent 工具闭环真机验收增量",
    "agentActionRetryCount",
    "连续完成至少三次网页用户→伴侣换手",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.81+225",
    "agent/v04181-cedar-background-agent-tools",
    "jsonRetryCount=58",
    "CedarAgentActionPlanner",
    "CI PENDING / TRUE DEVICE PENDING",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04181-cedar-background-agent-tools",
    "validate_v04181_cedar_background_agent_tools.py",
    "AI-Companion-v0.41.81-225-Cedar-Background-Agent-Tools-APK",
    "v0.41.81-cedar-background-agent-tools-test",
)

print("v0.41.81+225 Cedar background Agent-tools validation passed.")
