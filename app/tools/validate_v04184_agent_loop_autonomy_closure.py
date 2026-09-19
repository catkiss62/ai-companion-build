#!/usr/bin/env python3
"""Cross-module gate for +228 Agent-loop and autonomy closure."""

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


assert any(
    version in read("pubspec.yaml")
    for version in (
        "version: 0.41.84+228",
        "version: 0.41.85+229",
        "version: 0.41.86+230",
        "version: 0.41.87+231",
    )
)
assert any(
    version in read("lib/core/agent/agent_self_reader.dart")
    for version in (
        "v0.41.84+228",
        "v0.41.85+229",
        "v0.41.86+230",
        "v0.41.87+231",
    )
)
assert any(
    version in read("lib/core/mcp/mcp_http_client.dart")
    for version in (
        "'version': '0.41.84'",
        "'version': '0.41.85'",
        "'version': '0.41.86'",
        "'version': '0.41.87'",
    )
)
require(
    "lib/core/mcp/cedar_agent_loop_policy.dart",
    "maxPlanningRounds = 6",
    "maxToolCalls = 10",
    "committedMutation",
    "awaitingInvitation || waitingUser",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "_optionalContinuationGate",
    "_runCompanionTurnStep",
    "recentActionCount",
    "hydrateTransportParams",
    "missingExplicitRequiredFields",
    "room_state_hydrated",
)
engine = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
assert "Future<CedarAutonomyProgress> _runCompanionTurnLoop" not in engine
step = engine.split("Future<CedarAutonomyProgress> _runCompanionTurnStep", 1)[1]
step = step.split("static String _executionErrorCategory", 1)[0]
assert "for (var round" not in step
assert "_advanceSessionLocked(" in step
require(
    "lib/core/mcp/cedar_game_protocol.dart",
    "class CedarExecutableCallPolicy",
    "class CedarPlayerProtocolContract",
    "uniqueTransportValue",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "pendingTerminalKey",
    "markTerminalDelivered",
    "recent_game_episode",
    "restore_room_state_once",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "usageLane: 'agent_tool_planning'",
    "usageLane: 'final_reply'",
    "markTerminalDelivered",
    "visibleDelta.isNotEmpty",
    "onEmotionCue?.call(visibleEmotionKey)",
)
require(
    "lib/features/chat/chat_controller.dart",
    "startEmotionCue(projectedAssistant.emotionKey)",
)
require(
    "lib/core/agent/agent_tool_registry.dart",
    "public_web.discover_autonomous",
    "autonomousAvailable: true",
)
require(
    "lib/core/autonomy/layered_public_web_provider.dart",
    "cancelWithToken",
    "_client.close()",
)
require("lib/core/ai/generation_cancellation.dart", "Future.any<T>")
candidate_model = read("lib/core/models/public_web_candidate.dart")
draft_constructor = candidate_model.split("class PublicWebCandidateDraft", 1)[1]
draft_constructor = draft_constructor.split("final String fingerprint;", 1)[0]
assert draft_constructor.count("this.keyPoints = const <String>[]") == 1
assert draft_constructor.count("this.uncertainties = const <String>[]") == 1
assert draft_constructor.count("this.readAt,") == 1
require(
    "lib/core/mcp/cedar_agent_loop_policy.dart",
    "import 'cedar_game_protocol.dart';",
)
require(
    "lib/core/phone/companion_album_discovery_engine.dart",
    "companion_album_fisharchive_attempt_count",
    "raw['original']",
)
require(
    "lib/core/desire/proactive_scene_continuity_policy.dart",
    "Duration(minutes: 10)",
    "recent_active_conversation",
)
require(
    "lib/core/perception/perception_interpreter.dart",
    "_ScreenSessionWindow",
    "熄屏不能算作继续使用",
)
require(
    "lib/core/diagnostics/model_usage_telemetry.dart",
    "input_tokens",
    "cache_hit_tokens",
    "cache_miss_tokens",
)
require(
    "lib/core/reference/world_book_presets.dart",
    "去工具化与自主性",
    "极端阈值层",
)
require(
    "test/world_book_model_test.dart",
    "核心架构：底色与分层机制",
    "去工具化与自主性",
)
require(
    "lib/core/database/app_database.dart",
    "_migrateUntouchedPersonalitySpectrum",
    "e7035045f0853b5e15eb610ed02441d86519e866443870e4b08a394319907dd2",
)
require(
    "lib/core/rules/rule_layer_content_v04155_user_defaults.dart",
    "每一段动作、神态之后都需要配一段对话。",
)
require(
    "lib/core/rules/rule_layer_defaults.dart",
    "legacyEditableRuleLayerSha256V04183ActionDialogue",
    "547afce48773ffe8c159befeb8ecad17ecc4840d29fa25ddc482f9438ffc6d8c",
)
require(
    "test/layered_public_web_provider_v0349_test.dart",
    "Stop cancels an in-flight public-web request immediately",
)
require(
    "test/cedar_end_to_end_state_machine_v04182_test.dart",
    "terminal outcome remains pending until the visible reply commits",
    "a restored unique room list hydrates before claiming user turn",
)
assert any(
    version in read("test/agent_self_reader_v0416_test.dart")
    for version in (
        "build=v0.41.84+228 schema=61",
        "build=v0.41.85+229 schema=61",
        "build=v0.41.86+230 schema=61",
        "build=v0.41.87+231 schema=61",
    )
)
require(
    "test/cedar_background_agent_tools_v04181_test.dart",
    "explicit guide-required fields block an incomplete mutation",
    "contains('game_type')",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.84+228",
    "agent/v04184-agent-loop-autonomy-closure",
    "IMPLEMENTED LOCALLY",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04184-agent-loop-autonomy-closure",
    "validate_v04184_agent_loop_autonomy_closure.py",
    "AI-Companion-v0.41.84-228-Agent-Loop-Autonomy-Closure-APK",
    "v0.41.84-agent-loop-autonomy-closure-test",
)

print("v0.41.84+228 Agent-loop autonomy closure validation passed.")
