#!/usr/bin/env python3
"""Source gate for v0.41.91 bounded fatigue-affect coupling and sleep debt."""

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


require("pubspec.yaml", "version: 0.41.91+235")
require("lib/core/agent/agent_self_reader.dart", "v0.41.91+235")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.91'")
require(
    "lib/core/desire/fatigue_affect_policy.dart",
    "class FatigueAffectSnapshot",
    "class FatigueAffectPolicy",
    "positiveActivation",
    "negativeRestlessness",
    "maxSleepDebt = 0.18",
    "quietBeforeRepayment = Duration(minutes: 90)",
    "repaySleepDebt",
)
require(
    "lib/core/desire/fatigue_affect_controller.dart",
    "fatigue_sleep_debt_v1",
    "recentMessageHeaders(limit: 1)",
    "recordAutonomousExertion",
    "setSettingsAtomically",
)
require(
    "lib/core/desire/desire_core_policy.dart",
    "fatigueRestEligible",
    "fatigueRestReason",
    "affect.restScoreAdjustment",
    "affect.actionPenaltyAdjustment",
    "身体已经累了，心里却还没有安静下来",
)
require(
    "lib/core/desire/proactive_engine.dart",
    "fatigueAffect: fatigueAffect",
    "source: isCedarGameShare ? 'cedar_game_share' : 'proactive_message'",
)
require(
    "lib/core/autonomy/public_web_discovery_engine.dart",
    "FatigueAffectController(db).snapshot",
    "fatigueAffect: fatigueAffect",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "FatigueAffectSnapshot fatigueAffect",
    "activityActivation",
    "source: 'cedar_game_step'",
    "!CedarPlatformActionPolicy.isReadOnly(action)",
    "reason: 'night_sleep'",
)
require(
    "lib/core/emotion/emotion_episode_engine.dart",
    "又累又睡不着",
    "不要把烦躁写成精力恢复",
    "用户主动说话时仍正常回应",
)
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "circadian_affect_debt_v04191",
    "positiveActivation",
    "negativeRestlessness",
    "sleepDebt",
    "lastExertionSource",
)
require(
    "test/fatigue_affect_debt_v04191_test.dart",
    "positive connection briefly offsets rest without erasing body fatigue",
    "negative emotion means tired but restless, never extra outward energy",
    "sleep debt outweighs excitement after repeated late effort",
    "debt repayment starts only after ninety minutes of real quiet",
    "Cedar uses the same debt pressure and keeps unattended night veto",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04191-fatigue-affect-debt",
    "AI-Companion-v0.41.91-235-Fatigue-Affect-Sleep-Debt-APK",
    "v0.41.91-fatigue-affect-sleep-debt-test",
)
require(
    "AI_Companion_当前总账.md",
    "6.8 v0.41.91+235 疲劳—心境小幅耦合与睡眠债",
    "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require(
    "tools/validation_suite.txt",
    "validate_v04191_fatigue_affect_debt.py",
)

print("v0.41.91 fatigue-affect and sleep-debt validation passed")
