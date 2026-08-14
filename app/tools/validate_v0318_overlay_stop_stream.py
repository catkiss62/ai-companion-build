#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
assert match, "missing app version"
assert tuple(map(int, match.groups())) >= (0, 31, 8, 50)

database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 20;" in database

server = read("lib/core/platform/background_chat_command_server.dart")
for token in [
    "overlay_generation_snapshot.dart",
    "case 'generationSnapshot':",
    "case 'cancelGeneration':",
    "await controller.cancelCurrentGeneration()",
    "_overlaySendEpoch",
    "streamingReasoning",
    "streamingContent",
]:
    assert token in server, token

snapshot = read("lib/core/platform/overlay_generation_snapshot.dart")
for token in [
    "class OverlayGenerationSnapshot",
    "'cancelling'",
    "'thinking'",
    "'answering'",
    "'idle'",
    "'reasoning': reasoning",
    "'content': content",
]:
    assert token in snapshot, token

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
for token in [
    'if (chatSending) cancelGenerationFromOverlay() else sendFromOverlay()',
    'private fun cancelGenerationFromOverlay()',
    '"cancelGeneration"',
    '"generationSnapshot"',
    'beginGenerationPolling()',
    'GENERATION_POLL_MS = 140L',
    'STREAMING_MESSAGE_ID = "overlay:streaming"',
    'map["reasoning"] as? String',
    'map["content"] as? String',
    'if (live) "🧠 思考中" else "🧠 思考"',
    'smallButton("停语音") { stopSpeech() }',
]:
    assert token in overlay, token

# The nearby stop action must stay generation-aware instead of disabling the
# only reachable button. The header control remains explicitly speech-only.
send_start = overlay.index("private fun sendFromOverlay()")
send_end = overlay.index("private fun cancelGenerationFromOverlay()", send_start)
send_block = overlay[send_start:send_end]
assert "chatSend?.isEnabled = false" not in send_block
assert "setComposerGenerationState(sending = true)" in send_block

test = read("test/overlay_generation_snapshot_test.dart")
assert "without inventing text" in test
assert "正在比较两种回答方式" in test

print("v0.31.8 overlay stop and live stream validation passed")
