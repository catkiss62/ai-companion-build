#!/usr/bin/env python3
"""Static contracts for v0.41.19 Phase 2A runtime stabilization."""

from pathlib import Path
import re


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
self_drive = read("app/lib/core/desire/self_drive_engine.dart")
proactive = read("app/lib/core/desire/proactive_engine.dart")
frequency = read("app/lib/core/models/proactive_frequency.dart")
feedback = read("app/lib/core/models/proactive_topic_feedback_policy.dart")
learning = read("app/lib/core/models/personality_learning.dart")
extractor = read("app/lib/core/ai/memory_extractor.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
daily_rule = read("app/lib/core/rules/rule_layer_content_v0353.dart")
truth_guard = read("app/lib/core/grounding/operational_claim_grounding_guard.dart")
snapshot = read("app/lib/core/sync/snapshot_service.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert re.search(r"^version:\s*0\.41\.(?:19\+158|20\+159|21\+160|22\+161)\s*$", pubspec, re.MULTILINE)
assert "static const int schemaVersion = 44;" in database
for token in (
    "_createV44Tables",
    "idx_self_review_active_source",
    "personality_learning_evidence_revisions",
    "_stabilizeV44Data",
    "_normalizeV44SelfReviewImport",
    "activeSourceDuplicateCount",
    "evidenceRevisionCount",
):
    assert token in database, token
assert "personality_learning_evidence_revisions" in snapshot

for token in (
    "SelfReviewSourceFingerprint.thread",
    "thread.updatedAt.millisecondsSinceEpoch",
    "memory.updatedAt.millisecondsSinceEpoch",
):
    if token.startswith("SelfReview"):
        assert token in self_drive, token
    else:
        assert token not in self_drive, token
for token in (
    "minimumGap",
    "Duration(minutes: 30)",
    "Duration(minutes: 15)",
    "Duration(minutes: 8)",
):
    assert token in frequency, token
for token in (
    "lastSentProactiveAt",
    "decision: 'minimum_gap'",
    "不得把 2 分钟说成睡醒",
):
    assert token in database + proactive, token

for token in (
    "ProactiveTopicFeedbackPolicy.isRepetitionComplaint",
    "outcome: 'dismissed'",
    "topicFit: -0.95",
):
    assert token in extractor, token
assert extractor.index(
    "ProactiveTopicFeedbackPolicy.isRepetitionComplaint(userText)"
) < extractor.index("if (raw is! Map) return null;")
assert "翻来覆去" in feedback

for token in (
    "PersonalityLearningAtomicityPolicy",
    "PersonalityLearningEvidenceRepairPolicy",
    "user.preference.communication.colloquial_concise",
    "relationship.permission.initiative.self_directed",
):
    assert token in learning + database, token
assert "同一原子偏好或许可" in extractor

if "version: 0.41.22+161" in pubspec:
    for token in (
        "普通聊天最终正文只写真正说出口的话",
        "普通聊天正文禁止动作、神态、语气说明",
        "一至三个口语句",
        "DialogueExpressionPlan.select",
    ):
        assert token in prompt + daily_rule, token
else:
    for token in (
        "普通短回合允许零动作",
        "需要非语言承载",
        "一至三个口语短句",
        "【近期动作词根降重】",
    ):
        assert token in prompt + daily_rule, token
for retired in (
    "每轮正文至少有一行重要动作、神态、语气或微表情",
    "顿了顿，又小小声补了一句。",
):
    assert retired not in prompt, retired
assert "每轮对话至少要出现一次" not in daily_rule

for token in (
    "_publicWebJourney",
    "ungrounded_public_web_journey",
    "publicWebOutcomeAvailable",
):
    assert token in truth_guard + proactive, token

for token in (
    "Build AI Companion v0.41.19+158 APK (Phase 2A Stabilization)",
    "agent/v04119-phase2a-runtime-stabilization",
    "AI-Companion-v0.41.19-158-Phase2A-Runtime-Stabilization-APK",
    "validate_v04119_phase2a_runtime_stabilization.py",
):
    assert token in workflow, token
for token in (
    "### 27. 2026-09-02 · v0.41.19 Phase 2A 运行稳定化",
    "0.41.19+158 / schema 44 / snapshot protocol 5",
    "动作与神态不是随机可选装饰",
):
    assert token in ledger, token

print("v0.41.19 Phase 2A runtime stabilization validation passed")
