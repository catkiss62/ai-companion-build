#!/usr/bin/env python3
"""Static contracts for v0.41.9 observation-only personality learning."""

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
snapshot = read("lib/core/sync/snapshot_service.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
agent_self = read("lib/core/agent/agent_self_reader.dart")
prompt_builder = read("lib/core/ai/prompt_builder.dart")
desire_engine = read("lib/core/desire/desire_engine.dart")
moe_adapter = read("lib/core/integration/moe_expression_prompt_adapter.dart")
tests = read("test/personality_learning_phase1_test.dart")
phase_doc = read("docs/PERSONALITY_LEARNING_GROWTH_PHASE1.md")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
ledger = (REPO / "AI_Companion_当前总账.md").read_text(encoding="utf-8")

assert re.search(r"^version:\s*0\.41\.(?:9\+148|10\+149|11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157|19\+158|20\+159|21\+160|22\+161|23\+162)\s*$", pubspec, re.M)
assert "static const int schemaVersion = 42;" in database
assert any(label in agent_self for label in (
    "buildLabel = 'v0.41.13+152'",
    "buildLabel = 'v0.41.14+153'",
    "buildLabel = 'v0.41.18+157'",
    "buildLabel = 'v0.41.19+158'",
    "buildLabel = 'v0.41.20+159'",
))
assert "if (oldVersion < 42)" in database
assert "_createV42Tables" in database

for table in (
    "personality_learning_candidates",
    "personality_learning_evidence",
):
    assert f"CREATE TABLE IF NOT EXISTS {table}" in database
    assert table in snapshot
assert "UNIQUE(scope, subject_key, context_key)" in database
assert "UNIQUE(candidate_id, source_message_id)" in database
assert "personality_learning_enabled" in database
assert "personalityTrialAt(DateTime moment)" in database

for token in (
    "user_preference",
    "relationship_permission",
    "trial_preference",
    "explicit_preference",
    "explicit_correction",
    "direct_feedback",
    "boundary",
    "revealed_choice",
    "candidate",
    "forming",
    "established",
    "contradicted",
    "retired",
    "normalizedUser.contains(quote)",
    "A contradiction without a grounded target",
    "supportCount >= 2",
):
    assert token in model, token

for token in (
    "learning_signals",
    "证据只能来自【刚发生的对话】里用户这一条真实原话",
    "用户沉默、没有反对、短回复、回复长度",
    "只允许 scope=trial_preference",
    "只允许 scope=user_preference 或 relationship_permission",
    "personalityLearningCandidatesForExtraction",
    "_applyPersonalityLearningSignals",
    "sourceMessageId: user.id",
    "assistantMessageId: assistant.id",
):
    assert token in extractor, token

# Phase 1 is storage-only. No candidate, evidence or learned proposition may
# enter the live reply prompt, Desire selection or Dynamic Moe colouring.
for source, name in (
    (prompt_builder, "chat prompt"),
    (desire_engine, "desire engine"),
    (moe_adapter, "moe adapter"),
):
    assert "personality_learning" not in source, name
    assert "PersonalityLearning" not in source, name

for token in (
    "schemaVersion >= 42",
    "schema 42 状态包缺少人格学习表",
    "Schema 1-41 never promised",
):
    assert token in snapshot, token

for token in (
    "personalityLearningCandidateBodiesIncluded': false",
    "personalityLearningEvidenceBodiesIncluded': false",
    "personalityLearningSubjectKeysIncluded': false",
    "personalityLearningModelProposalIncluded': false",
    "personalityLearningDiagnosticStats",
    "'personalityLearning': personalityLearning",
):
    assert token in diagnostics, token

for token in (
    "AI-only or paraphrased evidence is rejected",
    "a contradiction cannot invent an ungrounded target",
    "two independent supporting observations can become established",
    "ordinary and trial scopes cannot leak into each other",
    "candidate from another trial context cannot be targeted",
):
    assert token in tests, token

for token in (
    "immutable_core",
    "hard_style_ban",
    "relationship_fact",
    "expression_protocol",
    "trial_script",
    "growth_seed",
    "AI 回复只用于理解",
    "Phase 1 不读取候选来生成普通、主动或沉浸聊天",
):
    assert token in phase_doc, token

for token in (
    "Build AI Companion v0.41.10+149 APK (Personality Learning Grounding Hotfix)",
    "agent/v04110-personality-learning-grounding-hotfix",
    "AI-Companion-v0.41.10-149-Personality-Learning-Grounding-Hotfix-APK",
    "v0.41.10-personality-learning-grounding-hotfix-test",
    ".ci/v04110-monitor.txt",
    "python3 tools/validate_v0419_personality_learning_observation.py",
):
    assert token in workflow, token

for token in (
    "v0.41.9 人格学习观察层 Phase 0+1",
    "agent/v0419-personality-learning-observation",
    "0.41.9+148",
    "只观察、不改表达",
    "不合并 `main`、不发布正式 Release",
):
    assert token in ledger, token

print("v0.41.9 personality learning observation validation passed")
