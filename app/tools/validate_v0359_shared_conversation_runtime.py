#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
assert re.search(r"^version:\s*(?:0\.35\.9\+84|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112|0\.38\.14\+113|0\.38\.15\+114)\s*$", pubspec, re.M)

database = read("lib/core/database/app_database.dart")
for token in [
    "status IN ('pending','running','retry_wait','failed')",
    "Future<bool> interruptGenerationJob",
    "'status': 'interrupted'",
    "Future<List<GenerationInterruption>> recentGenerationInterruptions",
    "where: 'id = ? AND role = ?'",
    "await _rebuildSomaticAggregates",
]:
    assert token in database, token

model = read("lib/core/models/generation_job.dart")
assert "status == 'interrupted'" in model
assert "class GenerationInterruption" in model

runner = read("lib/core/ai/durable_generation_runner.dart")
catch_start = runner.index("} catch (e) {")
catch_block = runner[catch_start: runner.index("} finally {", catch_start)]
assert "interruptGenerationJob" in catch_block
assert "status: 'interrupted'" in catch_block
assert "failGenerationJob" not in catch_block

controller = read("lib/features/chat/chat_controller.dart")
for token in [
    "bool get generationActive => sending || externalGenerationActive",
    "Future<bool> syncExternalMessages()",
    "await db.blockingGenerationJob()",
    "await db.recentGenerationInterruptions(limit: 20)",
    "await _incrementOverlayUnread()",
    "(await db.failedGenerationNeedingAttention())?.id",
    "class ChatTimelineItem",
]:
    assert token in controller, token

page = read("lib/features/chat/chat_page.dart")
for token in [
    "Duration(milliseconds: 400)",
    "controller.timelineItems",
    "controller.generationActive",
    "const _InterruptionMarker()",
    "这一轮对话已中断",
]:
    assert token in page, token

server = read("lib/core/platform/background_chat_command_server.dart")
for token in [
    "Future<List<Map<String, Object?>>> _timelineRows",
    "'role': 'system_notice'",
    "'attachments': attachments",
    "thumbnail.path",
]:
    assert token in server, token

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
for token in [
    "val sharedSending = map[\"sending\"] == true",
    "setComposerGenerationState(sending = sharedSending)",
    "NativeAttachment(",
    "BitmapFactory.decodeFile(",
    "attachment.thumbnailPath",
    "message.role == \"system_notice\"",
    "formatDateSeparator(message.createdAt)",
    "AlphaAnimation(0.52f, 1f)",
    "if (ok && chatExpanded) setUnread(0)",
]:
    assert token in overlay, token

print("v0.35.9 shared conversation runtime validation passed")
