#!/usr/bin/env python3
"""Source gate for v0.41.92 causal desire ledger and game interest."""

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
    "lib/core/desire/game_engagement_policy.dart",
    "enum GameEngagementPhase",
    "spark, flow, saturated, cooling, available",
    "negativeRestlessness",
    "Duration(hours: 8)",
)
require(
    "lib/core/desire/desire_satisfaction_ledger.dart",
    "desire_satisfaction_ledger_v1",
    "class DesireSatisfactionLedger",
    "game_share",
    "thoughtBodiesIncluded",
)
require(
    "lib/core/desire/proactive_selection_policy.dart",
    "canonicalTopic",
    "game_share",
    "opportunityBoost",
    "Duration(minutes: 90)",
)
require(
    "lib/core/desire/self_drive_engine.dart",
    "class SelfReviewDrivePolicy",
    "if (gameTopic) return DriveKey.curiosity",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "class CedarResumeEligibilityPolicy",
    "canEnterCompetition",
    "GameEngagementPolicy.evaluate",
    "engagementPhase",
    "DesireSatisfactionLedgerController(db).record",
)
require(
    "lib/core/database/app_database.dart",
    "'game_share'",
    "nonproductiveWinnerCount",
    "dominanceAlerts",
)
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "satisfactionLedger.diagnostic(now)",
)
require(
    "test/desire_game_interest_v04192_test.dart",
    "game engagement flows, saturates, cools and becomes available again",
    "negative affect can interrupt otherwise active game momentum",
    "not-due checkpoint never enters proactive competition",
    "ordinary game threads use curiosity instead of attachment",
    "Cedar and shared activity use one semantic game domain",
    "game sharing is a separate behavior lane from playing",
    "causal satisfaction ledger round-trips and keeps source metadata",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04192-desire-game-interest",
    "AI-Companion-v0.41.92-236-Desire-Game-Interest-APK",
    "v0.41.92-desire-game-interest-test",
)
require(
    "AI_Companion_当前总账.md",
    "6.9 v0.41.92+236 欲望因果账本与动态游戏投入",
    "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require(
    "tools/validation_suite.txt",
    "validate_v04192_desire_game_interest.py",
)

print("v0.41.92 desire ledger and dynamic game-interest validation passed")
