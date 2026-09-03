#!/usr/bin/env python3
"""Static contracts for v0.41.21 Phase 2A.5 responsibility ablation."""

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
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
runner = read("app/lib/core/ai/durable_generation_runner.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
extractor = read("app/lib/core/ai/memory_extractor.dart")
telemetry = read("app/lib/core/diagnostics/conversation_initiative_telemetry.dart")
verifier = read("app/lib/core/desire/conversation_outcome_verifier.dart")
question_guard = read("app/lib/core/grounding/information_seeking_question_guard.dart")
web_policy = read("app/lib/core/autonomy/public_web_prompt_policy.dart")
tests = read("app/test/conversation_responsibility_ablation_v04121_test.dart")
plan = read("app/docs/CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert re.search(r"^version:\s*0\.41\.(?:21\+160|22\+161)\s*$", pubspec, re.MULTILINE)
assert "static const int schemaVersion = 44;" in database
assert any(
    token in self_reader
    for token in ("buildLabel = 'v0.41.21+160'", "buildLabel = 'v0.41.22+161'")
)

for token in (
    "ConversationOutcomeVerifier.verify",
    "sourceConversationThought",
    "expressionVerification.shouldMarkThoughtActed",
    "verification: expressionVerification",
    "与获授权 Thought 不匹配",
):
    assert token in runner, token
assert "conversationPlan.hadAiBid &&" not in runner

for token in (
    "plannedSpeechAct",
    "expressed_had_ai_bid",
    "source_thought_expressed",
    "expression_match_reason",
    "legacy_plan_only",
    "expressionMismatchCount",
):
    assert token in telemetry, token

for token in (
    "ask_source_mismatch",
    "planned_bid_not_expressed",
    "sourceThoughtExpressed",
    "shouldMarkThoughtActed",
    "_semanticallyMatches",
):
    assert token in verifier, token
for token in (
    "hasInformationRequest",
    "hasRhetoricalQuestion",
    "authorized_information_request",
    "rhetorical_only",
):
    assert token in question_guard, token

for token in (
    "PublicWebPromptPolicy.candidateIds",
    "publicWebContextByIds",
    "_selectedConversationThoughtSection",
    "SELECTED_THOUGHT_DATA",
):
    assert token in prompt, token
assert "activePublicWebContext(" not in prompt
for token in (
    "hasCurrentUserWebResult",
    "selectedCandidateId",
    "PublicWebSharePolicy.isCandidateThought",
):
    assert token in web_policy, token
for token in (
    "does not promote an",
    "lifecycle_state NOT IN",
):
    assert token in database, token

for token in (
    "手机落库后的终态行为核验",
    "planned_speech_act 只是生成前意图",
    "had_ai_bid=false 时不得因用户继续聊天而补记满足",
):
    assert token in extractor, token

for token in (
    "authorized ask without a real question remains unacted",
    "authorized ask must match the selected Thought",
    "matching information request can become an acted Thought",
    "rhetorical teasing is not converted into information seeking",
    "unselected autonomous results are not ambient prompt context",
    "current user web tool results exclude autonomous cards",
):
    assert token in tests, token

for token in (
    "终态真值",
    "生成前 Thought/Move/Gate 只是意图",
    "分享前重新阅读的核心是恢复上下文",
    "恢复当前详细上下文",
):
    assert token in plan + ledger, token

for token in (
    "Build AI Companion v0.41.21+160 APK (Phase 2A.5 Responsibility Ablation)",
    "agent/v04121-phase2a5-system-responsibility-ablation",
    "AI-Companion-v0.41.21-160-Phase2A5-Responsibility-Ablation-APK",
    "validate_v04121_phase2a5_responsibility_ablation.py",
    ".ci/v04121-monitor.txt",
):
    assert token in workflow, token

print("v0.41.21 Phase 2A.5 responsibility ablation validation passed")
