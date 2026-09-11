#!/usr/bin/env python3
"""Static contracts for the v0.41.55 pinned Genie port and lazy language flow."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


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

# These are byte-for-byte hashes from the user-verified v0.6.4 source commit
# 5380a536f83aeaec540a9aaa7982149969c73e26. Companion policy must stay outside.
core_hashes = {
    "BenchmarkModels.kt": "91009b6eb7f7b399bda5aa23d0f5590d4c1cb3de339b3005df92b3a8bc739390",
    "ChineseFrontend.kt": "4f2d9f675c0959a89f8e0de37c354eaac8e0562f68436c126b112db52f454179",
    "EnglishFrontend.kt": "f6fe3f78b809e443ee0e9e1daa3f7ede9a2fabf7d31f11f226e51130ce6986fa",
    "GenieSymbolsV2.kt": "4226d34e2866c99d2ddcc61ba60120d86aa549e626d7c03d478317ac9d59f77b",
    "NativeJapaneseFrontend.kt": "ffc05ea6e5457e6482cee617d77186448dcfe18899b8899bc5604fb08a34468c",
    "GenieBenchmarkEngine.kt": "a92bfc9f7c5b37d42076f4566f4c75f20a89d2e4b72efd50a09319e21bac47e1",
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
player = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
)
asset_store = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieRuntimeAssetStore.kt"
)

assert 'android:process=":genie_tts"' in manifest
assert 'android:extractNativeLibs="true"' in manifest
assert "aidl = true" in gradle
assert 'ndkVersion = "27.2.12479018"' in gradle
assert "isMinifyEnabled = false" in gradle
assert "isShrinkResources = false" in gradle
assert "GenieTtsRuntime(applicationContext)" in service
assert "private val lock = ReentrantLock(true)" in service
assert "Executors.newSingleThreadExecutor" in service
assert 'Thread(runnable, "Genie-TTS-worker")' in service
assert "worker.submit(Callable { lock.withLock(block) }).get()" in service
assert "generateToFile" in aidl and "byte[]" not in aidl
assert 'File(cacheDir, "genie-tts-ipc")' in service
assert "output.readBytes()" in native and "output.delete()" in native
assert "linkToDeath" in client and "child_process_exit" in client
assert "recordUnreadyStatus" in native
assert 'status["diagnosticCode"]' in native
assert 'phase = "generation_failed"' in native
assert "recordTtsClientFailure" in read("lib/core/platform/android_bridge.dart")
assert '"recordTtsClientFailure" ->' in read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
assert "TtsProcessCheckpoint" in service and "Debug.getPss()" in read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/TtsProcessCheckpoint.kt"
)
assert "HistoricalNativeTombstoneSanitizer.summarize" in read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
diagnostic_store = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt"
)
for token in ('"pssKb"', '"rssKb"', '"threads"', '"modelsReady"', '"language"'):
    assert token in diagnostic_store, token
assert "GenieFrontendAdapter.prepareChineseAssets" in runtime
assert "GenieFrontendAdapter.importRoberta" in runtime
assert "GenieRuntimeAssetStore.prepare" in runtime
assert "build204-jiuhu-v076-integrity-v1" in asset_store
assert "canonicalRoot.parentFile == canonicalBase" in asset_store
assert "canonicalCandidate.deleteRecursively()" in asset_store
assert "engine.prepareFrontendAssets(prepared, progress)" in asset_store
assert 'File(context.filesDir, "genie-benchmark")' in asset_store
assert '"genie-benchmark/shared/' in adapter
assert "DeepSeek" in adapter and "地铺西咳" in adapter
assert "service.generatePrepared(" in queue
for token in ("service.beginPlayback()", "service.enqueuePlayback(", "service.finishPlayback()"):
    assert token in queue, token
assert "interSentenceGap" not in queue
for token in (
    "fun beginStream(",
    "fun enqueueStream(",
    "fun finishStream()",
    "wav.sampleRate * bytesPerFrame",
    'Thread(::runWriter, "Genie-TTS-stream-player")',
    "PlaybackParams()",
    ".setPitch(currentPitch)",
    ".setSpeed(currentSpeed)",
    "LoudnessEnhancer(created.audioSessionId)",
    "2000.0 * log10(requested.toDouble())",
):
    assert token in player, token
assert "resampleForSpeed" not in runtime
assert "pcm16Wav(result.audio" in runtime
assert "volume = value.coerceIn(0.0, 2.0)" in native
assert "GenieFixedTextSegmenter.splitFirstImmediate(unit.text, language)" in queue
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
tuning = read("lib/core/tts/tts_playback_tuning.dart")
model = read("lib/core/ai/model_profile.dart")
model_settings = read("lib/features/settings/settings_category_pages.dart")
processor = read("lib/core/tts/tts_text_processor.dart")

assert "MultilingualReplyCodec" not in runner
assert "multilingual_replies_enabled" not in runner
assert "PromptBuilder.visibleChineseGenerationReminder()" in runner
assert "PromptBuilder.multilingualGenerationReminder()" not in runner
assert "import '../models/chat_language_variant.dart';" in runner
assert "<multilingual_reply>" not in prompt
assert "multilingualGenerationReminder" not in prompt
assert "thinking: false" in lazy
assert "source_segments" in lazy
assert "raw.length != source.length" in lazy
assert "MessageLanguageVariantDecoder.decode" in lazy
assert "ChatSegment(kind: source[index].kind, text: text)" in lazy
assert ".whenComplete(() {" in lazy
assert ".whenComplete(() => _inFlight.remove(key))" not in lazy
assert "upsertMessageLanguageVariant" in db
assert "conflictAlgorithm: ConflictAlgorithm.replace" in db
assert "languageVariantService.ensure" in controller
assert "latestSpeechLanguage != ChatLanguage.chinese" in controller
assert "ttsPlayback.beginStream" not in controller
assert "tts_streaming_enabled" not in controller
assert "languageVariantPreparing" in controller
assert "Widget _chatLanguageBar" not in chat
assert "Widget _topLanguageSelector" in chat
top_bar = chat[chat.index("Widget _topBar"):chat.index("Widget _composer")]
assert top_bar.index("_topLanguageSelector()") < top_bar.index("child: const Text('NSFW')")
assert "选择$languageName作为后续朗读语言" in chat
for stale in (
    "中文语音",
    "日语正文＋中文对照",
    "日语语音 · 显示中文翻译",
    "English 正文＋中文对照",
    "English 语音 · 显示中文翻译",
):
    assert stale not in chat, stale
assert "shouldFollowChatNotification" in chat
assert "停止生成语音" in chat
assert "生成三语版本" not in chat and "生成三语版本" not in voice_settings
assert "外语按需生成" in chat and "外语按需生成" in voice_settings
assert "不使用真流式测试模式" in voice_settings
assert "static const double maxVolume = 2.0;" in tuning
assert "static const double minSpeed = 0.5;" in tuning
assert "static const double maxSpeed = 2.0;" in tuning
assert "max: TtsPlaybackTuning.maxVolume" in voice_settings
assert "max: TtsPlaybackTuning.maxSpeed" in voice_settings
assert "low('low', 'Low')" in model
for token in (
    "keyboardType: TextInputType.text",
    "autofillHints: const <String>[]",
    "obscureText: false",
    "自定义模型名称（普通文本）",
):
    assert token in model_settings, token
assert "ReasoningEffort.low" in read("test/deepseek_temperature_test.dart")
assert "'地铺C咳'" in processor and "'拖肯'" in processor
assert "\\bYuki\\b" not in processor
assert "'{\"token\":\"拖肯\",\"DeepSeek\":\"地铺C咳\"}'" in db
assert "whereArgs: const ['tts_replacements_json', '{\"Yuki\":\"有希\"}']" in db

# The user's exported 05/06/07 groups and humor module are byte-locked in
# dedicated sources. The only differences from the backup rule rows are the
# separately requested removal of age-boundary wording.
user_rules = read("lib/core/rules/rule_layer_content_v04155_user_defaults.dart")
user_humor = read("lib/core/reference/world_book_content_v04155_user.dart")


def triple_const(source: str, name: str) -> str:
    match = re.search(
        rf"const\s+{re.escape(name)}\s*=\s*r?'''(.*?)''';",
        source,
        flags=re.S,
    )
    assert match is not None, name
    return match.group(1)


user_default_hashes = {
    "ruleContentV04155_04IntimacyCore":
        "547afce48773ffe8c159befeb8ecad17ecc4840d29fa25ddc482f9438ffc6d8c",
    "ruleContentV04155_05IntimacyRendering":
        "b30afa45447b14bb80aeccd0a851b114dbbaf0940575470a663db1729c898c99",
    "ruleContentV04155_06IntimacyReference":
        "844488e94b947cd8aaaad729ea6899a0550739c107e327f9ed7c739a69ba5e1f",
    "ruleContentV04155_ImmersiveGlobal":
        "6f215ca791794ca1337bed4c0bba8d3882f6402327e2640f15c85d64f86941ca",
    "ruleContentV04155_ImmersiveNsfwSource":
        "1685e3bc0567762e55d5c6bd07b39767b64af2d5f0af6d57477cb1c9a7d54c33",
}
for name, expected in user_default_hashes.items():
    body = triple_const(user_rules, name)
    assert sha256(body.encode()).hexdigest() == expected, name
    assert not re.search(
        r"未成年|成年人|成年男性|成年女性|幼态身体|年龄模糊|孩子|幼儿|\badult\b|\bminor\b",
        body,
        flags=re.I,
    ), name

user_humor_body = triple_const(user_humor, "worldBookHumorV04155User")
assert sha256(user_humor_body.encode()).hexdigest() == (
    "829c17a037400319c9c5519b71803d9dba38e438f27b6a7fa17bad7500aa4bb5"
)
assert not re.search(r"未成年|成年人|成年男性|成年女性|男孩子|幼儿|年龄", user_humor_body)
defaults = read("lib/core/rules/rule_layer_defaults.dart")
for token in (
    "ruleContentV04155_04IntimacyCore",
    "ruleContentV04155_05IntimacyRendering",
    "ruleContentV04155_06IntimacyReference",
    "ruleContentV04155_ImmersiveGlobal",
    "ruleContentV04155_ImmersiveNsfwSource",
    "legacyEditableRuleLayerSha256V04155UserDefaults",
    "Immersive Intimacy Reference",
):
    assert token in defaults, token
assert "...legacyEditableRuleLayerSha256V04155UserDefaults.entries" in db
assert "legacyEditableRuleLayerSha256V04155AgeBoundaryCleanup" in defaults
assert "...legacyEditableRuleLayerSha256V04155AgeBoundaryCleanup.entries" in db
special_styles = read("lib/core/rules/rule_layer_content_v0400.dart")
for token in ("孩子", "小女孩", "果冻般的少女"):
    assert token not in special_styles, token
world_book = read("lib/core/reference/world_book_presets.dart")
assert "content: worldBookHumorV04156User" in world_book
assert "probability: 30" in world_book
assert "worldbook_humor_user_default_v04155_applied" in db
posture_rules = read("lib/core/rules/rule_layer_content_v0353.dart")
younger_posture = triple_const(posture_rules, "ruleContentV0353_07_posture_younger")
assert not re.search(r"成年|未成年|孩子|幼儿|年龄", younger_posture)

immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
immersive_defaults = read("lib/core/rules/rule_layer_content_immersive.dart")
immersive_rendering = read("lib/widgets/action_tint_text.dart")
for token in (
    "对白统一用直角引号「」",
    "AI角色对白使用直角引号「」",
    "'「'.allMatches(trimmed).length",
    "'」'.allMatches(trimmed).length",
):
    assert token in immersive_prompt, token
assert "legacyImmersiveDefaultRoomNovelRulesV04155CurvedQuotes" in immersive_defaults
assert "AI角色说出口的对白使用直角引号「」" in immersive_defaults
assert "legacyImmersiveDefaultRoomNovelRulesV04155CurvedQuotes" in db
assert "isDialogue: trimmed.startsWith('「')" in immersive_rendering
assert "isDialogue: trimmed.startsWith('“')" not in immersive_rendering

# Scan every direct current prompt assembler. Versioned legacy bodies and
# import classifiers are intentionally excluded because they are never sent to
# the model; their old bytes remain available only for conservative migration.
runtime_prompt_sources = "\n".join(
    read(path)
    for path in (
        "lib/core/ai/prompt_builder.dart",
        "lib/core/ai/nsfw_context_router.dart",
        "lib/core/ai/memory_extractor.dart",
        "lib/core/immersive/immersive_prompt_builder.dart",
        "lib/core/immersive/immersive_nsfw_router.dart",
        "lib/core/rules/intimacy_prompt_sections.dart",
        "lib/core/reference/reference_library.dart",
        "lib/core/reference/world_book_presets.dart",
        "lib/core/memory/personality_learning_prompt_policy.dart",
        "lib/core/desire/proactive_presentation.dart",
    )
)
runtime_prompt_sources = runtime_prompt_sources.replace("改写成人设台词", "改写为人设台词")
assert not re.search(
    r"未成年|成年人|成年男性|成年女性|幼态身体|年龄模糊|成人(?!类|设)|\badult\b|\bminor\b",
    runtime_prompt_sources,
    flags=re.I,
)

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "Build AI Companion v0.41.60+204 APK",
        "agent/v04155-genie-direct-port-lazy-language",
    "validate_v04155_genie_direct_port_lazy_language.py",
    "AI-Companion-v0.41.60-204-Jiuhu-Four-Voice-Auto-Fix-APK",
    "genie-tts-private-runtime-v0.7.6-jiuhu",
):
    assert token in workflow, token
assert "companion ONNX Runtime differs from verified Genie APK" in workflow
assert workflow.count("lib/arm64-v8a/libgenie_frontend.so") >= 3
assert workflow.count("lib/arm64-v8a/libc++_shared.so") >= 3
assert "OpenJTalk ELF dependency closure is complete" in workflow
assert "ORG_GRADLE_PROJECT_skipGenieNativeBuild" in workflow
assert "libMNN.so" in workflow and "libbertvits2.so" in workflow
assert "LegacyTtsRuntime" not in service
assert "LegacyTtsRuntime" not in native

print("v0.41.55 pinned Genie direct-port and lazy-language contracts passed")
