#!/usr/bin/env python3
"""Static contracts for v0.41.32 bounded Phase 2B learning/association."""

from pathlib import Path


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
learning_policy = read(
    "app/lib/core/memory/personality_learning_prompt_policy.dart"
)
topic_policy = read("app/lib/core/memory/topic_association_policy.dart")
consolidation = read(
    "app/lib/core/memory/phase2b_consolidation_engine.dart"
)
extractor = read("app/lib/core/ai/memory_extractor.dart")
verifier = read("app/lib/core/desire/conversation_outcome_verifier.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
grounding_guard = read(
    "app/lib/core/grounding/operational_claim_grounding_guard.dart"
)
snapshot = read("app/lib/core/sync/snapshot_service.dart")
test = read("app/test/phase2b_learning_association_test.dart")
ledger = read("AI_Companion_当前总账.md")
workflow = read(".github/workflows/build-apk.yml")

assert "version: 0.41.32+171" in pubspec
assert "static const int schemaVersion = 46;" in database
assert any(
    label in self_reader
    for label in (
        "buildLabel = 'v0.41.32+171'",
        "buildLabel = 'v0.41.33+172'",
    )
)
assert "protocolVersion: 5" in snapshot

for token in (
    "topic_key TEXT NOT NULL DEFAULT ''",
    "activation_count INTEGER NOT NULL DEFAULT 0",
    "associated_selected_count INTEGER NOT NULL DEFAULT 0",
    "_createV46LearningAssociationColumns",
    "version < 46",
    "backfillPhase2BTopicKeys",
):
    assert token in database, token

for token in (
    "directSelected",
    "seedTopics.isEmpty",
    "TopicAssociationPolicy.selectAssociated",
    "associated_selected_count",
):
    assert token in database, token

for token in (
    "PersonalityLearningStatus.established",
    "candidate.contradictionCount == 0",
    "candidate.contextKey == 'ordinary'",
    "selected.take(limit.clamp(0, 2).toInt())",
    "低权重倾向",
    "不得由此伪造用户原话",
):
    assert token in learning_policy, token
assert "recordPersonalityLearningActivation" in prompt
assert "PHASE 2B BOUNDED BIAS" in prompt
assert "不要把用户写成第三人称“她”或“他”" in prompt
assert "phase=phase2b_bounded_bias" in grounding_guard

for token in (
    "Duration(minutes: 90)",
    "now.hour < 7",
    "tryAcquireLocalLease",
    "backfillPhase2BTopicKeys",
):
    assert token in consolidation, token
for forbidden in ("DeepSeekClient", "proposition", "evidence_text"):
    assert forbidden not in consolidation, forbidden

assert "topic_key 是可选的一层关联主题" in extractor
assert "'来找我'" in verifier
assert "'找我聊'" in verifier
assert "造梗|玩梗|造梗/玩梗" in database
assert "AND aliases = ?" in database

for token in (
    "does not expand without a direct topic seed",
    "expands only the same topic and never more than three",
    "blocks forming, contradicted and trial candidates",
    "never selects more than two candidates",
    "local consolidation runs only at night or after 90 minutes idle",
):
    assert token in test, token

for token in (
    "agent/v04132-phase2b-learning-association",
    "Build AI Companion v0.41.32+171 APK",
    "AI-Companion-v0.41.32-171-Phase2B-Learning-Association-APK",
    "validate_v04132_phase2b_learning_association.py",
):
    assert token in workflow, token

assert "v0.41.32 Phase 2B 学习消费与一层关联" in ledger
assert "原始备份、消息正文和脱敏诊断不得提交仓库" in ledger

print("v0.41.32 Phase 2B learning association validation passed")
