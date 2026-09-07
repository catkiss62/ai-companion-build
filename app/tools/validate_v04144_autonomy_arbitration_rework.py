#!/usr/bin/env python3
"""Structural regression contracts for v0.41.44 autonomy arbitration."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
engine = read("lib/core/desire/proactive_engine.dart")
selection = read("lib/core/desire/proactive_selection_policy.dart")
discovery = read("lib/core/autonomy/public_web_discovery_engine.dart")
policy = read("lib/core/autonomy/public_web_discovery_policy.dart")
tests = read("test/proactive_phase3b_behavior_policy_v04143_test.dart")
web_tests = read("test/public_web_discovery_policy_v0348_test.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.41\.44\+183$", pubspec, re.M)
assert "static const int schemaVersion = 55;" in database
assert "agent/v04144-autonomy-arbitration-rework" in workflow
assert "Build AI Companion v0.41.44+183 APK" in workflow
assert "AI-Companion-v0.41.44-183-Autonomy-Arbitration-Rework-APK" in workflow

assert "final heartbeatKey =" in engine
assert "behaviorKind: 'wait'" in engine
assert "reasonTag: 'no_intent'" in engine
assert "reasonTag: 'below_action_threshold'" in engine
assert "reasonTag: 'scene_rest_hold'" in engine
assert "'behaviorKind': selection.behaviorKind" in engine
assert "'wait'," in database

fatigue_block = engine.split(
    "fatigue >= DesireCorePolicy.fatigueProactiveQuietGate", 1
)[1].split("final recentScene", 1)[0]
assert "return const ProactiveDecision" not in fatigue_block
assert "behaviorKind == 'wait'" in engine
assert "intent.wantAction == 'rest'" in engine

assert "class PublicWebDiscoveryAvailability" in discovery
assert "Future<PublicWebDiscoveryAvailability> availability" in discovery
assert "capability.available ? 'discover_interest' : 'wait'" in engine
assert "capability/public_web:" in engine
assert "final discoveryScore = (discoverySource.score - 0.03)" in engine
assert "sourceIntent: routedDiscoveryIntent" in engine
assert "sourceIntentOverride: discoveryIntent" in engine
assert "selection?.selectedOriginalScore ?? intent.score" in engine
assert "budgetLimitFor" in policy

assert "previousStatus != 'completed'" in selection
assert "previousBehavior == 'rest'" in selection
assert "previousBehavior == 'wait'" in selection
assert "_sharesTopicCooldown(previousBehavior, behaviorKind)" in selection
assert "previous == 'public_web_discovery'" in selection
assert "reasonTag == 'delivery_gate'" in engine
assert "? 'wait'" in engine

assert "selectedOriginalScore" in selection
assert "final deliveryIntentScore = max(" in engine
assert "'deliveryIntent':" in engine
assert "status = 'completed' AND behavior_kind IN" in database
assert "'proactive_message','public_web_discovery','public_web_share'" in database

for phrase in (
    "blocked message does not pretend the topic was handled",
    "completed rest does not suppress a later drive message",
    "visible delivery does not hard-block quiet discovery of same topic",
    "delivery keeps original motive strength after selection downrank",
    "wait is a first-class non-action candidate",
    "rest remains a real winner inside shared competition",
):
    assert phrase in tests
assert "adaptive budget depends on original motive and verified value" in web_tests

print("v0.41.44 autonomy arbitration rework validation passed")
