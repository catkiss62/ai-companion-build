#!/usr/bin/env python3
"""Cross-module gate for +226 Cedar authoritative state-machine closure."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"


require("pubspec.yaml", "version: 0.41.82+226", "sqflite_common_ffi")
require("lib/core/agent/agent_self_reader.dart", "v0.41.82+226")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.82'")
require(
    "lib/core/mcp/cedar_game_protocol.dart",
    "class CedarActionTransportPolicy",
    "class CedarContinuationPriorityPolicy",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "CedarActionTransportPolicy.immediateResponseParams",
    "McpResumeAfterResolver.resolveStructured",
    "requestTimeout: const Duration(seconds: 20)",
    "params: params",
)
require(
    "lib/core/mcp/cedar_toy_client.dart",
    "timeout: const Duration(seconds: 40)",
)
require(
    "lib/core/mcp/cedar_duel_observer_resolver.dart",
    "class CedarDuelObserverResolver",
    "action: 'state'",
    "'wait': true",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "write_reconcile_once",
    "CedarDuelObserverResolver.resolveStructured",
    "renewableServerWait",
    "const <String>{'user', 'shared', 'wait'}.contains(normalizedActor)",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "error is TimeoutException",
    "Duration(seconds: 45)",
    "clamp(1, 20000)",
    "reason: 'night_sleep'",
    "CedarActionTransportPolicy.immediateResponseParams",
    "McpResumeAfterResolver.resolveStructured",
    "Duration(seconds: 15)",
    "action_lease_lost",
)
require(
    "lib/core/desire/proactive_engine.dart",
    "CedarContinuationPriorityPolicy.shouldDefer",
)
assert "immersive_chat_page_visible" not in read(
    "lib/core/desire/proactive_engine.dart"
)[read("lib/core/desire/proactive_engine.dart").index("continueCedarActivityIfDue"):][:700]
require(
    "lib/core/database/app_database.dart",
    "createForTesting",
    "'awaiting_confirmation'",
)
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "lastExecutionErrorCategory",
    "lastContinuationState",
    "autonomyEnabled",
)
require(
    "test/cedar_end_to_end_state_machine_v04182_test.dart",
    "new -> own turn -> move -> wait -> remote move -> own move",
    "a timed-out duel write becomes a read-only reconciliation",
    "Stop terminally cancels an incomplete draft and unblocks backup",
    "authoritative Cedar state must persist without a model wait",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.82+226 Cedar 权威状态机端到端闭环真机验收增量",
    "普通消息、尚未轮到小机",
)
require(
    "../AI_Companion_当前总账.md",
    "v0.41.82+226",
    "agent/v04182-cedar-state-machine-e2e",
    "CI PENDING / TRUE DEVICE PENDING",
)
require(
    "../.github/workflows/build-apk.yml",
    "agent/v04182-cedar-state-machine-e2e",
    "validate_v04182_cedar_state_machine_e2e.py",
    "AI-Companion-v0.41.82-226-Cedar-State-Machine-E2E-APK",
    "v0.41.82-cedar-state-machine-e2e-test",
)

print("v0.41.82+226 Cedar state-machine E2E validation passed.")
