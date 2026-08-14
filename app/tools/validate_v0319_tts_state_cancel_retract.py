#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
assert match, "missing app version"
assert tuple(map(int, match.groups())) >= (0, 31, 9, 51)

database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 20;" in database
cancel_start = database.index("Future<bool> cancelGenerationJobByUser")
cancel_end = database.index("Future<bool> isGenerationRunCurrent", cancel_start)
cancel = database[cancel_start:cancel_end]
for token in [
    "db.transaction<bool>",
    "status IN ('pending','running','retry_wait')",
    "'status': 'cancelled_by_user'",
    "where: 'id = ? AND role = ?'",
    "whereArgs: [userMessageId, 'user']",
]:
    assert token in cancel, token

queue = read("lib/core/tts/tts_playback_queue.dart")
for token in [
    "enum TtsPlaybackPhase { idle, synthesizing, playing }",
    "final TtsPlaybackPhase phase",
    "final String? ownerId",
    "session.playing",
    "ownerId: session.ownerId",
]:
    assert token in queue, token

controller = read("lib/features/chat/chat_controller.dart")
for token in [
    "ownerId: job.assistantMessageId",
    "ownerId: result.assistant!.id",
    "ownerId: message.id",
    "activeGenerationTtsPhase",
    "messages = await db.recentMessages(limit: 120)",
]:
    assert token in controller, token

page = read("lib/features/chat/chat_page.dart")
for token in [
    "Icons.volume_up_outlined",
    "TtsPlaybackPhase.synthesizing",
    "TtsPlaybackPhase.playing",
    "'…'",
    "'■'",
]:
    assert token in page, token
assert "Icons.stop_circle_outlined" not in page

server = read("lib/core/platform/background_chat_command_server.dart")
assert "case 'ttsSnapshot':" in server
assert "state?.phase.name" in server
assert "state?.ownerId" in server

overlay = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
for token in [
    '"ttsSnapshot"',
    'TTS_POLL_MS = 160L',
    'R.drawable.ic_volume_up_outlined',
    '"synthesizing" ->',
    'text = "…"',
    'text = "■"',
]:
    assert token in overlay, token
assert 'smallButton("停语音")' not in overlay
assert (ROOT / "android/app/src/main/res/drawable/ic_volume_up_outlined.xml").is_file()

tests = read("test/tts_playback_queue_test.dart")
assert "reports synthesizing, playing, and idle" in tests
assert "auto streaming announces synthesis" in tests

print("v0.31.9 TTS state and cancelled-turn withdrawal validation passed")
