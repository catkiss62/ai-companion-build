#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), f"{path} is empty"
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
contract = read("lib/core/emotion/emotion_contract.dart")
classifier = read("lib/core/emotion/emotion_classifier_service.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
tests = read("test/emotion_contract_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in ("version: 0.38.0+99", "version: 0.38.1+100")
)
assert "static const int schemaVersion = 32;" in database
assert "schemaVersion = 33" not in database

for token in (
    "enum EmotionEnvelopeStatus",
    "EmotionEnvelopeStatus.canonical",
    "EmotionEnvelopeStatus.recovered",
    "EmotionEnvelopeStatus.missing",
    "EmotionEnvelopeStatus.empty",
    "EmotionEnvelopeStatus.invalid",
    "EmotionEnvelopeStatus.malformed",
    "_recoverableXmlFirstLine",
    "_recoverableNamedFirstLine",
    "_malformedFirstLine",
    "_complete.allMatches(raw)",
    "_stripReservedMarkup(raw)",
):
    assert token in contract, token

for token in (
    "class EmotionSource",
    "heuristic_missing_tag",
    "heuristic_empty_tag",
    "heuristic_invalid_tag",
    "heuristic_malformed_tag",
    "diagnosticStatus",
):
    assert token in contract, token

for token in (
    "_cuesByKey",
    "_containsNonNegated",
    "bounded Chinese cue scorer",
    "EmotionSource.llmRecovered",
    "EmotionSource.fallbackMissing",
    "EmotionSource.fallbackInvalid",
    "top3",
):
    assert token in classifier, token
for forbidden in ("MethodChannel", "_classifyOnAndroid", "source: '19emo'", "Random("):
    assert forbidden not in classifier + contract, forbidden

assert "envelopeStatus: envelope.status" in runner
assert "envelopeStatus: emotionEnvelope.status" in proactive
assert "不得只写进 reasoning/思考" in prompt

for token in (
    "emotionParseStatusCounts",
    "emotion_parse_status",
    "EmotionSource.diagnosticStatus",
    "'rawEmotionTagsIncluded': false",
):
    assert token in database, token
assert "emotion_raw_tag" not in database[database.index("Future<Map<String, Object?>> emotionDiagnosticStats"):database.index("Future<int> expireEmotionEpisodes")]

for title in (
    "safe first-line variants recover without leaking machine metadata",
    "ordinary visible emotion wording is never mistaken for metadata",
    "malformed explicit first line is hidden without losing its body",
    "invalid envelope falls back but never leaks into body",
    "missing tags use deterministic 19-label cue scoring",
    "negated cues do not manufacture an emotion",
    "source diagnostics expose categories without raw tags",
):
    assert title in tests, title
assert "expect(cases, hasLength(19))" in tests

for token in (
    "validate_v0380_emotion_fallback_recovery.py",
    ".ci/v0380-monitor.txt",
):
    assert token in workflow, token
for alternatives in (
    (
        "Build AI Companion v0.38.0+99 APK (19 Emotion Recovery)",
        "Build AI Companion v0.38.1+100 APK (Adult Relationship Capability)",
    ),
    (
        "AI-Companion-v0.38.0-99-19-Emotion-Recovery-APK.apk",
        "AI-Companion-v0.38.1-100-Adult-Relationship-Capability-APK.apk",
    ),
    (
        "v0.38.0-emotion-recovery-test",
        "v0.38.1-adult-relationship-capability-test",
    ),
):
    assert any(token in workflow for token in alternatives), alternatives

print("v0.38.0 19 Emotion envelope, deterministic fallback and redacted diagnostics validation passed")
