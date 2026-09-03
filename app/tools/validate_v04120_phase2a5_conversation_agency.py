#!/usr/bin/env python3
"""Static contracts for v0.41.20 Phase 2A.5 conversation agency."""

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
policy = read("app/lib/core/desire/conversation_initiative_policy.dart")
telemetry = read("app/lib/core/diagnostics/conversation_initiative_telemetry.dart")
runner = read("app/lib/core/ai/durable_generation_runner.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
extractor = read("app/lib/core/ai/memory_extractor.dart")
outcome = read("app/lib/core/desire/ordinary_desire_response.dart")
guard = read("app/lib/core/grounding/information_seeking_question_guard.dart")
diagnostics = read("app/lib/core/diagnostics/preflight_diagnostics.dart")
tests = read("app/test/conversation_agency_phase2a5_test.dart")
plan = read("app/docs/CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert re.search(r"^version:\s*0\.41\.(?:20\+159|21\+160|22\+161|23\+162)\s*$", pubspec, re.MULTILINE)
assert "static const int schemaVersion = 44;" in database
assert any(
    token in self_reader
    for token in (
        "buildLabel = 'v0.41.20+159'",
        "buildLabel = 'v0.41.21+160'",
        "buildLabel = 'v0.41.22+161'",
    )
)

for token in (
    "ConversationTopicMove",
    "ConversationSpeechAct",
    "answer_user",
    "follow_user_jump",
    "branch_from_detail",
    "release_topic",
    "askAuthorized",
    "curiosityGateReason",
    "questionPressureBand",
    "用户情绪只是输入",
    "可见思考链保持自然",
    "继续用户话题不等于被动",
):
    assert token in policy, token
assert "DriveKey.curiosity => ConversationInitiativeMode.probeUserTopic" not in policy
assert "if (explicitJump) return 'user_redirected';" in policy
assert "if (selectedThought == null) return 'no_source';" in policy

for token in (
    "conversationInitiativeOverride",
    "ConversationInitiativeTelemetry.recordPlan",
):
    assert token in prompt, token
for token in (
    "InformationSeekingQuestionGuard.evaluate",
    "askAuthorized: conversationPlan.askAuthorized",
    "NATURAL OUTPUT CORRECTION · ONE RETRY",
    "recordCommittedPlan",
    "ThoughtLifecycleEngine(db: db).markActed",
    "preserveProviderReasoning(generated.reasoning)",
):
    assert token in runner, token
assert runner.index("final conversationPlan = ConversationInitiativePolicy.select") < runner.index(
    "final baseRequestMessages = await PromptBuilder(db).buildChatMessages"
)

for token in (
    "conversation_initiative_telemetry_v2",
    "committedPlanKey",
    "assistant_message_id",
    "plans.reversed.take(12)",
    "planForAssistant",
    "topicMoveCounts",
    "speechActCounts",
    "curiosityGateCounts",
    "askAuthorizedCount",
    "askBlockedCount",
):
    assert token in telemetry, token
for forbidden in (
    "message_text",
    "thought_text",
    "reasoning_content",
):
    assert forbidden not in telemetry, forbidden

for token in (
    "authoritativeHadAiBid",
    "authoritativeDrive",
    "authoritativeAction",
):
    assert token in extractor + outcome, token
assert any(
    token in extractor
    for token in ("手机生成前的权威 Move", "手机落库后的终态行为核验")
)
for token in (
    "thoughtByOutboundMessageId",
    "last_outbound_message_id = ?",
):
    assert token in database, token
for token in (
    "previousConversationThought",
    "_applyOrdinaryThoughtOutcome",
    "thoughtLifecycle.applyResponseOutcome",
):
    assert token in extractor, token

for token in (
    "unauthorized_information_request",
    "_rhetoricalMarkers",
):
    assert token in guard, token
assert any(
    token in guard
    for token in ("askAuthorized || text.trim().isEmpty", "askAuthorized || matches == 0")
)
assert "text.contains('?')" not in guard
assert "informationQuestionGuardMatchedTextIncluded': false" in diagnostics
assert "'informationQuestionGuard':" in diagnostics

for token in (
    "explicit user jump follows the new direction",
    "the same user emotion does not force one support-agent reaction",
    "recent interview rhythm softly blocks",
    "a strong specific curiosity can cross",
    "release language closes",
    "guard preserves teasing rhetorical questions",
    "prompt keeps reasoning visible",
):
    assert token in tests, token

for token in (
    "不改写、隐藏或美化 DeepSeek 可见思考链",
    "Curiosity Gate",
    "反线性对话推进",
    "不复制外部世界书文案或示例",
    "schema 44 / protocol 5 不迁移",
):
    assert token in plan, token

for token in (
    "Build AI Companion v0.41.20+159 APK (Phase 2A.5 Conversation Agency)",
    "agent/v04120-phase2a5-conversation-agency",
    "AI-Companion-v0.41.20-159-Phase2A5-Conversation-Agency-APK",
    "validate_v04120_phase2a5_conversation_agency.py",
):
    assert token in workflow, token
for token in (
    "### 28. 2026-09-02 · Phase 2A.5 对话主动权与自我驱动表达",
    "probe_user_topic=45",
    "stay_with_user_topic=0",
    "CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md",
):
    assert token in ledger, token

print("v0.41.20 Phase 2A.5 conversation agency validation passed")
