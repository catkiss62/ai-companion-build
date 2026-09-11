#!/usr/bin/env python3
"""Static contracts for build 204 Jiuhu voices and Gemini relay selection."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    missing = [token for token in tokens if token not in text]
    assert not missing, f"missing contract tokens: {missing}"


def main() -> None:
    require(read("pubspec.yaml"), "version: 0.41.61+205")
    require(
        read("lib/core/database/app_database.dart"),
        "static const int schemaVersion = 59;",
        "'tts_speed': '1.0'",
        "'tts_volume': '1.0'",
        "'tts_pitch_semitones': '0.0'",
    )

    runtime = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt"
    )
    catalog = read(
        "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/VoiceProfileCatalog.kt"
    )
    require(
        runtime,
        '"daily" to "jiuhu_bento_tools"',
        '"gentle" to "jiuhu_dream_days"',
        '"lively" to "jiuhu_idle50"',
        '"cute" to "jiuhu_devotion"',
    )
    require(
        catalog,
        '"jiuhu_bento_tools", "daily", "日常"',
        '"jiuhu_dream_days", "gentle", "温柔"',
        '"jiuhu_idle50", "lively", "活泼"',
        '"jiuhu_devotion", "cute", "可爱"',
    )
    for forbidden in ("naiyou_", '"daily" to "ref01"', '"cute" to "ref06"'):
        assert forbidden not in runtime + catalog, forbidden

    store = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieRuntimeAssetStore.kt"
    )
    require(
        store,
        "ai-companion-v04160-build204-jiuhu-v076-integrity-v1",
        'candidate.name == "shared"',
        "candidate.canonicalFile",
        "canonicalCandidate.deleteRecursively()",
    )

    tuning = read("lib/core/tts/tts_playback_tuning.dart")
    service = read("lib/core/tts/tts_service.dart")
    settings = read("lib/features/chat/chat_quick_settings_pages.dart")
    require(tuning, "pitchRatioForSemitones", "minPitchSemitones", "maxPitchSemitones")
    require(
        service,
        "last_tts_resolved_voice",
        "await provider.setSpeed(speed);",
        "await provider.setPitch(pitch);",
        "await provider.setVolume(volume);",
    )
    require(settings, "tts_pitch_semitones", "音调", "tts_speed", "tts_volume")
    assert "TtsTonePreset" not in tuning + service + settings
    assert "高音版（原声）" not in settings and "低音版" not in settings

    voice = read("lib/core/tts/tts_voice_profile.dart")
    require(
        voice,
        "'happy': TtsVoiceMode.lively",
        "'playful': TtsVoiceMode.cute",
        "'affection': TtsVoiceMode.gentle",
    )
    assert "confidence < 0.35" not in voice
    proactive = read("lib/core/desire/proactive_engine.dart")
    immersive = read("lib/core/immersive/immersive_room_controller.dart")
    require(proactive, "emotion: TtsEmotionCue(", "confidence: message.emotionConfidence")
    require(
        immersive,
        "_ttsEmotionCueFor",
        "EmotionClassifierService.instance.resolve",
        "emotion: emotion",
    )

    player = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
    )
    queue = read("lib/core/tts/tts_playback_queue.dart")
    queue_test = read("test/tts_playback_queue_test.dart")
    require(
        player,
        "AudioTrack.MODE_STREAM",
        "currentSpeed != 1.0f || currentPitch != 1.0f",
        ".setPitch(currentPitch)",
        ".setSpeed(currentSpeed)",
    )
    assert "resampleForSpeed" not in player
    assert "Thread.sleep(200" not in player
    require(
        queue,
        "unawaited(_generateAwaited",
        "await service.beginPlayback();",
        "await service.finishPlayback();",
    )
    require(
        queue_test,
        "A2 generates later sentences while the first sentence is playing",
        "expect(fake.playbackBeginCount, 1);",
        "expect(fake.playbackFinishCount, 1);",
    )

    provider = read("lib/core/ai/chat_api_provider.dart")
    secure = read("lib/core/storage/secure_config.dart")
    chat_client = read("lib/core/ai/deepseek_client.dart")
    model_settings = read("lib/features/settings/settings_category_pages.dart")
    provider_test = read("test/chat_api_provider_test.dart")
    require(
        provider,
        "https://api.shuaiapi.com/v1/chat/completions",
        "gemini-3.7-flash",
        "'thinking_level': thinking ? normalized.apiName : 'low'",
        "'include_thoughts': thinking",
        "'google'",
    )
    gemini_fields = provider.split("'google': <String, Object?>{", 1)[1]
    assert "'reasoning_effort'" not in gemini_fields
    assert "'extra_body':" not in provider
    require(
        secure,
        "chat_api_provider",
        "shuaiapi_gemini_api_key",
        "readDeepSeekApiKey",
        "readShuaiApiKey",
    )
    require(
        chat_client,
        "ChatApiProvider.fromEndpoint(endpoint)",
        "provider.effectiveModel(model)",
        "provider.thinkingRequestFields",
        "delta['reasoning_content']",
    )
    require(
        model_settings,
        "DeepSeek 与帅 API Gemini 二选一",
        "Gemini 正文与思考摘要均连接通过",
        "deepseek_model",
    )
    require(
        provider_test,
        "without DeepSeek fields",
        "body?.containsKey('thinking'), isFalse",
        "body?.containsKey('reasoning_effort'), isFalse",
        "'include_thoughts': true",
    )

    workflow = read("../.github/workflows/build-apk.yml")
    require(
        workflow,
        "Build AI Companion v0.41.60+204 APK",
        "agent/v04160-jiuhu-four-voice-auto-fix",
        "genie-tts-private-runtime-v0.7.6-jiuhu",
        "Genie-TTS-Android-v0.7.6-Jiuhu-4-candidates-test.apk",
        "af90aeaf84afdb383bd71584a5512609666c9af38110ea192ebde6f2c84ceb43",
        "FRONTEND_TAG='genie-tts-private-runtime-v0.6.4'",
        "FRONTEND_APK='Genie-TTS-v0.6.4-Verified.apk'",
        "FRONTEND_SHA='Genie-TTS-v0.6.4-Verified.apk.sha256'",
        "never extract its retired Tiandou benchmark",
        "'assets/benchmark_jiuhu/*'",
        "Keep the pinned Jiuhu ORT only as the post-build byte-identity",
        "unzip -q \".genie-payload/${FRONTEND_APK}\"",
        "'assets/openjtalk/*'",
        "expected_reference_inputs",
        "'ref_seq', 'ref_bert', 'ssl_content', 'ref_audio', 'ge', 'ge_advanced'",
        "expected_models",
        "models/t2s_shared_fp32.bin",
        "306827268",
        "07c40df473ddb08e259357ddf17173ffc3f82ce1a3e208cd1dd438f0dd01c445",
        "models/vits_fp32.bin",
        "175582720",
        "bfd6558dee03e06fafa2225d906f27e0f303395951d8cc4b8f2b26b3da2e99c2",
        "relative.startswith('models/') and relative not in expected_models",
        "prompt_signatures",
        "AI-Companion-v0.41.60-204-Jiuhu-Gemini-Relay-APK",
    )
    print("v0.41.60 Jiuhu, automatic-routing, streaming and Gemini relay contract passed")


if __name__ == "__main__":
    main()
