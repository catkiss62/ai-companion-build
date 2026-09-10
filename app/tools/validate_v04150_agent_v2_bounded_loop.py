#!/usr/bin/env python3
"""Structural, safety and regression contracts for v0.41.50 Agent v2."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
self_reader = read("lib/core/agent/agent_self_reader.dart")
policy = read("lib/core/agent/agent_task_loop.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
durable = read("lib/core/ai/durable_generation_runner.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
reference = read("lib/core/reference/reference_library.dart")
presets = read("lib/core/reference/world_book_presets.dart")
tests = read("test/agent_task_loop_v04150_test.dart")
ledger = (REPO / "AI_Companion_当前总账.md").read_text(encoding="utf-8")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(r"^version:\s*0\.41\.(?:50\+189|51\+190|52\+191|53\+192|54\+193|55\+(?:195|196|197|198|199)|56\+200|57\+201|58\+202|59\+203)$", pubspec, re.M)
assert re.search(r"static const int schemaVersion = (?:56|57|58|59);", database)
assert "buildLabel = 'v0.41.50+189'" in self_reader
assert "agent/v04150-agent-v2-bounded-loop" in workflow
assert "Build AI Companion v0.41.50+189 APK" in workflow
assert "AI-Companion-v0.41.50-189-Agent-v2-Bounded-Loop-APK" in workflow
assert "v0.41.50-agent-v2-bounded-loop-test" in workflow
assert "python3 tools/validate_v04150_agent_v2_bounded_loop.py" in workflow

# One user turn may replan, but the limits are local constants rather than
# prompt suggestions. Every execution round remains small.
assert "maxPlanningRounds = 3" in policy
assert "maxToolCalls = 6" in policy
assert "maxCallsPerRound = 2" in policy
assert "不得原样重试同一工具和参数" in policy
assert "不要输出计划" in policy
assert "callFingerprint" in policy
assert "excludedCallFingerprints" in planner
assert "result.take(AgentTaskLoopPolicy.maxToolCalls)" in planner
assert "callIndexOffset + index" in runner
assert "plan.calls.take(boundedMaxCalls)" in runner

# The second and third planning requests receive the same narrow task toolbox,
# while finalization explicitly closes tools and returns true terminal counts.
assert "while (toolsOpen && generated.toolCalls.isNotEmpty)" in durable
assert "tools: taskToolDefinitions" in durable
assert "finalizationMessages" in durable
assert "AgentTaskLoopPolicy.verify" in durable
assert "executedToolFingerprints" in durable
assert "callIndexOffset: agentToolCalls" in durable
assert "AgentTaskLoopPolicy.containsProposal" in durable
assert "AgentTaskLoopPolicy.hasCommitPendingMedia" in durable
assert "currentToolResults: agentToolResults" in durable
assert "GenerationCancelledByUserException" in durable
assert "isGenerationRunCurrent" in durable
assert "renewLocalLease" in durable

# Diagnostics contain counts and states only, never plans, arguments or result
# bodies. System self-read describes the bounded capability honestly.
for token in (
    "bounded_observe_act_verify_v2",
    "maxPlanningRoundsPerTurn",
    "maxCallsPerPlanningRound",
    "v2MultiRoundTurnCount",
    "v2LastVerification",
):
    assert token in diagnostics
assert "agent_v2_bounded_loop_v04150" in self_reader
assert "最多三个规划回合、六次调用" in self_reader

# The humor expansion remains intact and below the actual behavior injection
# budget. v0.41.50 must not silently inflate the permanent prompt to 30k.
assert "var remaining = worldBookCategoryPromptLimit;" in reference
assert "const worldBookCategoryPromptLimit = 30000;" in reference
humor = re.search(r"const worldBookHumorV04149 = '''(.*?)''';", presets, re.S)
assert humor and 2400 <= len(humor.group(1)) <= 5000
assert "四个行为模块总正文约 11,321 字" in ledger
assert "不会因造梗扩写而截断" in ledger

# Tests cover budgets, exact-repeat rejection, proposal separation and local
# terminal verification. Prompt additions keep the user's no-paired-stars rule.
for token in (
    "three planning rounds and six total calls",
    "rejects an exact repeated call",
    "remaining global budget can reduce a round to one call",
    "never upgrades partial or absent outcomes",
    "proposal tools remain distinguishable",
):
    assert token in tests
assert "**" not in policy

print("v0.41.50 Agent v2 bounded loop validation passed")
