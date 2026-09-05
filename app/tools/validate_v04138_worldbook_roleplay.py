#!/usr/bin/env python3
"""Static source contract for v0.41.38 WorldBook 2D provenance."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB = (ROOT / "lib/core/database/app_database.dart").read_text(encoding="utf-8")
PROMPT = (ROOT / "lib/core/ai/prompt_builder.dart").read_text(encoding="utf-8")
EXTRACTOR = (ROOT / "lib/core/ai/memory_extractor.dart").read_text(encoding="utf-8")
REFERENCE = (ROOT / "lib/core/reference/reference_library.dart").read_text(encoding="utf-8")
HISTORY = (ROOT / "lib/core/reference/world_book_history_policy.dart").read_text(encoding="utf-8")
SELF_ENGINE = (ROOT / "lib/core/self/ai_self_reflection_engine.dart").read_text(encoding="utf-8")
SELF_POLICY = (ROOT / "lib/core/self/ai_self_evidence_policy.dart").read_text(encoding="utf-8")
RULES = (ROOT / "lib/core/rules/rule_layer_service.dart").read_text(encoding="utf-8")
EMOTION = (ROOT / "lib/core/emotion/emotion_contract.dart").read_text(encoding="utf-8")
PUBSPEC = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")


def require(source: str, token: str, label: str) -> None:
    assert token in source, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.41.38+177", "build identity")
require(DB, "static const int schemaVersion = 50;", "schema identity")
for column in (
    "worldbook_context_json",
    "source_reference_document_id",
    "source_reference_document_version",
):
    require(DB, column, f"schema provenance column {column}")

for token in (
    "_stabilizeV50WorldBook",
    "entry_type': 'roleplay'",
    "builtin.worldbook.special.$styleKey",
    "status': 'ended'",
    "appendWorldBookRoleplayContinuity",
    "referenceDocumentsByIds",
):
    require(DB, token, f"migration/runtime boundary {token}")

require(PROMPT, "PromptBuildResult", "atomic prompt provenance result")
require(PROMPT, "WorldBookTurnContext.fromDocuments", "prompt source snapshot")
require(PROMPT, "WorldBookHistoryPolicy.forActiveRoleplay", "cross-role history filter")
require(PROMPT, "当前角色扮演 Session · 早先剧情尾部", "source-session resume")
require(REFERENCE, "Future<WorldBookPromptBundle> roleplayForPrompt", "roleplay prompt lane")
require(REFERENCE, "临时娱乐扮演", "roleplay reality contract")
require(HISTORY, "if (message.isProactive) continue", "proactive pairing guard")

roleplay_guard = EXTRACTOR.index("if (worldBookContext.hasRoleplay)")
expression_write = EXTRACTOR.index("markRecentlyInjectedMemoriesExpressed", roleplay_guard)
assert roleplay_guard < expression_write, "roleplay must exit before ordinary expression reinforcement"
require(EXTRACTOR, "appendWorldBookRoleplayContinuity", "partitioned roleplay continuity")
require(EXTRACTOR, "return;", "roleplay hard extraction exit")
require(EXTRACTOR, "knowledgeReferenceActive", "knowledge memory gate")
require(EXTRACTOR, "user_evidence_quote", "verbatim user evidence for knowledge turns")

require(SELF_ENGINE, "evidence_message_ids", "model evidence citations")
require(SELF_ENGINE, "ai_self_tendency", "autonomous self tendency lane")
require(SELF_POLICY, "requested.length < 3", "multi-message evidence floor")
require(SELF_POLICY, "Duration(hours: 2)", "independent time buckets")
require(SELF_POLICY, "evidence.length >= 4 && days.length >= 2", "cross-day promotion")
require(SELF_POLICY, "roleplay_evidence", "roleplay evidence rejection")
require(SELF_POLICY, "knowledge_reference_evidence", "knowledge self-evidence rejection")

require(RULES, "specialStylePrompt: ''", "legacy ordinary-chat route retirement")
assert "await db.activeSpecialStyleTrial()" not in RULES, (
    "ordinary RuleLayerService must not retain legacy special-style injection"
)

require(EMOTION, "_recoverableEmFirstLine", "leading em compatibility")
require(EMOTION, "EmotionCatalog.isCanonicalLabel(candidate)", "bounded em label allowlist")

print("v0.41.38 WorldBook 2D roleplay provenance source contract validated")
