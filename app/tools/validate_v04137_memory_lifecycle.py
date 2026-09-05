#!/usr/bin/env python3
"""Static source contract for the v0.41.37 Memory 2D boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB = (ROOT / "lib/core/database/app_database.dart").read_text(encoding="utf-8")
EXTRACTOR = (ROOT / "lib/core/ai/memory_extractor.dart").read_text(encoding="utf-8")
PROMPT = (ROOT / "lib/core/ai/prompt_builder.dart").read_text(encoding="utf-8")
POLICY = (ROOT / "lib/core/memory/memory_lifecycle_policy.dart").read_text(
    encoding="utf-8"
)
PUBSPEC = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")


def require(source: str, token: str, label: str) -> None:
    assert token in source, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.41.37+176", "build identity")
require(DB, "static const int schemaVersion = 49;", "schema identity")
for column in (
    "fact_state",
    "attention_state",
    "recall_policy",
    "spontaneous_salience",
    "lifecycle_source",
    "lifecycle_updated_at",
    "resolved_at",
    "resolution_reason",
):
    require(DB, column, f"schema column {column}")

require(DB, "_stabilizeV49MemoryLifecycle", "legacy lifecycle backfill")
require(DB, "explicit_user_completion_v49_replay", "completion replay provenance")
require(DB, "source_kind = 'unfinished_thread'", "review-envelope closure")
require(DB, "MemoryLifecyclePolicy.eligibleForSpontaneousRecall", "self-drive gate")
require(DB, "retrievalMode == 'proactive'", "proactive retrieval lane")
require(DB, "Retrieval is observation, not new evidence", "no recall reinforcement")

retrieval_start = DB.index("Future<List<MemoryItem>> relevantMemories(")
retrieval_end = DB.index("bool _memoryAssociationCooldownBlocked", retrieval_start)
retrieval_body = DB[retrieval_start:retrieval_end]
assert "item.retentionScore + 0.015" not in retrieval_body, (
    "memory injection must not reinforce retention"
)

for token in (
    "isExplicitCompletion(userText)",
    "isExplicitCancellation(userText)",
    "isExplicitDeferral(userText)",
    "outcome: 'resolved'",
    "outcome: 'deferred'",
):
    require(EXTRACTOR, token, f"local proactive outcome guard {token}")

require(PROMPT, "【本轮事项状态】", "same-turn lifecycle prompt")
require(PROMPT, "这仍不是系统侧独立核验", "capability truth boundary")
require(POLICY, "only a live", "local follow-up authority comment")
require(POLICY, "spontaneousSalience >= 0.68", "spontaneous recall threshold")

print("v0.41.37 Memory 2D source contract validated")
