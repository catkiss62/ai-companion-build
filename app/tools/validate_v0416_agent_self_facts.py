#!/usr/bin/env python3
"""Static privacy, migration and routing contracts for v0.41.6."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
registry = read("lib/core/agent/agent_tool_registry.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
self_reader = read("lib/core/agent/agent_self_reader.dart")
durable = read("lib/core/ai/durable_generation_runner.dart")
snapshot = read("lib/core/sync/snapshot_service.dart")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
ledger = (REPO / "AI_Companion_当前总账.md").read_text(encoding="utf-8")

current = "version: 0.41.34+173" in pubspec
assert current or re.search(r"^version:\s*0\.41\.(?:6\+145|7\+146|8\+147|9\+148|10\+149|11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157|19\+158|20\+159|21\+160|22\+161|23\+162|24\+163)\s*$", pubspec, re.M)
agent_truth_or_newer = current or any(version in pubspec for version in (
    "version: 0.41.14+153", "version: 0.41.18+157", "version: 0.41.19+158", "version: 0.41.20+159", "version: 0.41.21+160", "version: 0.41.22+161"
))
assert current or "static const int schemaVersion = 41;" in database
assert "if (oldVersion < 41)" in database
assert "await _createV41Tables(db);" in database

create_table = re.search(
    r"CREATE TABLE IF NOT EXISTS agent_tool_outcomes \((.*?)\n\s*\)",
    database,
    re.S,
)
assert create_table is not None
table_sql = create_table.group(1)
for column in (
    "tool_id",
    "origin",
    "status",
    "reason_tag",
    "outcome_kind",
    "result_count",
    "error_code",
    "started_at",
    "finished_at",
    "source_device_id",
    "source_device_label",
):
    assert column in table_sql, column
for forbidden in (
    "query",
    "url",
    "arguments",
    "prompt",
    "result_body",
    "reasoning",
    "provider_payload",
    "chat_content",
):
    assert forbidden not in table_sql, forbidden

for token in (
    "recordAgentToolOutcome",
    "recentAgentToolOutcomes",
    "recentAutonomousActionOutcomes",
    "LIMIT 200",
    "Duration(days: 90)",
    "safeErrorCodes",
    "'redacted_error'",
):
    assert token in database, token
assert database.count("'agent_tool_outcomes',") >= 3
complete_archive_block = snapshot.split(
    "const completeArchiveTables = <String>[", 1
)[1].split("];", 1)[0]
assert "agent_tool_outcomes" not in complete_archive_block

for token in (
    "id: 'system_self.read'",
    "executable: true",
    "userTurnAvailable: true",
    "autonomousAvailable: false",
    "systemSelfRead",
):
    assert token in registry, token
for placeholder in (
    "videoUnderstanding",
    "memoryProposal",
    "reminderSchedule",
    "mcpInvoke",
):
    block = registry.split(f"static const {placeholder} =", 1)[1].split(");", 1)[0]
    assert "executable: false" in block, placeholder
screen_block = registry.split("static const screenObservation =", 1)[1].split(
    ");", 1
)[0]
if agent_truth_or_newer:
    assert "executable: true" in screen_block
    assert "userTurnAvailable: true" in screen_block
    assert "autonomousAvailable: false" in screen_block
else:
    assert "executable: false" in screen_block

for token in (
    "explicitRecentOutcomes",
    "explicitSystemFacts",
    "'system_self.read': 'system_self_read'",
    "'system_self_read': 'system_self.read'",
    "<String>['facts', 'outcomes', 'growth', 'all']"
    if agent_truth_or_newer
    else "['facts', 'outcomes', 'all']",
):
    assert token in planner, token

for token in (
    "AgentSelfReader(db: db, android: android).read(scope)",
    "eventScopeId",
    "recordAgentToolOutcome",
    "_eventId("
    if agent_truth_or_newer
    else "user_turn:$stableScope:${call.toolId}:$callIndex",
    "AgentToolStatus.failed => 'execution_failed'",
):
    assert token in runner, token
assert durable.count("eventScopeId: job.id") == 2

for token in (
    "buildLabel = 'v0.41.34+173'"
    if current
    else "buildLabel = 'v0.41.24+163'"
    if "version: 0.41.24+163" in pubspec
    else "buildLabel = 'v0.41.23+162'"
    if "version: 0.41.23+162" in pubspec
    else "buildLabel = 'v0.41.22+161'"
    if "version: 0.41.22+161" in pubspec
    else "buildLabel = 'v0.41.21+160'"
    if "version: 0.41.21+160" in pubspec
    else "buildLabel = 'v0.41.20+159'"
    if "version: 0.41.20+159" in pubspec
    else "buildLabel = 'v0.41.19+158'"
    if "version: 0.41.19+158" in pubspec
    else "buildLabel = 'v0.41.18+157'"
    if "version: 0.41.18+157" in pubspec
    else "buildLabel = 'v0.41.14+153'"
    if "version: 0.41.14+153" in pubspec
    else "buildLabel = 'v0.41.13+152'",
    "Duration(days: 14)",
    ".take(8)",
    "'not_implemented'",
    "不得声称这些功能是你自己编写的",
    "不得补写未提供的具体内容",
    "密钥、API endpoint、原始日志、数据库路径、聊天正文",
    "device=$device",
):
    assert token in self_reader, token
assert "device=${outcome.sourceDeviceId}" not in self_reader
assert "device=${outcome.sourceDeviceLabel}" not in self_reader

preflight = read("lib/core/diagnostics/preflight_diagnostics.dart")
for token in (
    "agentToolOutcomeDeviceIdsIncluded': false",
    "agentToolOutcomeDiagnosticStats",
    "'recentOutcomes': agentToolOutcomes",
):
    assert token in preflight, token

for test_file in (
    "test/agent_self_reader_v0416_test.dart",
    "test/agent_tool_planner_fast_route_test.dart",
    "test/agent_tool_registry_test.dart",
):
    assert (ROOT / test_file).is_file(), test_file

for token in (
    "Build AI Companion v0.41.6+145 APK (Agent Self Facts)",
    "agent/v0416-agent-self-facts",
    "AI-Companion-v0.41.6-145-Agent-Self-Facts-APK",
    "v0.41.6-agent-self-facts-test",
    ".ci/v0416-monitor.txt",
    "python3 tools/validate_v0416_agent_self_facts.py",
):
    assert token in workflow, token

for token in (
    "v0.41.6 Agent 自我系统事实与近期 Outcome",
    "agent/v0416-agent-self-facts",
    "0.41.6+145",
    "schemaVersion=41",
):
    assert token in ledger, token

print("v0.41.6 Agent Self Facts validation passed")
