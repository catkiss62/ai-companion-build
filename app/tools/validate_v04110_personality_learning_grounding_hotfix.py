#!/usr/bin/env python3
"""Static contracts for v0.41.10 personality-learning grounding hotfix."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
model = read("lib/core/models/personality_learning.dart")
extractor = read("lib/core/ai/memory_extractor.dart")
tests = read("test/personality_learning_phase1_test.dart")
agent_self = read("lib/core/agent/agent_self_reader.dart")
prompt_builder = read("lib/core/ai/prompt_builder.dart")
desire_engine = read("lib/core/desire/desire_engine.dart")
moe_adapter = read("lib/core/integration/moe_expression_prompt_adapter.dart")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
ledger = (REPO / "AI_Companion_当前总账.md").read_text(encoding="utf-8")


assert re.search(r"^version:\s*0\.41\.(?:11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157|19\+158|20\+159|21\+160|22\+161)\s*$", pubspec, re.M)
assert "static const int schemaVersion = 42;" in database
assert any(label in agent_self for label in (
    "buildLabel = 'v0.41.13+152'",
    "buildLabel = 'v0.41.14+153'",
    "buildLabel = 'v0.41.18+157'",
    "buildLabel = 'v0.41.19+158'",
    "buildLabel = 'v0.41.20+159'",
))

for token in (
    "PersonalityLearningRejectionReason",
    "ungroundedTarget('ungrounded_target')",
    "ambiguousReinforcement('ambiguous_reinforcement')",
    "contextOnlyReply('context_only_reply')",
    "parseDetailed",
    "_findGroundedReinforcementTarget",
    "_isGroundedToTarget",
    "_distinctiveBigramOverlap",
    "_isContextOnlyPacingReply",
    "Direct feedback is intentionally allowed",
    "explicitTarget",
):
    assert token in model, token

for token in (
    "当前用户原话本身必须明确谈到或评价该候选",
    "不能因为上一条 AI 顺便扩写了某个偏好就挂到该候选",
    "PersonalityLearningProposal.parseDetailed",
    "personality_learning_rejected_${entry.key.key}_count",
    "contextKey: learningContext.contextKey",
    "learningCandidates.take(16)",
):
    assert token in extractor, token

for token in (
    "where: 'status != ? AND context_key = ?'",
    "if (matching.isNotEmpty) return false",
    "maturity.status == PersonalityLearningStatus.contradicted",
):
    assert token in database, token

for token in (
    "rejectionReasonCounts",
    "personality_learning_rejected_${reason.key}_count",
    "candidateBodiesIncluded': false",
    "evidenceBodiesIncluded': false",
    "modelProposalIncluded': false",
):
    assert token in database, token

for token in (
    "true-device same-direction support rejoins one grounded candidate",
    "true-device pacing reply cannot borrow the AI context target",
    "explicit direct feedback keeps a model-selected target",
    "PersonalityLearningRejectionReason.ungroundedTarget",
    "PersonalityLearningRejectionReason.contextOnlyReply",
    "an explicit first-person pacing preference remains learnable",
    "pacing elsewhere in the turn does not hide a separate preference",
    "an explicit unrelated preference cannot pass without semantic review",
):
    assert token in tests, token

# The hotfix remains observation-only. Learned candidates cannot enter live
# reply generation, Desire selection or Dynamic Moe colouring.
for source, name in (
    (prompt_builder, "chat prompt"),
    (desire_engine, "desire engine"),
    (moe_adapter, "moe adapter"),
):
    assert "personality_learning" not in source, name
    assert "PersonalityLearning" not in source, name

for token in (
    "Build AI Companion v0.41.10+149 APK (Personality Learning Grounding Hotfix)",
    "agent/v04110-personality-learning-grounding-hotfix",
    "AI-Companion-v0.41.10-149-Personality-Learning-Grounding-Hotfix-APK",
    "v0.41.10-personality-learning-grounding-hotfix-test",
    ".ci/v04110-monitor.txt",
    "python3 tools/validate_v04110_personality_learning_grounding_hotfix.py",
):
    assert token in workflow, token

for token in (
    "v0.41.10 人格学习证据归因热修",
    "agent/v04110-personality-learning-grounding-hotfix",
    "0.41.10+149 / schema 42",
    "Phase 2 继续关闭",
    "不合并 `main`、不发布正式 Release",
):
    assert token in ledger, token

print("v0.41.10 personality learning grounding hotfix validation passed")
