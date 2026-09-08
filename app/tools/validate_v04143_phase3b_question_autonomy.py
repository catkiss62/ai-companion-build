#!/usr/bin/env python3
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
engine = read("lib/core/desire/proactive_engine.dart")
selection = read("lib/core/desire/proactive_selection_policy.dart")
discovery = read("lib/core/autonomy/public_web_discovery_engine.dart")
planner = read("lib/core/autonomy/public_web_question_planner.dart")
readiness = read("lib/core/desire/proactive_thought_readiness_policy.dart")
preflight = read("lib/core/diagnostics/preflight_diagnostics.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(
    r"^version:\s*0\.41\.(?:43\+182|44\+183|45\+184|46\+185|47\+186|48\+187)$",
    pubspec,
    re.M,
)
assert "static const int schemaVersion = 55;" in database
assert "agent/v04143-phase3b-question-autonomy" in workflow
assert (
    "Build AI Companion v0.41.43+182 APK" in workflow
    or "Build AI Companion v0.41.44+183 APK" in workflow
    or "Build AI Companion v0.41.45+184 APK" in workflow
)
assert (
    "AI-Companion-v0.41.43-182-Phase3B-Question-Autonomy-APK" in workflow
    or "AI-Companion-v0.41.44-183-Autonomy-Arbitration-Rework-APK" in workflow
    or "AI-Companion-v0.41.45-184-Sticker-Expression-APK" in workflow
)

# The question planner receives only taxonomy metadata and a drive category.
for allowed in ("public_topic", "public_domain", "curiosity_mode", "drive_category"):
    assert allowed in planner
for forbidden in (
    "CompanionThought",
    "ChatMessage",
    "MemoryItem",
    "latestUserText",
    "recentMessages",
    "roleplay",
):
    assert forbidden not in planner
for rejected in ("服务", "取悦", "讨好", "服从", "迎合", "用户刚才", "聊天记录"):
    assert rejected in planner
assert "taxonomy_fallback" in planner
assert "generated_question" in planner
assert "questionPlan.query" in discovery
assert "public_web_last_query_plan_mode" in discovery

# Local maintenance cannot silently execute discovery/reread before selection.
heartbeat = engine.split("Future<LocalCompanionHeartbeat> _runLocalHeartbeat", 1)[1]
heartbeat = heartbeat.split("Future<ProactiveDecision> evaluate", 1)[0]
assert "publicWebDiscovery.maybeDiscover" not in heartbeat
assert "publicWebSharing.stageNextCandidate" not in heartbeat
for action in ("discover_interest", "prepare_public_web_share"):
    assert action in engine
for behavior in (
    "proactive_message",
    "public_web_discovery",
    "public_web_share",
    "rest",
    "wait",
):
    assert behavior in selection
assert "recentAutonomousBehaviors" in engine
assert "ProactiveThoughtReadinessPolicy.isReady" in engine
assert "Thought may remain useful for ordinary conversational recall" in readiness

for token in (
    "CREATE TABLE IF NOT EXISTS autonomous_behavior_events",
    "heartbeat_key TEXT NOT NULL UNIQUE",
    "claimAutonomousBehavior",
    "finishAutonomousBehavior",
    "'autonomous_behavior_events'",
    "autonomousBehaviorDiagnosticStats",
):
    assert token in database
assert "'autonomousBehaviors': autonomousBehaviors" in preflight
for redaction in (
    "heartbeatKeysIncluded",
    "topicHashesIncluded",
    "sourceIdsIncluded",
    "questionBodiesIncluded",
):
    assert f"'{redaction}': false" in database

# Prove the schema-level one-behavior-per-heartbeat invariant independently.
match = re.search(
    r"CREATE TABLE IF NOT EXISTS autonomous_behavior_events \((.*?)\n\s*\)\n\s*'''\);",
    database,
    re.S,
)
assert match, "cannot extract autonomous behavior DDL"
conn = sqlite3.connect(":memory:")
conn.execute(f"CREATE TABLE autonomous_behavior_events ({match.group(1)})")
row = ("one", "heartbeat", "rest", "internal", "unknown", "", "selected", "ordinary", 1)
conn.execute(
    "INSERT INTO autonomous_behavior_events "
    "(id,heartbeat_key,behavior_kind,source_type,intent_kind,topic_hash,status,reason_tag,started_at) "
    "VALUES (?,?,?,?,?,?,?,?,?)",
    row,
)
try:
    conn.execute(
        "INSERT INTO autonomous_behavior_events "
        "(id,heartbeat_key,behavior_kind,source_type,intent_kind,topic_hash,status,reason_tag,started_at) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        ("two",) + row[1:],
    )
    raise AssertionError("a second behavior was accepted for one heartbeat")
except sqlite3.IntegrityError:
    pass

for test in (
    "test/public_web_question_planner_v04143_test.dart",
    "test/proactive_phase3b_behavior_policy_v04143_test.dart",
):
    assert (ROOT / test).is_file()

print("v0.41.43 Phase 3B question-autonomy validation passed")
