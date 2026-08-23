#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
from struct import unpack

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat = read("lib/features/chat/chat_page.dart")
settings = read("lib/features/settings/settings_page.dart")
commands = read("lib/core/platform/background_chat_command_server.dart")
tint = read("lib/widgets/action_tint_text.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
android_bridge = read("lib/core/platform/android_bridge.dart")
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt"
)
system_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
background_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/BackgroundSystemBridge.kt"
)
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.37.6+95" in pubspec
assert "static const int schemaVersion = 30;" in database
assert "if (oldVersion < 30)" in database
assert "whereArgs: const ['chat_panel_opacity', '0.72']" in database
assert "whereArgs: const ['chat_typewriter_ms', '56']" in database
assert "'chat_panel_opacity': '0.60'" in database
assert "'chat_typewriter_ms': '48'" in database

for source in (runtime, system_bridge, background_bridge, android_bridge, database):
    assert "runtimeProcessEpoch" in source
assert "sameRuntime" in database
assert "expiresInMs" in database
assert "tokenIncluded': false" in database

resume_at = controller.index("Future<void> resumePendingGeneration()")
resume_end = controller.index("\n  Future<", resume_at + 20)
resume_body = controller[resume_at:resume_end]
assert "generationRecovery.recoverOne()" in resume_body
assert "generationRunner.run" not in resume_body
assert "正在结束上次中断的回复" in chat
assert "const Duration(seconds: 30)" in runner
assert "reasoning: delta.reasoning" in runner

assert "pushNamed('/settings')" in chat
assert "SettingsPage()" not in chat
assert "ttsStatus!" not in settings
assert "Text(status!" not in settings
assert "final currentTtsStatus = ttsStatus;" in settings

assert "_presentRecentMessages" in commands
assert "chat_last_presented_assistant_id" in commands
assert r"r'「[^」\n]*(?:」|$)'" in tint
assert "“[^”" not in tint
assert '\\"[^\\\"' not in overlay
assert '"「[^」\\n]*(?:」|$)"' in overlay

assert "emotionDiagnosticStats" in database
assert "localLeaseDiagnostic('chat_turn_lease')" in diagnostics
assert "'emotionObservability': emotionDiagnostics" in diagnostics
assert "'messageBodiesIncluded': false" in database
assert "'triggerMessageIdsIncluded': false" in database

launcher = (
    ROOT / "android/app/src/main/res/drawable-nodpi/companion_launcher_icon.png"
).read_bytes()
assert launcher.startswith(b"\x89PNG\r\n\x1a\n")
assert unpack(">II", launcher[16:24]) == (512, 512)
assert sha256(launcher).hexdigest() == (
    "b98622b8c305f5ef71e57432ad23ee2bc714bd7b61f138daf1b1d10d46157058"
)

assert "Build AI Companion v0.37.6+95 APK" in workflow
assert "AI-Companion-v0.37.6-95-Chat-Recovery-Presentation-APK.apk" in workflow
assert "schema advances to 30" in workflow
assert "validate_v0376_chat_recovery_presentation.py" in workflow

print("v0.37.6 chat recovery and presentation validation passed")
