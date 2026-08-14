#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
assert match, "missing app version"
assert tuple(map(int, match.groups())) >= (0, 31, 7, 49)

token = read("lib/core/ai/generation_cancellation.dart")
assert "class GenerationCancellationToken" in token
assert "GenerationCancelledByUserException" in token
assert "whenCancelled" in token and "throwIfCancelled" in token

client = read("lib/core/ai/deepseek_client.dart")
assert "streamClientFactory" in client
assert "cancellationToken.whenCancelled" in client
assert "streamClient.close()" in client
assert "GenerationCancelledByUserException" in client

database = read("lib/core/database/app_database.dart")
assert "Future<bool> cancelGenerationJobByUser" in database
assert "'status': 'cancelled_by_user'" in database
assert "'run_token': ''" in database
assert "status IN ('pending','running','retry_wait')" in database
assert "Future<bool> isGenerationRunCurrent" in database

runner = read("lib/core/ai/durable_generation_runner.dart")
assert "GenerationCancellationToken? cancellationToken" in runner
assert "cancellationToken: cancellationToken" in runner
assert "isGenerationRunCurrent" in runner
assert "status: 'cancelled_by_user'" in runner
assert "cancellationToken?.throwIfCancelled()" in runner

controller = read("lib/features/chat/chat_controller.dart")
assert "Future<void> cancelCurrentGeneration()" in controller
assert "_activeGenerationCancellation" in controller
assert "token?.cancel()" in controller
assert "await ttsPlayback.stop()" in controller
assert "await db.cancelGenerationJobByUser(jobId)" in controller
assert "_recoveryScheduleEpoch++" in controller

page = read("lib/features/chat/chat_page.dart")
assert "controller.cancelCurrentGeneration" in page
assert "Icons.stop_rounded" in page
assert "停止这轮回复" in page

model = read("lib/core/models/generation_job.dart")
assert "status == 'cancelled_by_user'" in model

print("v0.31.7 true stop generation validation passed")
