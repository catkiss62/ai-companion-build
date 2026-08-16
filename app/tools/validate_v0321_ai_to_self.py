#!/usr/bin/env python3
"""Static contract checks for v0.32.1 committed AI-to-self somatic echo."""

from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"ERROR: missing {label}: {needle}")


policy = read("lib/core/somatic/somatic_policy.dart")
engine = read("lib/core/somatic/somatic_engine.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
db = read("lib/core/database/app_database.dart")
tests = read("test/somatic_policy_test.dart")
pubspec = read("pubspec.yaml")

if not any(version in pubspec for version in (
    "version: 0.32.2+54", "version: 0.33.0+55", "version: 0.33.1+56", "version: 0.33.2+57", "version: 0.33.3+58", "version: 0.33.4+59", "version: 0.33.5+60", "version: 0.33.6+61", "version: 0.33.7+62", "version: 0.33.9+64", "version: 0.34.0+65",
)):
    raise SystemExit("ERROR: unsupported current release version")
require(policy, "detectAssistantSelfTouch", "assistant detector")
require(policy, "SomaticDirection.aiToSelf", "AI-to-self direction")
require(policy, "source: 'assistant_committed'", "committed source")
require(policy, "fullStrength * 0.5", "half-strength echo")
require(policy, "_isProspectiveOrNegated", "intention/negation filter")
require(engine, "assistantCommitEvents", "engine commit event builder")
require(runner, "assistantSomaticEvents = somaticEngine.assistantCommitEvents", "pure pre-commit detection")
require(runner, "somaticEvents: assistantSomaticEvents", "commit handoff")
require(db, "List<SomaticEvent> somaticEvents = const <SomaticEvent>[]", "atomic commit parameter")
require(db, "event.turnId != assistant.id", "assistant turn fence")
require(db, "event.direction != SomaticDirection.aiToSelf", "direction fence")
require(db, "event.direction == SomaticDirection.userToAi", "source-role validation")
require(db, "? 'user'", "user source role")
require(db, ": 'assistant'", "assistant source role")
require(db, "invalid_assistant_somatic_event", "invalid event rollback")
require(db, "generation_commit_ownership_lost", "durable ownership fence")
require(db, "_recordSomaticEventsInTransaction(\n        txn,\n        somaticEvents,\n        assistant.createdAt,", "same-transaction pulse")
require(tests, "committed assistant action echoes to self at half strength", "half-strength unit test")
require(tests, "assistant intention and negation do not create self sensation", "false-positive unit test")
require(tests, "assistant recovery identity is deterministic", "recovery unit test")

method_start = db.index("Future<bool> completeGenerationJobIfCurrent")
method_end = db.index("Future<GenerationJob?> failGenerationJob", method_start)
method = db[method_start:method_end]
completion_check = method.index("if (completed != 1)")
pulse_write = method.index("_recordSomaticEventsInTransaction", completion_check)
return_true = method.index("return true;", pulse_write)
if not (completion_check < pulse_write < return_true):
    raise SystemExit("ERROR: somatic pulse is not fenced after durable completion")

print("v0.32.1 AI-to-self somatic contract validated.")
