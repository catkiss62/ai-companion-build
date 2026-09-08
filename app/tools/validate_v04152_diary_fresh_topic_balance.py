#!/usr/bin/env python3
"""Structural and privacy contracts for v0.41.52."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


assert "version: 0.41.52+191" in read("pubspec.yaml")
assert "static const int schemaVersion = 56;" in read(
    "lib/core/database/app_database.dart"
)

diary = read("lib/core/phone/simulated_diary_generator.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
for token in (
    "DeepSeekModelProfile.flash",
    "SimulatedDiaryQuality.acceptable",
    "similarity(trimmed, recent) < 0.72",
    "不得补造用户说过的话",
    "factualFallback",
):
    assert token in diary + repository, token
for token in ("sharedMoments", "cares", "carriedThreads", "awarenessSummaries"):
    assert token in repository, token

prompt = read("lib/core/ai/prompt_builder.dart")
engine = read("lib/core/desire/proactive_engine.dart")
selection = read("lib/core/desire/proactive_selection_policy.dart")
appraisal = read("lib/core/autonomy/public_web_appraisal_policy.dart")
for token in (
    "freshTopicSourceOnly",
    "新话题来源隔离",
    "const <DailyContinuityRecord>[]",
    "freshnessBalanceBoost",
    "freshnessShortfall",
    "recentFreshCount",
    "recentVisibleCount",
    "fresh_source_promoted",
):
    assert token in prompt + engine + selection, token
assert "shareScore >= 0.74 && subjectiveValue >= 0.58" in appraisal
assert "('proactive_message','public_web_share')" in read(
    "lib/core/database/app_database.dart"
)

chat = read("lib/features/chat/chat_page.dart")
bridge = read("lib/core/platform/android_bridge.dart")
kotlin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
for stale in (
    "其他相册应用",
    "_ChatImageSource.externalGallery",
    "完整语义：${item.record.caption}",
):
    assert stale not in chat, stale
assert "pickExternalGalleryImage" not in bridge + kotlin
assert "item.record.caption" in chat

tests = read("test/simulated_diary_generator_v04152_test.dart") + read(
    "test/proactive_selection_policy_v0403_test.dart"
)
for token in (
    "quality gate rejects boilerplate",
    "factual fallback uses only organized continuity material",
    "fresh source is promoted when visible history is below half fresh",
    "balanced visible history does not force a weaker fresh source",
):
    assert token in tests, token

print("v0.41.52 diary and fresh-topic balance validation passed")
