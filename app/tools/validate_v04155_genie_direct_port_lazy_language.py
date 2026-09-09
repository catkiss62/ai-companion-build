#!/usr/bin/env python3
"""Static contracts for the v0.41.55 pinned Genie port and lazy language flow."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


assert "version: 0.41.55+194" in read("pubspec.yaml")
assert "static const buildLabel = 'v0.41.55+194';" in read(
    "lib/core/agent/agent_self_reader.dart"
)

# These are byte-for-byte hashes from the user-verified v0.6.4 source commit
# 5380a536f83aeaec540a9aaa7982149969c73e26. Companion policy must stay outside.
core_hashes = {
    "BenchmarkModels.kt": "b6f3a414764cc6c7a5846c7eb7d7122d732573492b09a012bac35ddea0d8e178",
    "ChineseFrontend.kt": "4f2d9f675c0959a89f8e0de37c354eaac8e0562f68436c126b112db52f454179",
    "EnglishFrontend.kt": "f6fe3f78b809e443ee0e9e1daa3f7ede9a2fabf7d31f11f226e51130ce6986fa",
    "GenieSymbolsV2.kt": "4226d34e2866c99d2ddcc61ba60120d86aa549e626d7c03d478317ac9d59f77b",
    "NativeJapaneseFrontend.kt": "ffc05ea6e5457e6482cee617d77186448dcfe18899b8899bc5604fb08a34468c",
    "GenieBenchmarkEngine.kt": "6101a330e3b07e3d4e5ef4977ddb769a340008ef51ebdeab6227e2e1e8602f14",
    "SystemAudioPolicy.kt": "e8a2b56f04447b835a17826c0be0afa4080a43c148f786e6e6d1a6ef987cfbe0",
}
core_root = ROOT / "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark"
for name, expected in core_hashes.items():
    assert sha256((core_root / name).read_bytes()).hexdigest() == expected, name

adapter = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieFrontendAdapter.kt"
)
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt"
)
service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsIsolatedService.kt"
)
client = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/IsolatedGenieTtsClient.kt"
)
native = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt"
)
manifest = read("android/app/src/main/AndroidManifest.xml")
gradle = read("android/app/build.gradle.kts")
aidl = read(
    "android/app/src/main/aidl/com/aicompanion/localfirst/IGenieTtsIsolatedService.aidl"
)
queue = read("lib/core/tts/tts_playback_queue.dart")
fixed_segmenter = read("lib/core/tts/genie_fixed_text_segmenter.dart")

assert 'android:process=":genie_tts"' in manifest
assert 'android:extractNativeLibs="true"' in manifest
assert "aidl = true" in gradle
assert "GenieTtsRuntime(applicationContext)" in service
assert "private val lock = ReentrantLock(true)" in service
assert "generateToFile" in aidl and "byte[]" not in aidl
assert 'File(cacheDir, "genie-tts-ipc")' in service
assert "output.readBytes()" in native and "output.delete()" in native
assert "linkToDeath" in client and "child_process_exit" in client
assert "TtsProcessCheckpoint" in service and "Debug.getPss()" in read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/TtsProcessCheckpoint.kt"
)
assert "GenieFrontendAdapter.prepareChineseAssets" in runtime
assert "GenieFrontendAdapter.importRoberta" in runtime
assert "DeepSeek" in adapter and "地铺西咳" in adapter
assert "initialPrefill = const Duration(seconds: 1)" in queue
assert "service.generatePrepared(" in queue and "service.playPrepared(" in queue
assert "GenieFixedTextSegmenter.split(prepared, language)" in queue
for token in ("targetChars: english ? 88 : 42", "maxChars: english ? 110 : 54"):
    assert token in fixed_segmenter, token

# No permanent multilingual envelope remains on the ordinary generation path.
runner = read("lib/core/ai/durable_generation_runner.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
lazy = read("lib/core/ai/message_language_variant_service.dart")
db = read("lib/core/database/app_database.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat = read("lib/features/chat/chat_page.dart")
voice_settings = read("lib/features/chat/chat_quick_settings_pages.dart")

assert "MultilingualReplyCodec" not in runner
assert "multilingual_replies_enabled" not in runner
assert "PromptBuilder.visibleChineseGenerationReminder()" in runner
assert "PromptBuilder.multilingualGenerationReminder()" not in runner
assert "<multilingual_reply>" not in prompt
assert "multilingualGenerationReminder" not in prompt
assert "thinking: false" in lazy
assert "source_segments" in lazy
assert "raw.length != source.length" in lazy
assert "item['kind']?.toString() != source[index].kind.key" in lazy
assert "upsertMessageLanguageVariant" in db
assert "conflictAlgorithm: ConflictAlgorithm.replace" in db
assert "languageVariantService.ensure" in controller
assert "latestSpeechLanguage != ChatLanguage.chinese" in controller
assert "ttsPlayback.beginStream" not in controller
assert "tts_streaming_enabled" not in controller
assert "languageVariantPreparing" in controller
assert "latestAssistant.content.trim().isNotEmpty" in chat
assert "生成三语版本" not in chat and "生成三语版本" not in voice_settings
assert "外语按需生成" in chat and "外语按需生成" in voice_settings
assert "不使用真流式测试模式" in voice_settings

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "Build AI Companion v0.41.55+194 APK",
    "agent/v04155-genie-direct-port-lazy-language",
    "validate_v04155_genie_direct_port_lazy_language.py",
    "AI-Companion-v0.41.55-194-Genie-Direct-Port-Lazy-Language-APK",
    "genie-tts-private-runtime-v0.6.4",
):
    assert token in workflow, token
assert "genie-tts-private-runtime-v0.7" not in workflow

print("v0.41.55 pinned Genie direct-port and lazy-language contracts passed")
