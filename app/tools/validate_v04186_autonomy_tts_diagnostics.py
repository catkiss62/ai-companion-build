#!/usr/bin/env python3
"""Cross-module gate for +230 solo-episode arbitration and TTS evidence."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"


require("pubspec.yaml", "version: 0.41.86+230")
require("lib/core/agent/agent_self_reader.dart", "v0.41.86+230")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.86'")
require(
    "lib/core/tts/tts_voice_profile.dart",
    "'happy': TtsVoiceMode.cute",
    "'excited': TtsVoiceMode.lively",
)
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/TtsDiagnosticEvidence.kt",
    "characterClasses",
    "pcmPayloadHash",
    "wavDurationMs",
    "referenceEchoSuspected",
)
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt",
    "referenceCaseId",
    "normalizedCharacterClasses",
    "validPhoneCount",
    "decoderIterations",
    "pcmDurationMs",
    "referenceEchoSuspected",
)
require(
    "lib/core/mcp/cedar_solo_episode_policy.dart",
    "stateChangeLimit = 3",
    "durationLimit = Duration(minutes: 25)",
    "class CedarAntiAddictionParser",
    "allowselfreset",
    "anti_addiction_locked",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "soloEpisodeKey",
    "resumeOptions",
    "resumeCheckpoint",
    "self_reset_not_authorized",
    "episode_checkpoint",
)
require(
    "lib/core/desire/proactive_engine.dart",
    "resume_game",
    "self_reset_and_resume",
    "cedarToyAutonomy.resumeOptions",
)
require(
    "lib/core/maintenance/recovery_orchestrator.dart",
    "episodeCheckpointDue",
    "anti_addiction_checkpoint",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "action == 'rest'",
    "successfulGap",
    "soloStepGap",
)
require(
    "test/cedar_solo_episode_v04186_test.dart",
    "three successful state changes create one resumable checkpoint",
    "structured anti-addiction lock carries permission and recovery time",
    "an ordinary game lock is not",
)
require(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/TtsDiagnosticEvidenceTest.kt",
    "characterClassesAreCountsOnlyAndCoverMixedInput",
    "echoSuspicionRequiresAllDegenerateInferenceSignals",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.86+230",
    "agent/v04186-autonomy-tts-diagnostics",
    "IMPLEMENTED LOCALLY",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04186-autonomy-tts-diagnostics",
    "AI-Companion-v0.41.86-230-Autonomy-TTS-Diagnostics-APK",
    "v0.41.86-autonomy-tts-diagnostics-test",
)
require("tools/validation_suite.txt", "validate_v04186_autonomy_tts_diagnostics.py")

print("v0.41.86+230 autonomy and TTS diagnostics validation passed.")
