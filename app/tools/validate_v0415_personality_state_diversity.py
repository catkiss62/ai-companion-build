#!/usr/bin/env python3
"""Static contracts for v0.41.5 personality-state diversity and rhythm repair."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
feed = read("lib/core/desire/thought_feed_policy.dart")
presence = read("lib/core/presence/presence_intelligence.dart")
perception = read("lib/core/perception/perception_engine.dart")
selection = read("lib/core/desire/proactive_selection_policy.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
rhythm = read("lib/core/desire/proactive_rhythm_engine.dart")
reciprocity = read("lib/core/desire/interaction_reciprocity_policy.dart")
emotion_engine = read("lib/core/emotion/emotion_episode_engine.dart")
rest = read("lib/core/emotion/rest_need_policy.dart")
moe = read("lib/core/moe/application/moe_dynamics_policy.dart")
moe_prompt = read("lib/core/integration/moe_expression_prompt_adapter.dart")
prompt_builder = read("lib/core/ai/prompt_builder.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
ledger = (ROOT.parent / "AI_Companion_当前总账.md").read_text(encoding="utf-8")

assert re.search(r"^version:\s*0\.41\.(?:5\+144|6\+145|7\+146|8\+147|9\+148|10\+149|11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157|19\+158|20\+159|21\+160|22\+161)\s*$", pubspec, re.M)
assert "static const int schemaVersion = 40;" in database

for token in (
    "ThoughtProvenance.awareness",
    "incomingStrength.clamp(0.08, 0.34)",
    "fedCount: 1",
    "kind: 'flit'",
    "lifecycleState: 'active'",
):
    assert token in feed, token
assert "drive: DriveKey.curiosity" in presence
assert "legacy.driveKey == DriveKey.attachment.name" in presence
assert "DriveKey.attachment: 0.002 + result.score * 0.004" not in presence
assert "DriveKey.attachment: 0.006" not in perception

for token in (
    "recentSourceTypes",
    "sourceRepetitionPenalty",
    "samplingUnit",
    "top.adjusted.score - value.adjusted.score <= 0.08",
    "samplingCandidateCount",
    "source_repeat_3_plus",
):
    assert token in selection, token
for token in (
    "final selectionSeed =",
    "Random(selectionSeed).nextDouble()",
    "proactive_last_selection_sampling_v1",
    "fatigueProactiveQuietGate",
):
    assert token in proactive, token

assert "_responseQuality(latency);" in rhythm
quality = rhythm.split("double _responseQuality", 1)[1]
assert "textLength" not in quality
assert "user.content.length" not in quality

for token in (
    "Message length is intentionally absent",
    "case 'acknowledged':",
    "activateEpisode: next >= 4",
    "case 'dodged':",
    "activateEpisode: next >= 3",
    "case 'refused':",
):
    assert token in reciprocity, token
for token in (
    "applyInteractionReciprocityOutcomeOnce",
    "emotion:continuous:unmet_bid",
    "structured_conversation_outcome",
    "messageLengthIncluded': false",
):
    assert token in database, token

for token in (
    "fatigueEntry = 0.66",
    "fatigueExit = 0.52",
    "stressEntry = 0.82",
    "stressExit = 0.64",
    "currentlyActive && !recovers",
):
    assert token in rest, token
for token in (
    "emotion:continuous:rest_need",
    "upsertContinuousEmotionEpisode",
    "drive_recovered_below_hysteresis",
    "用户主动说话时仍正常回应",
):
    assert token in emotion_engine, token

for token in (
    "contextReady && grounded >= exitThreshold",
    "MoeStateSnapshot projectForPrompt",
    "final stale = elapsedHours >= 6.0",
    "expressionPlanForTurn",
    "contextTagsForUserText",
    "recentPrimaryRun >= 2 ? 0.30 : 0.58",
    "neutralChance = hasContext ? 0.08 : 0.20",
):
    assert token in moe, token
for token in (
    "moe_expression_selection_state_v2",
    "final afterglowBudget = 1 +",
    "% 3",
    "Random(selectionSeed)",
    "noContextTurns <= afterglowBudget",
    "projectedAgeMinutes",
    "rawTextIncluded': false",
):
    assert token in moe_prompt, token
assert "latestUserText:" in prompt_builder and "turnKey:" in prompt_builder

seed_match = re.search(
    r"const ruleContentV0353_03_personality_seed = r'''(.*?)''';",
    rules,
    re.S,
)
assert seed_match is not None
if "version: 0.41.22+161" in pubspec:
    assert hashlib.sha256(seed_match.group(1).encode("utf-8")).hexdigest() == (
        "6fa9b009375b26461ed9f014d5f8367c30cd7e9543f26bce167b0b35c313eb91"
    )
    assert "legacyEditableRuleLayerSha256V04121AggressiveDialogue" in read(
        "lib/core/rules/rule_layer_defaults.dart"
    )
else:
    assert hashlib.sha256(seed_match.group(1).encode("utf-8")).hexdigest() == (
        "fdad3b2640ddbeb24b9502c25c6707e047a16454f6f9b3b04cfff2caf7a5689b"
    )

for test_file in (
    "test/thought_feed_policy_v0415_test.dart",
    "test/interaction_reciprocity_policy_v0415_test.dart",
    "test/rest_need_policy_v0415_test.dart",
):
    assert (ROOT / test_file).is_file(), test_file

for token in (
    "Build AI Companion v0.41.5+144 APK (Personality State Diversity)",
    "agent/v0415-personality-state-diversity",
    "AI-Companion-v0.41.5-144-Personality-State-Diversity-APK",
    "python3 tools/validate_v0415_personality_state_diversity.py",
    ".ci/v0415-monitor.txt",
):
    assert token in workflow, token

for token in (
    "v0.41.5 性格状态多样性与夜间节律修复",
    "受控随机",
    "规则 01、规则 03",
    "自主截屏仍标记为 `not_implemented`",
):
    assert token in ledger, token

print("v0.41.5 personality state diversity validation passed")
