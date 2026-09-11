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
    assert any(
        version in read("pubspec.yaml")
        for version in ("version: 0.41.65+209", "version: 0.41.66+210")
    )
    assert any(
        label in read("lib/core/agent/agent_self_reader.dart")
        for label in (
            "static const buildLabel = 'v0.41.65+209';",
            "static const buildLabel = 'v0.41.66+210';",
        )
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
    require(more, "功能分类")
    assert any(
        label in more
        for label in (
            "AI Companion · v0.41.65+209",
            "AI Companion · v0.41.66+210",
        )
    )
    for title in ("她", "你们", "能力", "手机感知", "数据与高级"):
        assert title in more, title
    assert "SettingsDomainList" not in more
    for title in (
        "模型与联网",
        "记忆与成长",
        "主动联系与感知",
        "语音与聊天呈现",
        "设备与数据",
        "诊断与开发",
    ):
        assert title in setting_hub, title
    require(
        setting_hub,
        "常用聊天选项也保留在头像侧栏；两处使用同一份设置，不会互相覆盖。",
    )
    require(chat_page, "widget.onOpenMore?.call();")
    v2 = chat_page[chat_page.index("Future<void> _openQuickPanelV2") :]
    for shortcut in (
        "title: '主动联系'",
        "title: '聊天画面'",
        "title: '语音与情绪'",
        "title: '文字演出'",
    ):
        assert shortcut in v2, shortcut
    require(v2, "subtitle: '浏览全部功能分类。'")

    require(
        read("test/settings_information_architecture_test.dart"),
        "six responsibility domains",
        "两处使用同一份设置",
    )
    require(
        read("test/ui_information_architecture_v0360_test.dart"),
        "five stable domains are visible without placeholder features",
        "'能力'",
        "'数据与高级'",
    )
    self_reader_test = read("test/agent_self_reader_v0416_test.dart")
    assert any(
        fact in self_reader_test
        for fact in (
            "build=v0.41.65+209 schema=60",
            "build=v0.41.66+210 schema=61",
        )
    )

    print("v0.41.63 immersive TTS, diagnostics, settings and routing contracts passed")


if __name__ == "__main__":
    main()
