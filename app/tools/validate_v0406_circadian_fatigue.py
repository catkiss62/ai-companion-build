#!/usr/bin/env python3
"""Static contracts for v0.40.6 circadian fatigue and Desire competition."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
policy = read("lib/core/desire/desire_core_policy.dart")
engine = read("lib/core/desire/desire_engine.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
database = read("lib/core/database/app_database.dart")
tests = read("test/desire_core_policy_v031_test.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.40\.6\+135\s*$", pubspec, re.M)
assert "static const int schemaVersion = 40;" in database

for token in (
    "circadianFatigueFloor(DateTime now)",
    "fatigueCompetitionFloor = 0.48",
    "fatigueRestScore(fatigue)",
    "rawScore - fatigueActionPenalty(fatigue)",
    "outboundFatigueCost(double fatigue)",
    "outboundEffort && action != 'rest'",
):
    assert token in policy, token

assert "if (fatigue >= fatigueRestGate)" not in policy
assert "return [" not in policy.split("static List<DesireCoreCandidate> candidates", 1)[1].split(
    "static Map<DriveKey, double> satisfiedDrives", 1
)[0]
assert "bool outboundEffort = false" in engine
assert "outboundEffort: true" in proactive
assert "circadian_fatigue_override_count" in proactive

for token in (
    "'fatiguePolicyMode': 'circadian_competition_v0406'",
    "'circadianFatigue': {",
    "'floorAppliedToCurrent':",
    "'strongDesireOverrideActive': strongDesireOverrideActive",
    "'hardVetoEnabled': false",
    "'outboundFatigueCostEnabled': true",
    "'thoughtOrMessageTextIncluded': false",
    "'userScheduleTextIncluded': false",
):
    assert token in diagnostics, token

for token in (
    "creates real late-night sleepiness",
    "exceptional attachment can override",
    "morning passage recovers fatigue",
    "only high-fatigue outbound effort adds a bounded body cost",
):
    assert token in tests, token

for token in (
    "Build AI Companion v0.40.6+135 APK (Circadian Fatigue Competition)",
    "agent/v0406-circadian-fatigue",
    "AI-Companion-v0.40.6-135-Circadian-Fatigue-APK",
    "python3 tools/validate_v0406_circadian_fatigue.py",
):
    assert token in workflow, token

print("v0.40.6 circadian fatigue validation passed")
