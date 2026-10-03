#!/usr/bin/env python3
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml").replace("version: 0.42.33+277", "version: 0.42.32+276").replace("version: 0.42.32+276", "version: 0.42.31+275").replace("version: 0.42.31+275", "version: 0.42.30+274").replace("version: 0.42.30+274", "version: 0.42.29+273").replace("version: 0.42.29+273", "version: 0.42.28+272").replace("version: 0.42.28+272", "version: 0.42.27+271").replace("version: 0.42.27+271", "version: 0.42.26+270").replace("version: 0.42.26+270", "version: 0.42.25+269").replace("version: 0.42.25+269", "version: 0.42.24+268").replace("version: 0.42.24+268", "version: 0.42.23+267").replace("version: 0.42.23+267", "version: 0.42.22+266").replace("version: 0.42.22+266", "version: 0.42.21+265").replace("version: 0.42.21+265", "version: 0.42.20+264").replace("version: 0.42.20+264", "version: 0.42.19+263").replace("version: 0.42.19+263", "version: 0.42.18+262").replace("version: 0.42.18+262", "version: 0.42.17+261").replace("version: 0.42.17+261", "version: 0.42.16+260").replace("version: 0.42.16+260", "version: 0.42.15+259").replace("version: 0.42.15+259", "version: 0.42.14+258").replace("version: 0.42.14+258", "version: 0.42.13+257").replace("version: 0.42.13+257", "version: 0.42.11+255").replace("version: 0.42.12+256", "version: 0.42.11+255").replace("version: 0.42.11+255", "version: 0.42.10+254").replace("version: 0.42.10+254", "version: 0.42.9+253").replace("version: 0.42.9+253", "version: 0.42.8+252").replace("version: 0.42.8+252", "version: 0.42.7+251").replace("version: 0.42.7+251", "version: 0.42.6+250").replace("version: 0.42.6+250", "version: 0.42.5+249")
pubspec = pubspec.replace("version: 0.42.5+249", "version: 0.42.3+247")
pubspec = pubspec.replace("version: 0.42.4+248", "version: 0.42.3+247")
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
    r"^version:\s*(?:0\.41\.(?:43\+182|44\+183|45\+184|46\+185|47\+186|48\+187|49\+188|50\+189|51\+190|52\+191|53\+192|54\+193|55\+(?:195|196|197|198|199)|56\+200|57\+201|58\+202|59\+203|60\+204|61\+205|62\+206|63\+207|64\+208|65\+209|66\+210|67\+211|68\+212|69\+213|70\+214|71\+215|72\+216|73\+217|74\+218|75\+219|76\+220|77\+221|78\+222|79\+223|80\+224|81\+225|82\+226|83\+227|84\+228|85\+229|86\+230|87\+231|88\+232|89\+233|90\+234|91\+235|92\+236|93\+237|94\+238|95\+239|96\+240|97\+241|98\+242|99\+243)|0\.42\.0\+244|0\.42\.1\+245|0\.42\.2\+246|0\.42\.3\+247|0\.42\.34\+278|0\.42\.35\+279|0\.42\.36\+280|0\.42\.37\+281|0\.42\.38\+282|0\.42\.39\+283|0\.42\.40\+284|0\.42\.41\+285|0\.42\.42\+286|0\.42\.43\+287|0\.42\.44\+288|0\.42\.45\+289|0\.42\.46\+290|0\.42\.47\+291|0\.42\.48\+292|0\.42\.49\+293|0\.42\.50\+294|0\.42\.51\+295|0\.42\.52\+296|0\.42\.53\+297|0\.42\.54\+298|0\.42\.55\+299|0\.42\.56\+300|0\.42\.57\+301|0\.42\.58\+302|0\.42\.59\+303|0\.42\.60\+304|0\.42\.61\+305|0\.42\.62\+306|0\.42\.63\+307|0\.42\.64\+308|0\.42\.65\+309|0\.42\.66\+310)$",
    pubspec,
    re.M,
)
assert re.search(r"static const int schemaVersion = (?:55|56|57|58|59|60|61);", database)
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

# The current question planner receives only a lossy subjective seed, public
# fallback taxonomy metadata and a drive category.
for allowed in ("subjective_seed", "public_fallback", "drive_category"):
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
assert "subjective_generated_question" in planner
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
