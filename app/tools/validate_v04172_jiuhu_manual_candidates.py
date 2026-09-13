#!/usr/bin/env python3
"""Static contracts for the three +216 manual-only Jiuhu ASMR candidates."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith(".github/") or path.startswith("AI_") else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> str:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"
    return text


voice = require(
    "lib/core/tts/tts_voice_profile.dart",
    "softSpeech('soft_speech', '轻语')",
    "whisper('whisper', '耳语')",
    "breathy('breathy', '气声')",
)
assert voice.index("cute('cute', '可爱')") < voice.index("softSpeech('soft_speech', '轻语')")
assert voice.index("softSpeech('soft_speech', '轻语')") < voice.index("whisper('whisper', '耳语')")
assert voice.index("whisper('whisper', '耳语')") < voice.index("breathy('breathy', '气声')")
automatic = voice.split("static const Map<String, TtsVoiceMode> _automatic", 1)[1]
automatic = automatic.split("static TtsVoiceMode resolve", 1)[0]
for forbidden in ("softSpeech", "whisper", "breathy"):
    assert forbidden not in automatic, f"manual voice leaked into automatic routing: {forbidden}"

runtime = require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt",
    '"soft_speech" to "jiuhu_soft_speech"',
    '"whisper" to "jiuhu_whisper"',
    '"breathy" to "jiuhu_breathy"',
)
catalog = require(
    "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/VoiceProfileCatalog.kt",
    '"jiuhu_soft_speech", "soft_speech", "轻语", "仅供手动选择',
    '"jiuhu_whisper", "whisper", "耳语", "仅供手动选择',
    '"jiuhu_breathy", "breathy", "气声", "仅供手动选择',
)
assert catalog.index('"jiuhu_devotion"') < catalog.index('"jiuhu_soft_speech"')
assert catalog.index('"jiuhu_soft_speech"') < catalog.index('"jiuhu_whisper"')
assert catalog.index('"jiuhu_whisper"') < catalog.index('"jiuhu_breathy"')

require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieRuntimeAssetStore.kt",
    "ai-companion-v04172-build216-jiuhu-v077-seven-voices-v1",
)
require(
    "test/tts_genie_policy_test.dart",
    "three appended ASMR candidates stay manual-only",
    "TtsVoiceMode.values.sublist(5)",
)
workflow = require(
    ".github/workflows/build-apk.yml",
    "genie-tts-private-runtime-v0.7.7-jiuhu-seven",
    "Jiuhu-v0.7.7-seven-candidate-prompt-overlay.zip",
    "15126a2067b6da77af47b882fdd966e41ba84a38cc7eb6cbe274b38485cec0fd",
    "seven independent candidates",
    "'jiuhu_soft_speech'",
    "'jiuhu_whisper'",
    "'jiuhu_breathy'",
)
assert "unzip -q -o \".genie-payload/${JIUHU_OVERLAY}\"" in workflow
assert "models/t2s_shared_fp32.bin" in workflow
assert "models/vits_fp32.bin" in workflow

print("v0.41.72+216 Jiuhu three manual-only ASMR candidates validation passed.")
