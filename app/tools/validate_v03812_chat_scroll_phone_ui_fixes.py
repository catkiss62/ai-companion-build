from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


page = read("lib/features/phone/simulated_phone_page.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
chat = read("lib/features/chat/chat_page.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
bridge = read("lib/core/platform/android_bridge.dart")
app = read("lib/app.dart")
main_activity = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt"
)
system_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.12+111" in pubspec
assert "static const int schemaVersion = 33;" in database

# The real-device home layout moves row one down while leaving row two nearly
# fixed, and the mood chart retains enough vertical range for a seven-day line.
assert "const SizedBox(height: 34)" in page
assert "mainAxisSpacing: 10" in page
if "version: 0.41.17+156" in pubspec:
    assert "MoodChartLayout.build" in page and "const chartHeight = 224.0" in page
else:
    assert "? 184.0" in page and "? 204.0" in page and ": 224.0" in page

# Cart list and expansion deliberately show the same reason again.
assert "entry.metadata['list_summary']" not in page
assert "entry.metadata['list_summary']" not in repository
assert page.count("entry.body,") >= 5

# Follow mode is changed only by a real user scroll. During answer streaming it
# anchors to the visible body-tail marker rather than a stale ListView extent.
assert "NotificationListener<UserScrollNotification>" in chat
assert "package:flutter/rendering.dart' show ScrollDirection" in chat
assert "_onUserScroll" in chat
assert "_anchorStreamingBody" in chat
assert "_streamingBodyTailKey" in chat
assert "Scrollable.ensureVisible(" in chat
assert "scroll.addListener(_onScrollChanged)" not in chat
assert "duration: Duration.zero" in chat

# The later single-playback contract retains the reasoning de-duplication while
# keeping the ordinary visible body buffered until durable commit.
early_publish = "if (localPlan == null && generated.toolCalls.isEmpty)"
assert early_publish not in runner
assert "emitDeltas: false," in runner
assert "visibleAnswerStreamed" not in runner
assert "onDelta?.call(DeepSeekDelta(content: finalContent))" not in runner
visible_reasoning = runner.index(
    "final visibleReasoning = preserveProviderReasoning(generated.reasoning);"
)
assistant = runner.index("final assistant = ChatMessage(", visible_reasoning)
assert "onDelta?.call(DeepSeekDelta(reasoning:" not in runner[
    visible_reasoning:assistant
]

# The overlay chat header requests the full app's chat tab. The pet menu's
# separate “打开聊天” contract is checked by the v0.38.13 follow-up.
assert 'putExtra(MainActivity.EXTRA_OPEN_CHAT, openChat)' in overlay
assert 'smallButton("打开") { openFullApp(openChat = true) }' in overlay
assert "EXTRA_OPEN_CHAT" in main_activity
assert "override fun onNewIntent" in main_activity
assert '"consumeOpenChatLaunch"' in system_bridge
assert 'methodChannel.invokeMethod("openChatLaunch", null)' in system_bridge
assert "consumeOpenChatLaunch" in bridge
assert "openChatLaunches" in bridge
assert "setState(() => index = 1)" in app

assert "python3 tools/validate_v03812_chat_scroll_phone_ui_fixes.py" in workflow
assert "grep -Fqx 'version: 0.38.16+115' app/pubspec.yaml" in workflow
assert "AI-Companion-v0.38.16-115-Action-Segment-Parser-Hotfix-APK" in workflow
assert "agent/v03816-action-segment-parser-hotfix" in workflow

print("v0.38.12 chat scroll and phone UI fixes validated")
