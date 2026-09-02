#!/usr/bin/env python3
"""Static contracts for v0.41.13 Phase 0+1 and time audit hardening."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


pubspec = read(APP / "pubspec.yaml")
database = read(APP / "lib/core/database/app_database.dart")
learning = read(APP / "lib/core/models/personality_learning.dart")
extractor = read(APP / "lib/core/ai/memory_extractor.dart")
memory = read(APP / "lib/core/memory/memory_brain.dart")
relationship = read(APP / "lib/core/relationship/relationship_brain.dart")
snapshot = read(APP / "lib/core/grounding/grounding_snapshot.dart")
grounding_engine = read(APP / "lib/core/grounding/grounding_engine.dart")
prompt = read(APP / "lib/core/ai/prompt_builder.dart")
durable = read(APP / "lib/core/ai/durable_generation_runner.dart")
proactive = read(APP / "lib/core/desire/proactive_engine.dart")
perspective = read(APP / "lib/core/grounding/user_perspective_guard.dart")
agent_self = read(APP / "lib/core/agent/agent_self_reader.dart")
learning_tests = read(APP / "test/personality_learning_phase1_test.dart")
grounding_tests = read(APP / "test/grounding_snapshot_test.dart")
perspective_tests = read(APP / "test/user_perspective_guard_test.dart")
docs = read(APP / "docs/PHASE01_TIME_AUDIT_HARDENING_v0.41.13.md")
doc_map = read(APP / "docs/DOCUMENTATION_MAP.md")
ledger = read(ROOT / "AI_Companion_当前总账.md")
workflow = read(ROOT / ".github/workflows/build-apk.yml")

assert any(version in pubspec for version in (
    "version: 0.41.13+152",
    "version: 0.41.14+153",
    "version: 0.41.18+157",
    "version: 0.41.19+158",
    "version: 0.41.20+159",
))
assert "static const int schemaVersion = 42;" in database
assert any(label in agent_self for label in (
    "buildLabel = 'v0.41.13+152'",
    "buildLabel = 'v0.41.14+153'",
    "buildLabel = 'v0.41.18+157'",
    "buildLabel = 'v0.41.19+158'",
    "buildLabel = 'v0.41.20+159'",
))
assert "implemented_observation_only" in agent_self

for token in (
    "unverifiedDirectFeedback('unverified_direct_feedback')",
    "overbroadProposition('overbroad_proposition')",
    "protectedContract('protected_contract')",
    "assistant_expression_quote",
    "previousAssistantText",
    "_isGroundedNewProposition",
    "_relationshipPermissionDomains",
    "isAllowedBehavioralSubject",
    "isCapabilityImplementationClaim",
    "genericCharacters[index] || genericCharacters[index + 1]",
):
    assert token in learning, token

for token in (
    "已作为 learning_signals 返回的互动表达偏好/关系许可",
    "PersonalityLearningBoundaryPolicy.isBehavioralMemorySubject",
    "PersonalityLearningBoundaryPolicy.looksLikeBehavioralPreference",
    "PersonalityLearningBoundaryPolicy.isCapabilityImplementationClaim",
    "previousAssistantText: previousAssistant?.content ?? ''",
):
    assert token in extractor, token
for token in (
    "isBehavioralMemorySubject",
    "looksLikeBehavioralPreference",
    "isCapabilityImplementationClaim",
):
    assert token in memory, token
for token in (
    "looksLikeBehavioralPreference",
    "isCapabilityImplementationClaim",
):
    assert token in relationship, token

for token in (
    "transientSceneRecheckMinutes = 30",
    "previousRealUserAt",
    "currentTurnInteractionGapMinutes",
    "userSceneAnchorAt",
    "hasProactiveBoundaryAfterSceneAnchor",
    "proactiveBoundaryInjectedUserMessageId",
    "timeBoundaryPromptMode",
    "'carry_forward'",
    "AI 自己的主动消息刷新用户现实现场",
    "活动类型",
    "明确持续时间",
):
    assert token in snapshot, token
assert "proactive_time_boundary_anchor_message_id" in grounding_engine
for token in (
    "普通聊天时间边界 · 本场景首次详细注入",
    "普通聊天时间边界 · 精简延续",
    "上一条真实用户消息时间",
    "当前 AI 主动触发时间",
    "OBSERVATION ONLY",
    "Phase 2/3 尚未开启",
    "proactive_time_boundary_anchor_message_id",
):
    assert token in prompt, token

for source in (durable, proactive):
    assert "UserPerspectiveGuard.evaluate" in source
    assert "不得把当前用户写成“他”" in source
assert "current_user_narrated_as_third_person" in perspective
assert "_thirdPartyContext.hasMatch(currentUserText)" in perspective

for token in (
    "ordinary content preferences stay outside personality learning",
    "a legacy content-preference candidate cannot be reinforced",
    "direct feedback requires a verbatim previous assistant expression",
    "direct feedback is rejected when the quoted expression matches two targets",
    "new proposition cannot add an absolute rule absent from user evidence",
    "Phase 1 boundary identifies legacy prompt bypass records",
):
    assert token in learning_tests, token
for token in (
    "30-minute user-scene boundary triggers one detailed injection",
    "a proactive generation uses the last real user as scene clock",
    "a proactive message never refreshes the user scene clock",
    "later proactive calls carry a compact boundary without timestamps",
    "a prior proactive prompt injection is compact even when it sent WAIT",
    "a new real user turn still receives detail after proactive WAIT",
):
    assert token in grounding_tests, token
assert "turns the current user into him" in perspective_tests
assert "allows a genuine third party" in perspective_tests

for token in (
    "0.41.13+152",
    "No learning candidate is consumed by replies",
    "30-minute",
    "No stored user row is deleted or migrated",
):
    assert token in docs, token
assert "PHASE01_TIME_AUDIT_HARDENING_v0.41.13.md" in doc_map
for token in (
    "agent/v04113-phase01-time-audit-hardening",
    "0.41.13+152",
    "Phase 2",
):
    assert token in ledger, token
for token in (
    "Build AI Companion v0.41.13+152 APK (Phase 0+1 Time Audit Hardening)",
    "agent/v04113-phase01-time-audit-hardening",
    "AI-Companion-v0.41.13-152-Phase01-Time-Audit-Hardening-APK",
    "v0.41.13-phase01-time-audit-hardening-test",
    "validate_v04113_phase01_time_audit_hardening.py",
):
    assert token in workflow, token

print("v0.41.13 Phase 0+1 time audit hardening validation passed")
