#!/usr/bin/env python3
"""Static contract for build 203 Tiandou recovery and independent pitch."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    missing = [token for token in tokens if token not in text]
    assert not missing, f"missing contract tokens: {missing}"


def main() -> None:
    require(read("pubspec.yaml"), "version: 0.41.59+203")
    require(
        read("lib/core/database/app_database.dart"),
        "static const int schemaVersion = 59;",
        "'tts_tone_preset': 'original'",
        "'tts_pitch_semitones': '0.0'",
        "if (oldVersion < 59)",
    )

    runtime = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt"
    )
    require(
        runtime,
        '"daily" to "ref01"',
        '"gentle" to "ref02"',
        '"lively" to "ref04"',
        '"cute" to "ref06"',
    )
    assert "naiyou_" not in runtime
    assert "sanitizeLegacyJapanese" not in runtime

    models = read(
        "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/BenchmarkModels.kt"
    )
    copier = read(
        "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/GenieBenchmarkEngine.kt"
    )
    integrity_policy = read(
        "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/AssetIntegrityPolicy.kt"
    )
    integrity_tests = read(
        "android/app/src/test/kotlin/com/catkiss62/geniettsbenchmark/AssetIntegrityPolicyTest.kt"
    )
    store = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieRuntimeAssetStore.kt"
    )
    require(models, "data class AssetIntegrity", 'root.optJSONObject("asset_integrity")')
    require(
        copier + integrity_policy,
        'output.name + ".incoming"',
        "expected.bytes",
        "expected.sha256",
        "StandardCopyOption.ATOMIC_MOVE",
        "fun sha256(file: File)",
    )
    require(
        integrity_tests,
        "correctLegacyFileIsHashedOnceAndMarkedReusable",
        "truncatedAndSameLengthWrongFilesAreRejected",
        "incomingWrongShaFailsBeforeReplacement",
        "verifiedIncomingAtomicallyReplacesOldFile",
    )
    require(store, "ai-companion-v04159-build203-tiandou-integrity-v1")

    tuning = read("lib/core/tts/tts_playback_tuning.dart")
    service = read("lib/core/tts/tts_service.dart")
    settings = read("lib/features/chat/chat_quick_settings_pages.dart")
    player = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
    )
    require(
        tuning,
        "TtsTonePreset",
        "高音版（原声）",
        "低音版",
        "lowPitchSemitones = -2.0",
        "minPitchSemitones = -4.0",
        "maxPitchSemitones = 4.0",
        "pitchRatioForSemitones",
    )
    require(
        service,
        "await provider.setSpeed(speed);",
        "await provider.setPitch(pitch);",
        "await provider.setVolume(volume);",
    )
    require(settings, "labelText: '恬豆音调'", "独立变调", "tts_pitch_semitones")
    require(
        player,
        "currentSpeed != 1.0f || currentPitch != 1.0f",
        ".setPitch(currentPitch)",
        ".setSpeed(currentSpeed)",
        "applyPlaybackParams",
    )
    assert "resampleForSpeed" not in player

    workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
        encoding="utf-8"
    )
    require(
        workflow,
        "genie-tts-private-runtime-v0.6.4",
        "Genie-TTS-v0.6.4-Verified.apk",
        "production_ids = {'ref01', 'ref02', 'ref04', 'ref06'}",
        "306_827_268",
        "manifest['asset_integrity']",
        "AI-Companion-v0.41.59-203-Tiandou-Pitch-Recovery-APK",
    )
    assert "assets/benchmark_naiyou/*" not in workflow
    print("v0.41.59 Tiandou integrity and independent-pitch contract passed")


if __name__ == "__main__":
    main()
