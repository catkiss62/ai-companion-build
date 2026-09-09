#!/usr/bin/env python3
"""Static contracts for the v0.41.54 Genie hotfix/settings candidate."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def dart_block(source: str, name: str) -> str:
    match = re.search(rf"const {re.escape(name)} = (?:r)?'''(.*?)''';", source, re.S)
    assert match, name
    return match.group(1)


assert "version: 0.41.54+193" in read("pubspec.yaml")
assert "static const buildLabel = 'v0.41.54+193';" in read(
    "lib/core/agent/agent_self_reader.dart"
)

db = read("lib/core/database/app_database.dart")
rules = read("lib/core/rules/rule_layer_content_v04125.dart")
rule_defaults = read("lib/core/rules/rule_layer_defaults.dart")
presets = read("lib/core/reference/world_book_presets.dart")
reference = read("lib/core/reference/reference_library.dart")
model = read("lib/core/ai/model_profile.dart")
settings = read("lib/features/settings/settings_category_pages.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat = read("lib/features/chat/chat_page.dart")
voice_settings = read("lib/features/chat/chat_quick_settings_pages.dart")
background = read("lib/core/platform/background_chat_command_server.dart")
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt"
)
native = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt"
)
diagnostics = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt"
)
player = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
)
chinese = read(
    "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/ChineseFrontend.kt"
)
workflow = read("../.github/workflows/build-apk.yml")

# Backup-derived defaults are byte-exact, and untouched v0.41.53 Rule 01 rows
# have a narrow hash migration instead of an overwrite of user edits.
assert sha256(dart_block(rules, "ruleContentV04125_01_core").encode()).hexdigest() == (
    "10e970d1e392329545ecf727139d4988d369486827a333593876e3955429cfc7"
)
assert "c68c1520f04eedd4d37852a6c6cb8cc81a8491b2a2d1a44da0054581004107e4" in rule_defaults
assert sha256(dart_block(presets, "worldBookNaturalDialogueV04154").encode()).hexdigest() == (
    "3b9c9426fd05e087578bb2adb63edc32ae2ab23b88e44b8eeaa339a4f57475ea"
)
assert sha256(dart_block(presets, "worldBookPersonalitySpectrumV04154").encode()).hexdigest() == (
    "e7035045f0853b5e15eb610ed02441d86519e866443870e4b08a394319907dd2"
)
for name in ("角色表达自然化", "日常对话规则", "性格光谱", "造梗能力"):
    assert f"name: '{name}'" in presets
assert "id = ? OR (name = ? AND entry_type = ?)" in db

# Knowledge, behavior and roleplay have independent bounded 30k content lanes.
assert "const worldBookCategoryPromptLimit = 30000;" in reference
assert reference.count("worldBookCategoryPromptLimit") >= 5

# Unknown model ids survive load/save and the custom sentinel is never sent.
for token in (
    "static const custom",
    "'__custom__'",
    "isCustom: true",
    "return DeepSeekModelProfile._(",
):
    assert token in model, token
for token in (
    "_customDeepSeekModel",
    "自定义模型 ID",
    "effectiveModel.apiName",
    "请输入自定义 DeepSeek 模型 ID",
):
    assert token in settings, token

# Generation, display projection and spoken language are deliberately separate.
assert "getSetting('multilingual_replies_enabled')" in runner
assert "getSetting('show_foreign_replies')" not in runner
assert "streamTts = !multilingualEnabled" in controller
assert "final latestSpeechLanguage =" in controller
assert "getSetting('show_foreign_replies')" not in controller
for source in (db, chat, voice_settings):
    assert "multilingual_replies_enabled" in source
for token in (
    "生成三语版本",
    "显示外语正文",
    "日语语音 · 显示中文翻译",
    "English 语音 · 显示中文翻译",
    "if (latestAssistant != null)",
):
    assert token in chat, token
assert "if (!value) await _db.setSetting('tts_language', 'zh')" not in voice_settings
assert "final selected =\n              ChatLanguage.tryParse" in background

# Restore the verified v0.6.4 order: one frontend prepares first; only then are
# the four acoustic sessions loaded. A language switch unloads both old layers.
initialize_block = runtime[runtime.index("fun initialize("):runtime.index("fun prepareLanguage(")]
assert "loadModels" not in initialize_block
generate_block = runtime[runtime.index("fun generate("):runtime.index("private fun resampleForSpeed")]
assert generate_block.index('onStage("prepare_frontend_$language")') < generate_block.index(
    "engine.loadModels("
)
assert "engine.unloadModels()" in runtime
assert "val acousticModelsReady" in runtime
for stage in (
    "load_acoustic_models",
    "acoustic_models_ready",
    "infer_$language",
    "audio_playback",
):
    assert stage in runtime + native, stage
assert "durable: Boolean = false" in diagnostics
assert "if (durable) editor.commit() else editor.apply()" in diagnostics

# The playback worker exclusively releases AudioTrack; stop only interrupts it.
stop_block = player[player.index("fun stop()"):player.index("private fun parseWav")]
assert ".release()" not in stop_block
assert "next.release()" in player

# Case-insensitive special pronunciations include the requested neutral finals.
for token in (
    'word.equals("token", ignoreCase = true)',
    'word.equals("deepseek", ignoreCase = true)',
    'put("拖肯", listOf(longArrayOf(252L, 290L), longArrayOf(222L, 144L)))',
    'longArrayOf(245L, 259L)',
    'longArrayOf(222L, 134L)',
):
    assert token in chinese, token

# Build stays pinned to the already verified private v0.6.4 APK. No v0.7 true
# streaming payload or source is pulled into this baseline candidate.
for token in (
    "Build AI Companion v0.41.54+193 APK",
    "agent/v04154-genie-tts-hotfix-settings",
    "genie-tts-private-runtime-v0.6.4",
    "Genie-TTS-v0.6.4-Verified.apk",
    "AI-Companion-v0.41.54-193-Genie-TTS-Hotfix-Settings-APK",
):
    assert token in workflow, token
assert "genie-tts-private-runtime-v0.7" not in workflow

print("v0.41.54 Genie TTS hotfix and settings contracts passed")
