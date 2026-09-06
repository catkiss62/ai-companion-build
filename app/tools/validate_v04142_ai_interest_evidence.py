#!/usr/bin/env python3
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
policy = read("lib/core/autonomy/ai_interest_evidence_policy.dart")
preflight = read("lib/core/diagnostics/preflight_diagnostics.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert "version: 0.41.42+181" in pubspec
assert "static const int schemaVersion = 54;" in database
for table in (
    "ai_interest_candidates",
    "ai_interest_evidence",
    "ai_interest_versions",
):
    assert f"CREATE TABLE IF NOT EXISTS {table}" in database
    assert f"'{table}'" in database

assert "event_cluster_key TEXT NOT NULL UNIQUE" in database
assert "autonomous_day_count INTEGER NOT NULL DEFAULT 0" in database
assert "_recordAiInterestEvidenceTxn" in database
assert "_revokeAiInterestEvidenceBySourceTxn" in database
assert "deactivateAiInterestCandidate" in database
assert "rollbackAiInterestCandidate" in database
assert "autonomous_web:$id:" in database
assert "autonomous_share:$candidateId" in database
assert "user_feedback:$id" in database
assert "diagnosticRun" in database
assert "user_turn_search" not in database

for excluded in ("diary", "roleplay", "model_self_report", "user_turn_search"):
    assert excluded not in policy
assert "autonomousDays.length >= 2" in policy
assert "source.autonomous" in policy
assert "canCreateCandidate" in policy

assert "aiInterestEvidenceDiagnosticStats" in preflight
assert "'aiInterestEvidence': aiInterestEvidence" in preflight
for redaction in (
    "aiInterestKeysIncluded",
    "aiInterestLabelsOrDomainsIncluded",
    "aiInterestEvidenceBodiesIncluded",
    "aiInterestSourceRefsIncluded",
):
    assert f"'{redaction}': false" in preflight

# Phase 3A is observation-only: it must not be imported by prompt/topic/proactive
# consumers. The only runtime consumer is redacted diagnostics.
for consumer in (
    "lib/core/ai/prompt_builder.dart",
    "lib/core/autonomy/public_web_discovery_policy.dart",
    "lib/core/autonomy/proactive_engine.dart",
):
    path = ROOT / consumer
    if path.exists():
        assert "ai_interest_evidence_policy" not in path.read_text(encoding="utf-8")

assert "agent/v04142-phase3a-interest-evidence" in workflow
assert "Build AI Companion v0.41.42+181 APK" in workflow
assert "AI-Companion-v0.41.42-181-Phase3A-Interest-Evidence-APK" in workflow

# Execute the exact embedded CREATE TABLE statements, then prove the event
# cluster uniqueness and candidate->evidence/version cascade used by restore.
conn = sqlite3.connect(":memory:")
conn.execute("PRAGMA foreign_keys = ON")
for table in (
    "ai_interest_candidates",
    "ai_interest_evidence",
    "ai_interest_versions",
):
    match = re.search(
        rf"CREATE TABLE IF NOT EXISTS {table} \((.*?)\n\s*\)\n\s*''\'\);",
        database,
        re.S,
    )
    assert match, f"cannot extract {table} DDL"
    conn.execute(f"CREATE TABLE IF NOT EXISTS {table} ({match.group(1)})")
conn.execute(
    "INSERT INTO ai_interest_candidates "
    "(id, interest_key, first_observed_at, created_at, updated_at) "
    "VALUES ('candidate', 'curiosity:test', 1, 1, 1)"
)
conn.execute(
    "INSERT INTO ai_interest_evidence "
    "(id, candidate_id, event_cluster_key, source_kind, source_ref, polarity, "
    "weight, local_day, occurred_at, created_at) VALUES "
    "('e1', 'candidate', 'run:one', 'autonomous_web_verified', 'source', "
    "1, 0.8, '2026-09-06', 1, 1)"
)
try:
    conn.execute(
        "INSERT INTO ai_interest_evidence "
        "(id, candidate_id, event_cluster_key, source_kind, source_ref, polarity, "
        "weight, local_day, occurred_at, created_at) VALUES "
        "('e2', 'candidate', 'run:one', 'autonomous_web_verified', 'source2', "
        "1, 0.8, '2026-09-06', 2, 2)"
    )
    raise AssertionError("duplicate event cluster was accepted")
except sqlite3.IntegrityError:
    pass
conn.execute(
    "INSERT INTO ai_interest_versions "
    "(id, candidate_id, version, status, support_count, counter_count, "
    "autonomous_day_count, confidence, freshness, created_at) VALUES "
    "('v1', 'candidate', 1, 'forming', 1, 0, 1, 0.6, 1, 1)"
)
conn.execute("DELETE FROM ai_interest_candidates WHERE id = 'candidate'")
assert conn.execute("SELECT COUNT(*) FROM ai_interest_evidence").fetchone()[0] == 0
assert conn.execute("SELECT COUNT(*) FROM ai_interest_versions").fetchone()[0] == 0
print("v0.41.42 Phase 3A AI-interest evidence validation passed")
