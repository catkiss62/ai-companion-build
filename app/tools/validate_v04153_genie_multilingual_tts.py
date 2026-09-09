#!/usr/bin/env python3
"""Static contracts for v0.41.53 multilingual ordinary chat + Genie-TTS."""

from pathlib import Path
import re
import sqlite3
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


db = read("lib/core/database/app_database.dart")
message = read("lib/core/models/chat_message.dart")
variant = read("lib/core/models/chat_language_variant.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
self_reader = read("lib/core/agent/agent_self_reader.dart")
chat = read("lib/features/chat/chat_page.dart")
controller = read("lib/features/chat/chat_controller.dart")
background = read("lib/core/platform/background_chat_command_server.dart")
queue = read("lib/core/tts/tts_playback_queue.dart")
segmenter = read("lib/core/tts/tts_sentence_segmenter.dart")
voice = read("lib/core/tts/tts_voice_profile.dart")
processor = read("lib/core/tts/tts_text_processor.dart")
native = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt")
bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt")
runtime = read("android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt")
chinese = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/ChineseFrontend.kt")
audio_policy = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/SystemAudioPolicy.kt")
catalog = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/VoiceProfileCatalog.kt")
gradle = read("android/app/build.gradle.kts")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in read("pubspec.yaml")
    for version in ("version: 0.41.53+192", "version: 0.41.54+193")
)
assert "static const int schemaVersion = 57;" in db
assert any(
    label in self_reader
    for label in (
        "static const buildLabel = 'v0.41.53+192';",
        "static const buildLabel = 'v0.41.54+193';",
    )
)
for token in (
    "CREATE TABLE IF NOT EXISTS message_language_variants",
    "PRIMARY KEY(message_id, language)",
    "REFERENCES messages(id) ON DELETE CASCADE",
    "'message_language_variants'",
    "_insertLanguageVariants(txn, assistant)",
):
    assert token in db, token
for token in (
    "enum ChatLanguage",
    "chinese('zh', '中')",
    "japanese('ja', '日')",
    "english('en', 'EN')",
    "<multilingual_reply>",
    "A foreign version is valid only when every semantic segment exists",
):
    assert token in variant, token
assert "languageVariants" in message and "contentFor(ChatLanguage language)" in message
assert "multilingual_replies_enabled" in runner
assert "String visibleBody(EmotionEnvelopeData parsedEnvelope)" in runner
assert "MultilingualReplyCodec.tryParse" in runner
assert "MultilingualReplyCodec.streamingChinese" in runner
assert "三语协议修复 · ONE RETRY" in runner
assert "multilingualGenerationReminder" in prompt
assert "三种语言的段数、顺序和 kind 必须完全一致" in prompt
for token in (
    "_chatLanguageBar(latestAssistant)",
    "_LanguageSpeechButton",
    "_ForeignMessageProjection",
    "中文对照",
    "显示外语",
    "message.hasLanguage(language)",
    "正在准备$languageName",
):
    assert token in chat, token
assert "await ttsPlayback.stop();" in controller
assert "language: language" in controller

assert "maxSafeChunkChars = 54" in segmenter
assert "englishMaxSafeChunkChars = 110" in segmenter
assert "session.language" in queue and "session.voice" in queue
assert "service.resolveVoice(emotion)" in queue
assert "initialPrefill = const Duration(seconds: 1)" in queue
assert "if (_generation != stoppedAt) return;" in queue
assert "TtsAcousticSegmenter.split(prepared, session.language)" in queue
assert "streamTts = !multilingualEnabled" in controller
assert "message.contentFor(displayLanguage)" in background
assert "language: message.hasLanguage(selected)" in background
assert "中文对照" in background
for profile in ("daily", "gentle", "lively", "cute"):
    assert f"TtsVoiceMode.{profile}" in voice
assert "confidence < 0.35" in voice
assert "DeepSeek" in processor and "地铺 C 咳" in processor
assert "token" in processor and "拖肯" in processor
assert 'word.equals("deepseek", ignoreCase = true)' in chinese
assert 'output.append("地铺西咳")' in chinese

for token in (
    "Genie-TTS v0.6.4 · ONNX Runtime (local)",
    "runtime.prepareLanguage(next)",
    "SystemAudioPolicy.isSilentOrVibrate(appContext)",
):
    assert token in native, token
for token in (
    '"prepareLanguage"',
    '"importChineseRoberta"',
    'call.argument<String>("language")',
    'call.argument<String>("voice")',
):
    assert token in bridge, token
for token in (
    "EngineConfig(BackendMode.CPU, TARGET_THREADS)",
    "releaseFrontend()",
    '"daily" to "ref01"',
    '"gentle" to "ref02"',
    '"lively" to "ref04"',
    '"cute" to "ref06"',
):
    assert token in runtime, token
assert "ref07" not in runtime and "test_backup" not in runtime
assert "ref07" not in catalog and "test_backup" not in catalog
assert "RINGER_MODE_NORMAL" in audio_policy
assert "USAGE_MEDIA" in audio_policy and "CONTENT_TYPE_SPEECH" in audio_policy
assert 'onnxruntime-android:1.22.0' in gradle
assert "abiFilters.clear()" in gradle
assert 'abiFilters += "arm64-v8a"' in gradle
assert (ROOT / "android/app/src/main/assets/frontend/english/cmudict.rep.gz").is_file()

assert "Restore exact validated Genie TTS v0.6.4 runtime payload" in workflow
assert "genie-tts-private-runtime-v0.6.4" in workflow
assert "select(.draft and .tag_name" in workflow
assert "releases/assets/${GENIE_ASSET_ID}" in workflow
assert "libopenjtalk_native.so" in workflow
assert "production_ids = {'ref01', 'ref02', 'ref04', 'ref06'}" in workflow
assert "relative.startswith('models/')" in workflow
assert "models/t2s_shared_fp32.bin" in workflow
assert "models/vits_fp32.bin" in workflow
assert "manifest['presets'] = []" in workflow
assert "flutter build apk --release --target-platform android-arm64" in workflow
for forbidden in (
    "Restore exact validated Meju TTS runtime payload",
    "All 27 upgraded Meju TTS assets",
):
    assert forbidden not in workflow, forbidden

repo_root = ROOT.parent
tracked_paths = set(
    subprocess.check_output(
        ["git", "ls-files"], cwd=repo_root, text=True
    ).splitlines()
)
for private_path in (
    ROOT / "android/app/src/main/assets/benchmark",
    ROOT / "android/app/src/main/assets/openjtalk",
    ROOT / "android/app/src/main/jniLibs/arm64-v8a/libopenjtalk_native.so",
):
    relative = private_path.relative_to(repo_root).as_posix()
    assert not any(
        tracked == relative or tracked.startswith(f"{relative}/")
        for tracked in tracked_paths
    ), f"private/runtime payload leaked into tracked git files: {relative}"

ddl = re.search(
    r"CREATE TABLE IF NOT EXISTS message_language_variants \((.*?)\n\s*\)\n\s*'''\);",
    db,
    re.S,
)
assert ddl
connection = sqlite3.connect(":memory:")
connection.execute("PRAGMA foreign_keys = ON")
connection.execute("CREATE TABLE messages (id TEXT PRIMARY KEY)")
connection.execute(f"CREATE TABLE message_language_variants ({ddl.group(1)})")
connection.execute("INSERT INTO messages(id) VALUES ('m1')")
connection.execute(
    "INSERT INTO message_language_variants VALUES (?,?,?,?)",
    ("m1", "ja", "本文", "[]"),
)
try:
    connection.execute(
        "INSERT INTO message_language_variants VALUES (?,?,?,?)",
        ("m1", "zh", "错误", "[]"),
    )
    raise AssertionError("canonical Chinese was accepted as a foreign projection")
except sqlite3.IntegrityError:
    pass
connection.execute("DELETE FROM messages WHERE id = 'm1'")
assert connection.execute(
    "SELECT COUNT(*) FROM message_language_variants"
).fetchone()[0] == 0

print("v0.41.53 multilingual ordinary chat and Genie-TTS contracts passed")
