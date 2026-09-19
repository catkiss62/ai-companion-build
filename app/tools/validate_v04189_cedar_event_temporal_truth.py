#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, needles: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise SystemExit(f"{path}: missing {missing}")


require(
    "lib/core/desire/cedar_game_thought_policy.dart",
    [
        "recentClaimWindow = Duration(hours: 1)",
        "proactiveShareMaxAge = Duration(hours: 48)",
        "thought.actionCount > 0 || thought.lastActedAt != null",
        "first.source == second.source",
        "return thought.bornAt",
    ],
)
require(
    "lib/core/desire/thought_consolidation_engine.dart",
    ["CedarGameThoughtPolicy.canConsolidateByTopic(a, b)"],
)
require(
    "lib/core/desire/proactive_thought_readiness_policy.dart",
    ["CedarGameThoughtPolicy.canInitiateShare(thought, now)"],
)
require(
    "lib/core/desire/proactive_engine.dart",
    [
        "CedarGameThoughtPolicy.evidenceAt(intentThought!)",
        "'cedar_event_age_minutes': cedarOutcomeAgeMinutes!",
        "'cedar_event_is_recent': cedarOutcomeIsRecent",
        "cedarOutcomeAt: cedarOutcomeAt",
        "stale_cedar_event_presented_as_recent",
    ],
)
require(
    "lib/core/grounding/operational_claim_grounding_guard.dart",
    [
        "DateTime? cedarOutcomeAt",
        "_cedarImmediateTimeAnchor",
        "stale_cedar_event_presented_as_recent",
        "(钓了|甩了|抛了)",
        "const Duration(hours: 1)",
    ],
)
require(
    "test/cedar_game_thought_temporal_v04189_test.dart",
    [
        "different Cedar Outcomes never consolidate",
        "at most one proactive share",
        "cannot initiate a share",
    ],
)
require(
    "test/operational_claim_grounding_guard_test.dart",
    [
        "old Cedar outcome cannot be presented as just completed",
        "old Cedar outcome remains shareable with an honest history anchor",
        "fresh Cedar fishing action is authorized",
    ],
)

print("v0.41.89 Cedar event temporal truth validation passed")
