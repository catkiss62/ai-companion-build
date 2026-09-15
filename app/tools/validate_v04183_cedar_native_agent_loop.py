#!/usr/bin/env python3
"""Cross-module gate for +227 Cedar native autonomous Agent closure."""

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


require("pubspec.yaml", "version: 0.41.83+227", "sqflite_common_ffi")
require("lib/core/agent/agent_self_reader.dart", "v0.41.83+227")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.83'")
require(
    "lib/core/agent/agent_native_tool_accumulator.dart",
    "class AgentNativeToolCallAccumulator",
    "void addAll(Iterable<DeepSeekToolCallDelta> fragments)",
    "List<DeepSeekToolCall> build({int limit = 2})",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "AgentNativeToolCallAccumulator()",
    "toolCallAccumulator.addAll(delta.toolCallDeltas)",
)
require(
    "lib/core/agent/agent_tool_planner.dart",
    "AgentToolOrigin origin = AgentToolOrigin.userTurn",
    "definition.autonomousAvailable",
    "'autonomous_agent'",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "AgentToolOrigin origin = AgentToolOrigin.userTurn",
    "definition.autonomousAvailable",
    "origin: origin.key",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "toolChoice: 'auto'",
    "origin: AgentToolOrigin.autonomous",
    "_runCompanionTurnLoop",
    "observed.state != 'remote_event_companion_turn'",
    "provider_http_${error.statusCode}",
    "cedar_toy_last_execution_error_detail",
)

engine = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
continue_due = engine.split(
    "Future<CedarAutonomyProgress> continueDue", 1
)[1].split("Future<CedarAutonomyProgress> progress", 1)[0]
assert "_continuationGate(" not in continue_due
assert "night_rest_deferred" not in continue_due

require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "lastExecutionErrorDetail",
    "cedar_toy_last_execution_error_detail",
)
require(
    "test/cedar_background_agent_tools_v04181_test.dart",
    "requestBody?['tool_choice'], 'auto'",
    "autonomous native parsing grants only registry-approved tools",
    "autonomous runner blocks capabilities not granted by the registry",
)
require(
    "test/cedar_end_to_end_state_machine_v04182_test.dart",
    "DateTime(2026, 9, 15, 2, 1)",
    "provider HTTP failure remains visible instead of becoming other",
    "provider_http_400",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.83+227 Cedar 原生 Agent 续接闭环真机验收增量",
    "同一个后台 execution 必须立即规划并落子",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.83+227",
    "agent/v04183-cedar-native-agent-loop",
    "CI PENDING / TRUE DEVICE PENDING",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04183-cedar-native-agent-loop",
    "validate_v04183_cedar_native_agent_loop.py",
    "AI-Companion-v0.41.83-227-Cedar-Native-Agent-Loop-APK",
    "v0.41.83-cedar-native-agent-loop-test",
)

print("v0.41.83+227 Cedar native Agent-loop validation passed.")
