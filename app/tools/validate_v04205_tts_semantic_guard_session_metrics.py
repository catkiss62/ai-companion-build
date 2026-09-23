#!/usr/bin/env python3
"""Lock the v0.42.5 zero-token semantic guard and bounded TTS session report."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parent


def read(path: str) -> str:
    base = REPOSITORY if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    engine = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/GenieBenchmarkEngine.kt")
    selector = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/GeneratedSemanticTokens.kt")
    runtime = read("android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt")
    session = read("android/app/src/main/kotlin/com/aicompanion/localfirst/TtsSessionPerformance.kt")
    native = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt")
    bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt")
    queue = read("lib/core/tts/tts_playback_queue.dart")
    tts_service = read("lib/core/tts/tts_service.dart")
    probe = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativePreflightProbe.kt")
    selector_test = read("android/app/src/test/kotlin/com/catkiss62/geniettsbenchmark/GeneratedSemanticTokensTest.kt")
    session_test = read("android/app/src/test/kotlin/com/aicompanion/localfirst/TtsSessionPerformanceTest.kt")
    preflight_compile = read("tools/validate_preflight_kotlin_v27.py")
    self_reader_test = read("test/agent_self_reader_v0416_test.dart")
    workflow = read(".github/workflows/build-apk.yml")
    ledger = read("AI_Companion_当前总账.md")
    checklist = read("docs/TEST_CHECKLIST.md")

    require("version: 0.42.5+249" in read("pubspec.yaml"), "version mismatch")
    require(
        "GeneratedSemanticTokens.select(yValues, loopIndex)" in engine,
        "production decoder does not use the zero-token guard",
    )
    for forbidden in (
        "if (loopIndex == 0) yValues.size",
        "max(1, requested)",
        "copyOfRange(yValues.size - semanticCount",
    ):
        require(forbidden not in engine, f"reference-prefix fallback survived: {forbidden}")
    for token in (
        "if (generatedTokenCount <= 0)",
        "NoGeneratedSemanticTokensException",
        "stopped before generating semantic tokens",
    ):
        require(token in selector, f"semantic selector contract missing: {token}")
    require(
        "semantic_rejected_no_generated_tokens" in runtime
        and '"semanticCount" to 0' in runtime,
        "root rejection evidence is missing",
    )
    require("referenceEchoSuspected" in runtime, "secondary acoustic defense was removed")

    for token in (
        "MAX_SESSIONS = 2",
        "TtsSessionPerformance",
        "rejected_no_generated_semantics",
        "firstSegmentReadyMs",
        "firstPlaybackStartMs",
        "minimumEstimatedBufferMs",
        "lateSegmentCount",
        "aggregateRtf",
        "autoAffinitySpeedupPercent",
        "different_voice_or_language",
        "textSha256",
    ):
        require(token in session, f"session diagnostic contract missing: {token}")
    for forbidden in ("spokenText", "visibleText", "referenceText", "wavBytes"):
        require(forbidden not in session, f"plaintext/audio field leaked into snapshots: {forbidden}")
    require("beginTtsSession" in bridge and "finishTtsSession" in bridge,
            "native session boundaries are missing")
    require("recordSessionSegment" in native and "recordEnqueued" in native,
            "generation/playback metrics are not connected")
    require("service.beginSession(manual: manual)" in queue,
            "scheduler does not open an explicit session")
    require("await _ensureRuntimeProfile();" in tts_service,
            "session profile is captured before pending runtime settings apply")
    require("await service.finishSession()" in queue,
            "scheduler does not durably close a complete session")
    require('"ttsSessionDiagnostics" to TtsSessionDiagnosticStore.snapshot(context)' in probe,
            "exported preflight report omits the last-two snapshots")
    require("TtsSessionDiagnosticStore.kt" in preflight_compile,
            "legacy isolated preflight compilation does not stub the TTS session store")
    require("build=v0.42.5+249 schema=61" in self_reader_test,
            "Agent self-reader regression still expects the previous build identity")

    for token in (
        "first stage stop rejects every bundled voice prompt",
        "normal generation selects only emitted tail",
    ):
        require(token in selector_test, f"semantic regression test missing: {token}")
    for token in (
        "immediate stop is retained as rejected failed session",
        "same utterance compares native eight threads with auto affinity",
        "different utterances are never compared",
    ):
        require(token in session_test, f"session regression test missing: {token}")

    require("agent/v04205-tts-semantic-guard-session-metrics" in workflow,
            "workflow branch trigger missing")
    require("v0.42.5+249" in workflow, "workflow identity mismatch")
    require("v0.42.5+249" in ledger and "Decoder 首轮停止" in ledger,
            "ledger diagnosis/handoff missing")
    require("同一条回复" in checklist and "最后两次" in checklist,
            "device comparison checklist missing")
    require(
        "tools/validate_v04205_tts_semantic_guard_session_metrics.py"
        in read("tools/validation_suite.txt"),
        "validator is not registered",
    )

    print("v0.42.5 TTS semantic guard and session metrics contract passed")


if __name__ == "__main__":
    main()
