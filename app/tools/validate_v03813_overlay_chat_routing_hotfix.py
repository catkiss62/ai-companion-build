from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
runner = read("lib/core/ai/durable_generation_runner.dart")
main_activity = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt"
)
system_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
bridge = read("lib/core/platform/android_bridge.dart")
app = read("lib/app.dart")
pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.14+113" in pubspec
assert "static const int schemaVersion = 33;" in database

# These are deliberately two different routes:
# 1. Pet/bubble menu “打开聊天” expands the native floating chat and keeps the
#    foreground third-party app visible.
# 2. Floating chat header “打开” launches the full Flutter app with a one-shot
#    destination that always selects the in-app chat tab.
assert 'onOpenChat = { showChatOverlay("pet_double_tap_menu") }' in overlay
assert 'onOpenChat = { openFullApp(openChat = true) }' not in overlay
assert 'smallButton("打开") { openFullApp(openChat = true) }' in overlay
assert 'putExtra(MainActivity.EXTRA_OPEN_CHAT, openChat)' in overlay

# Cold start and an existing singleTop Activity both carry the destination to
# Dart; consuming the extra prevents later ordinary resumes from reopening chat.
assert "EXTRA_OPEN_CHAT" in main_activity
assert "override fun onNewIntent" in main_activity
assert "setIntent(intent)" in main_activity
assert "bridge?.notifyOpenChatLaunch(intent)" in main_activity
assert '"consumeOpenChatLaunch"' in system_bridge
assert "removeExtra(MainActivity.EXTRA_OPEN_CHAT)" in system_bridge
assert 'methodChannel.invokeMethod("openChatLaunch", null)' in system_bridge
assert "consumeOpenChatLaunch" in bridge
assert "openChatLaunches" in bridge
assert "_openChatSubscription" in app
assert "setState(() => index = 1)" in app

# Native tool availability must not buffer every ordinary answer. Once any
# body text is visible, the guard keeps that exact answer; a legal tool-call
# preamble is also persisted with the post-tool answer instead of disappearing.
assert "emitDeltas: true," in runner
assert "emitDeltas: localPlan != null" not in runner
assert "if (!serviceGuard.allowed && visibleAnswerStreamed)" in runner
assert "action: 'stream_preserved'" in runner
assert "streamedToolPreamble" in runner
assert "finalContent = '$streamedToolPreamble\\n\\n$finalContent'.trim();" in runner

assert "python3 tools/validate_v03813_overlay_chat_routing_hotfix.py" in workflow
assert "grep -Fqx 'version: 0.38.14+113' app/pubspec.yaml" in workflow
assert "AI-Companion-v0.38.14-113-Reference-Unlock-Chat-Transcript-UI-APK" in workflow
assert "agent/v03814-unlock-chat-transcript-ui" in workflow

print("v0.38.13 streaming and overlay chat routing hotfix validated")
