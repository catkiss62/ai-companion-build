#!/usr/bin/env python3
"""Regression contract: +216 ASMR trials are retired again in +217."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith(".github/") else ROOT
    return (base / path).read_text(encoding="utf-8")


voice = read("lib/core/tts/tts_voice_profile.dart")
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt"
)
catalog = read(
    "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/VoiceProfileCatalog.kt"
)
store = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieRuntimeAssetStore.kt"
)
test = read("test/tts_genie_policy_test.dart")
workflow = read(".github/workflows/build-apk.yml")

for token in (
    "daily('daily', '日常')",
    "gentle('gentle', '温柔')",
    "lively('lively', '活泼')",
    "cute('cute', '可爱')",
):
    assert token in voice, token

for token in (
    '"daily" to "jiuhu_bento_tools"',
    '"gentle" to "jiuhu_dream_days"',
    '"lively" to "jiuhu_idle50"',
    '"cute" to "jiuhu_devotion"',
):
    assert token in runtime, token

for token in (
    '"jiuhu_bento_tools", "daily", "日常"',
    '"jiuhu_dream_days", "gentle", "温柔"',
    '"jiuhu_idle50", "lively", "活泼"',
    '"jiuhu_devotion", "cute", "可爱"',
):
    assert token in catalog, token

retired = (
    "jiuhu_soft_speech",
    "jiuhu_whisper",
    "jiuhu_breathy",
    "TtsVoiceMode.softSpeech",
    "TtsVoiceMode.whisper",
    "TtsVoiceMode.breathy",
)
for token in retired:
    assert token not in voice + runtime + catalog + workflow, token

assert "ai-companion-v04173-build217-jiuhu-four-voices-v1" in store
assert "TtsVoiceMode.fromSetting('soft_speech'), TtsVoiceMode.auto" in test
assert "TtsVoiceMode.fromSetting('whisper'), TtsVoiceMode.auto" in test
assert "TtsVoiceMode.fromSetting('breathy'), TtsVoiceMode.auto" in test
assert "Genie-TTS-Android-v0.7.6-Jiuhu-4-candidates-test.apk" in workflow
assert "Jiuhu-v0.7.7-seven-candidate-prompt-overlay.zip" not in workflow
assert "four independent voices" in workflow

print("v0.41.73+217 retired Jiuhu ASMR trials; four-voice regression passed.")
