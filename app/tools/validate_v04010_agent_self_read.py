#!/usr/bin/env python3
"""Static contracts for v0.40.10 on-demand Agent self-system read."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
registry = read("lib/core/agent/agent_tool_registry.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
journal = read("lib/core/agent/agent_outcome_journal.dart")
self_reader = read("lib/core/agent/agent_system_self_reader.dart")
album = read("lib/core/phone/companion_album_discovery_engine.dart")
memory = read("lib/core/ai/memory_extractor.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
registry_test = read("test/agent_tool_registry_test.dart")
planner_test = read("test/agent_tool_planner_fast_route_test.dart")
journal_test = read("test/agent_outcome_journal_test.dart")
facts_test = read("test/agent_system_facts_policy_test.dart")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert "version: 0.40.10+139" in pubspec
assert "static const int schemaVersion = 40;" in database

for token in (
    "id: 'system.self_read'",
    "risk: AgentToolRisk.readOnly",
    "userTurnAvailable: true",
    "autonomousAvailable: false",
):
    assert token in registry, token

for token in (
    "AgentToolRegistry.systemSelfRead.id",
    "'system.self_read': 'system_self_read'",
    "'system_self_read': 'system.self_read'",
    "'recent_outcomes'",
    "真正的 Agent 能力应该怎么设计",
):
    assert token in planner + planner_test, token

assert "AgentSystemSelfReader(" in runner
assert "toolId == AgentToolRegistry.systemSelfRead.id" in runner
assert "Reading the journal must not write" in runner

for token in (
    "static const maxEntries = 24",
    "RegExp(r'^[a-z0-9][a-z0-9_.:-]{0,79}$')",
    "'capability'",
    "'origin'",
    "'status'",
    "'outcome'",
    "'result_count'",
    "'occurred_at'",
):
    assert token in journal, token
for forbidden in ("query", "title", "summary", "url", "path", "error"):
    assert f"'{forbidden}'" not in journal, forbidden

for token in (
    "AgentOutcomeJournal.append",
    "agent_outcome_journal_v1",
    "recentAutonomousActionRuns",
    "reason_source NOT LIKE 'diagnostic_%'",
):
    assert token in database, token

for token in (
    "app_version=0.40.10+139",
    "[SYSTEM_FACT kind=capabilities]",
    "[RECENT_AGENT_OUTCOME source=bounded_local_projection]",
    "id: 'mcp.games'",
    "state: 'not_implemented'",
    "api_secret=false",
    "database_or_file_path=false",
    "tool_argument_or_result_body=false",
):
    assert token in self_reader, token
for forbidden in (
    "readEndpoint",
    "readVisionEndpoint",
    "ensureDeviceId",
    "databasePath",
):
    assert forbidden not in self_reader, forbidden

assert "capabilityId: 'album.autonomous_review'" in album
assert "recordAgentOutcomeEvent" in album and "recordAgentOutcomeEvent" in runner

for token in (
    "[SYSTEM_FACT]",
    "[RECENT_AGENT_OUTCOME]",
    "不得因为 AI 复述它们而生成 ai_self",
    "需要时必须重新读取当前真源",
):
    assert token in memory, token

for token in (
    "'systemSelfRead'",
    "'outcomeJournal'",
    "'systemSelfFactsBodyIncluded': false",
    "'systemSelfSecretsOrEndpointsIncluded': false",
    "'agentOutcomeContentBodiesIncluded': false",
    "'freeTextIncluded': false",
    "'screenImageNotificationChatThoughtBodyIncluded': false",
):
    assert token in diagnostics, token

assert "'system.self_read'" in registry_test
assert "AgentOutcomeJournal" in journal_test
assert "AgentSystemFactsPolicy" in facts_test
assert "mcp.games" in facts_test and "not_implemented" in facts_test

for token in (
    "Build AI Companion v0.40.10+139 APK (Agent Self Read)",
    "agent/v04010-agent-self-read",
    "AI-Companion-v0.40.10-139-Agent-Self-Read-APK",
    "python3 tools/validate_v04010_agent_self_read.py",
):
    assert token in workflow, token

print("v0.40.10 Agent self-system read validation passed")
