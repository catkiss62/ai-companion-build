#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
item = read("lib/core/models/memory_item.dart")
policy = read("lib/core/memory/memory_retrieval_policy.dart")
brain = read("lib/core/memory/memory_brain.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
extractor = read("lib/core/ai/memory_extractor.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
contract = read("lib/core/emotion/emotion_contract.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
tests = read("test/memory_retrieval_policy_test.dart")
emotion_tests = read("test/emotion_contract_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.37.7+96" in pubspec
assert "static const int schemaVersion = 31;" in database
assert "if (oldVersion < 31)" in database
for token in (
    "last_expressed_at",
    "expression_count",
    "_createV31Tables",
    "memory_retrieval_audit",
    "memoryRetrievalDiagnosticStats",
    "markRecentlyInjectedMemoriesExpressed",
):
    assert token in database, token

for token in (
    "class MemoryRetrievalPolicy",
    "without",
    "no_direct_seed",
    "ambiguous_single_overlap",
    "recently_injected_or_expressed",
    "Duration(hours: 18)",
    "Importance, confidence and pinned status",
):
    assert token in policy, token
assert "item.importance * 0.34" not in database
assert "final stableUser = await db.memoriesByKind" not in brain
assert "retrievalMode: mode.name" in prompt
assert "只在当前话题需要时使用，不要为了证明记得而主动复述" in brain

assert "lastExpressedAt" in item
assert "expressionCount" in item
assert "markRecentlyInjectedMemoriesExpressed" in extractor
assert "'memoryRetrieval': memoryRetrievalDiagnostics" in diagnostics
assert "'memoryRetrievalQueriesIncluded': false" in diagnostics

assert proactive.count("EmotionEnvelope.parse") >= 2
assert "EmotionClassifierService.instance.resolve" in proactive
assert "emotionRawTag: companionEmotion.rawTag" in proactive
assert "content: emotionEnvelope.visibleText" in proactive
assert "markRecentlyInjectedMemoriesExpressed" in proactive
for token in (
    "_complete",
    "_selfClosing",
    "_opening",
    "_stripReservedMarkup",
):
    assert token in contract, token
for token in (
    "<emotion></emotion>",
    "invalid envelope falls back but never leaks",
    "misplaced and duplicate emotion tags",
):
    assert token in emotion_tests, token

for token in (
    "unrelated importance and pinning never manufacture relevance",
    "generic affection overlap does not recall a different preference",
    "recent weak match cools down but explicit topic can break through",
    "visible expression cursor also participates in cooldown",
):
    assert token in tests, token

for token in (
    "Build AI Companion v0.37.7+96 APK (Layered Memory Retrieval)",
    "validate_v0377_layered_memory_retrieval.py",
    "AI-Companion-v0.37.7-96-Layered-Memory-Retrieval-APK.apk",
    ".ci/v0377-monitor.txt",
):
    assert token in workflow, token

print("v0.37.7 layered memory retrieval and proactive emotion normalization validation passed")
