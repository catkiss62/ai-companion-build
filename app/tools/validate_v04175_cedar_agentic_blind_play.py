#!/usr/bin/env python3
"""Static contracts for +219 model-owned Cedar discovery and blind play."""

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


require("pubspec.yaml", "version: 0.41.82+226")
require(
    "lib/core/ai/durable_generation_runner.dart",
    "CedarToyArcadeSkill.gatewayToolIds",
    "CedarToyArcadeSkill.engagedToolIds",
    "cedarLoopEngaged()",
    "cedarBlindPlay()",
    "CedarToyArcadeSkill.maxPlanningRounds",
    "CedarToyArcadeSkill.maxToolCalls",
    "cedarSessionActive: cedarLoopEngaged()",
    "cedarBlindPlay: cedarBlindPlay()",
    "cedarState = await cedarActivityStore.loadState()",
    "cedarCatalog = await cedarActivityStore.loadCatalog()",
    "CedarToyArcadeSkill.prompt",
)
runner = read("lib/core/ai/durable_generation_runner.dart")
for retired in (
    "reasonTag: 'explicit_game_mention'",
    "reasonTag: 'explicit_arcade_catalog'",
    "【明确游戏请求·零调用重试】",
):
    assert retired not in runner, f"retired phrase-driven route remains: {retired}"

require(
    "lib/core/agent/agent_tool_planner.dart",
    "这是常驻的轻量游戏能力入口",
    "不要求用户知道 Cedar、游戏厅、具体仓库名或目录 ID",
    "bool cedarBlindPlay = false",
    "'public_web.search'",
    "CedarToyArcadeSkill.requestsBlindPlay(text)",
)
require(
    "lib/core/agent/agent_task_loop.dart",
    "int planningRoundLimit = maxPlanningRounds",
    "int toolCallLimit = maxToolCalls",
)
require(
    "lib/core/mcp/cedar_toy_arcade_skill.dart",
    "static const maxPlanningRounds = 6",
    "static const maxToolCalls = 10",
    "static const gatewayToolIds",
    "static const engagedToolIds",
    "static bool requestsBlindPlay",
    "static bool requestsExternalGameKnowledge",
    "不授权查看 GitHub/其他源码、后台隐藏状态、题库答案、人类攻略、通关提示或外部网页",
)
require(
    "lib/core/mcp/cedar_toy_client.dart",
    "static String playerSafeGuide",
    "static String playerSafeGuideOutcome",
    "_forbiddenGuideField",
    "_forbiddenGuideHeading",
    "_externalGuidePointer",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "_repairPlayerGuides",
    "CedarToyClient.playerSafeGuide",
    "session.phase == CedarActivityPhase.guideReady",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "final playerGuide = CedarToyClient.playerSafeGuideOutcome(outcome)",
    "CedarPlatformActionPolicy.continuesPlanning(action)",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "CedarToyClient.playerSafeGuideOutcome(guideOutcome)",
)
require(
    "test/cedar_game_hall_protocol_v04174_test.dart",
    "陪我下五子棋",
    "blind play excludes web research",
    "player guide strips repository pointers and spoiler sections",
    "public_web_search",
    "第一关答案",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04182-cedar-state-machine-e2e",
    "AI-Companion-v0.41.82-226-Cedar-State-Machine-E2E-APK",
    "validate_v04175_cedar_agentic_blind_play.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.81+225",
    "模型自主发现",
    "盲玩隔离",
    "总账 v2",
)

print("v0.41.81+225 Cedar agentic blind-play validation passed.")
