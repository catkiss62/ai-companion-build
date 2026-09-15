#!/usr/bin/env python3
"""Cross-module contracts for +224 unified Cedar Agent continuation."""

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
require(
    "lib/core/mcp/cedar_agent_loop_policy.dart",
    "class CedarAgentLoopPolicy",
    "maxPlanningRounds = 10",
    "maxToolCalls = 16",
    "shouldRetryInitialNoCall",
    "shouldFinalizeRound",
    "class CedarServerContinuationPolicy",
    "authorizesExactAction",
    "hasContinuationCall || hasPendingRoomMessage || companionTurn",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "CedarAgentLoopPolicy.shouldRetryInitialNoCall",
    "cedarNoCallRetryUsed = false",
    "CedarAgentLoopPolicy.shouldFinalizeRound",
    "cedarActivityStore.promptContext",
    "cedarRoundRequestsContinuation",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "machineAction: 'list_games'",
    "machineAction: 'get_guide'",
    "serverContinuation",
    "CedarServerContinuationPolicy.authorizesExactAction",
    "markWriteOutcomeUncertain",
    "A stop arriving after the remote write",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "Refreshing a guide is metadata, not a new game transition",
    "existing.copyWith",
    "CedarServerContinuationPolicy.canObserve",
    "CedarServerContinuationPolicy.usesRealtimePace",
    "isUnroutableRemoteWait",
    "parkUnroutableRemoteWait",
    "activeGameId: next.isUnroutableRemoteWait ? '' : gameId",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "CedarToyArcadeSkill.prompt",
    "serverSessionStarted",
    "sharedRuntime",
    "CedarServerContinuationPolicy.authorizesExactAction",
    "Persist its structured result",
    "unroutable_wait_parked",
)
require(
    "lib/core/agent/agent_participation_consent.dart",
    "_explicitSharedGameRequest",
    "陪我",
    "我加入",
)
require(
    "lib/core/mcp/cedar_toy_arcade_skill.dart",
    "requestsNaturalPlay",
    "陪我",
    "下棋",
)
require(
    "test/cedar_agent_loop_v04180_test.dart",
    "one user goal stays open through discovery and room creation",
    "server next_call keeps an established room alive without local labels",
    "remote wait without a continuation route cannot pin the arcade",
    "normal request grants the requested shared-game authority",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.80+224 Cedar Agent 完整续接链真机验收增量",
    "list_games → get_guide",
    "服务端 `next_call`",
    "停止键",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04181-cedar-background-agent-tools",
    "AI-Companion-v0.41.81-225-Cedar-Background-Agent-Tools-APK",
    "validate_v04180_cedar_agent_loop.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.81+225",
    "Cedar Agent 完整续接链",
    "CI PASSED / APK READY / TRUE DEVICE PENDING",
)

print("v0.41.81+225 Cedar Agent-loop validation passed.")
