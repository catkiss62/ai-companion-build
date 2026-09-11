#!/usr/bin/env python3
"""Static contracts for build 207 TTS latency, semantics and routing hardening."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    missing = [token for token in tokens if token not in text]
    assert not missing, f"missing contract tokens: {missing}"


def main() -> None:
    require(read("pubspec.yaml"), "version: 0.41.63+207")
    require(
        read("lib/core/agent/agent_self_reader.dart"),
        "static const buildLabel = 'v0.41.63+207';",
    )

    settings = read("lib/features/settings/settings_category_pages.dart")
    require(
        settings,
        "if (!value.isGeminiRelay)",
        "_providerKillSwitchWrite =",
        "_secure.writeChatProvider(value);",
        "await _providerKillSwitchWrite;",
        "后续回复不会再调用 Gemini",
    )
    secure = read("lib/core/storage/secure_config.dart")
    require(
        secure,
        "Future<String?> readApiKey() => readDeepSeekApiKey();",
        "readFinalReplyApiKey",
        "readFinalReplyEndpoint",
    )
    proactive = read("lib/core/desire/proactive_engine.dart")
    require(proactive, "secureConfig.readApiKey()", "secureConfig.readEndpoint()")
    assert "readFinalReplyApiKey" not in proactive
    assert "readFinalReplyEndpoint" not in proactive

    queue = read("lib/core/tts/tts_playback_queue.dart")
    processor = read("lib/core/tts/tts_text_processor.dart")
    parser = read("lib/core/tts/tts_structured_stream_parser.dart")
    immersive = read("lib/core/immersive/immersive_room_controller.dart")
    require(
        queue,
        "addStructuredUnit",
        "TtsVoiceMode.gentle",
        "speedMultiplier: voice == TtsVoiceMode.gentle ? 1.2 : 1.0",
        "segmentIndex: index",
    )
    require(
        processor,
        "enum TtsSpeechRole { dialogue, narration }",
        "List<TtsPreparedUnit> processUnits",
        "? TtsSpeechRole.narration",
    )
    require(parser, "Only closed sentences/lines", "List<TtsPreparedUnit> finish()")
    require(
        immersive,
        "await _configureStreamingSpeech",
        "await _consumeStreamingSpeech(delta.content);",
        "await _finishStreamingSpeech();",
        "await _abortStreamingSpeech();",
        "language == ChatLanguage.chinese",
    )

    player = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
    )
    engine = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt"
    )
    checkpoint = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/TtsProcessCheckpoint.kt"
    )
    diagnostics = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt"
    )
    require(
        player,
        "val speed: Float",
        "playbackHeadFrames(writer) < framesWritten",
        "applyPlaybackParams(writer)",
    )
    require(
        engine,
        'phase = "generation_ready"',
        '"textSha256" to textHash',
        '"segmentIndex" to segmentIndex',
        '"phoneHash" to checkpoint["phoneHash"]',
        '"semanticHash" to checkpoint["semanticHash"]',
    )
    require(checkpoint, '"phoneCount"', '"semanticCount"', '"phoneHash"')
    require(diagnostics, '"textSha256"', '"segmentIndex"', '"semanticHash"')
    assert '"text" to text' not in engine

    more = read("lib/features/more/companion_more_page.dart")
    setting_hub = read("lib/features/settings/settings_page.dart")
    chat_page = read("lib/features/chat/chat_page.dart")
    require(more, "const SettingsDomainList()", "更多与全部设置")
    for title in (
        "模型与联网",
        "记忆与成长",
        "主动联系与感知",
        "语音与聊天呈现",
        "表情包",
        "设备与数据",
        "诊断与开发",
    ):
        assert title in setting_hub, title
    require(chat_page, "widget.onOpenMore?.call();", "唯一完整设置中心")
    v2 = chat_page[chat_page.index("Future<void> _openQuickPanelV2") :]
    for removed in ("title: '主动联系'", "title: '聊天画面'", "title: '语音与情绪'", "title: '文字演出'"):
        assert removed not in v2, removed

    require(
        read("test/settings_information_architecture_test.dart"),
        "seven responsibility domains",
        "'表情包'",
        "所有入口都使用同一份设置",
    )
    require(
        read("test/ui_information_architecture_v0360_test.dart"),
        "the unique More center exposes identity and settings domains",
        "'模型与联网'",
        "'诊断与开发'",
        "唯一完整设置中心",
    )
    require(
        read("test/agent_self_reader_v0416_test.dart"),
        "build=v0.41.63+207 schema=60",
    )

    print("v0.41.63 immersive TTS, diagnostics, settings and routing contracts passed")


if __name__ == "__main__":
    main()
