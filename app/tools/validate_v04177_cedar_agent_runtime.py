#!/usr/bin/env python3
"""Static contracts for +221 unified Cedar Agent runtime."""

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


require("pubspec.yaml", "version: 0.41.77+221")
require(
    "lib/core/mcp/cedar_agent_decision.dart",
    "abstract interface class CedarAgentDecisionModel",
    "class DeepSeekCedarAgentDecisionModel",
    "cedar_choose_game",
    "cedar_agent_turn",
    "cedar_classify_outcome",
    "toolChoice: 'required'",
    "incomplete_cedar_native_call",
    "thinking: attempt == 0",
)
require(
    "lib/core/mcp/cedar_game_protocol.dart",
    "class CedarAgentTurnPolicy",
    "continueInCurrentTurn",
    "scheduleBackground",
    "permitsStopBeforePlay",
    "'list_games'",
    "'get_guide'",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "_decisionModel.chooseGame",
    "_decisionModel.decideTurn",
    "_decisionModel.classifyOutcome",
    "semantic_replan_failed",
    "recordAgentDisposition",
    "structured?.nextActor ?? 'companion'",
)
autonomy = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
assert ".jsonCompletion(" not in autonomy, (
    "background Cedar control must not return to fragile JSON-body planning"
)
planned = autonomy[autonomy.index("_advanceSessionPlanned") :]
assert planned.index("_decisionModel.decideTurn") < planned.index(
    "final actionLease = await db.tryAcquireLocalLease",
), "background model planning must finish before the Cedar action lease"

require(
    "lib/core/agent/agent_tool_runner.dart",
    "protocolAction: 'list_games'",
    "protocolAction: 'get_guide'",
    "protocolAction: action",
    "CedarAgentTurnPolicy.continueInCurrentTurn",
    "DeepSeekCedarAgentDecisionModel(client: _ai)",
)
runner = read("lib/core/ai/durable_generation_runner.dart")
assert "cedarTurnHandedOff" not in runner, (
    "one Cedar play call must not be treated as an automatic handoff"
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "CedarToyArcadeSkill.requestsGamePlay(user.content)",
    "shouldReconsiderNoCall",
)
require(
    "test/cedar_agent_runtime_v04177_test.dart",
    "truncated planning stream retries as a native Cedar function call",
    "a second incomplete native call fails instead of becoming wait",
    "foreground keeps discovery and companion turns inside one goal",
    "reading a solo guide cannot be persisted as waiting or complete",
)

compatibility = read("docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md")
game_ids = (
    "mbti enneagram dnd love ecr humanity sins_virtues bdsmtest turtle_soup "
    "duel fishing bar forest moonlit eco ciyuwu leek delve travel arcade burger "
    "crucible_echoes imitator_td memoria white_room market workkk garden_cat "
    "camping_plaza"
).split()
missing_games = [game for game in game_ids if f"`{game}`" not in compatibility]
assert not missing_games, f"compatibility matrix missing {missing_games}"

# The public controller must stay protocol-driven. The only allowed game-id
# appendix is the audited player-parameter signature for a compact guide; it
# contains no strategy and is not part of the Agent state machine.
for path in (
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "lib/core/mcp/cedar_agent_decision.dart",
):
    text = read(path)
    hardcoded = [game for game in game_ids if f"'{game}'" in text]
    assert not hardcoded, f"{path}: game-specific controller branches {hardcoded}"

require(
    ".github/workflows/build-apk.yml",
    "agent/v04177-cedar-agent-runtime",
    "validate_v04177_cedar_agent_runtime.py",
    "AI-Companion-v0.41.77-221-Cedar-Agent-Runtime-APK",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.77+221",
    "Cedar 统一 Agent 游戏运行时",
    "后台模型规划、语义重规划和房间台词生成全部移出 Cedar 动作锁",
    "CI PENDING",
)

print("v0.41.77+221 unified Cedar Agent runtime validation passed.")
