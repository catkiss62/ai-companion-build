#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


assert re.search(r"^version:\s*0\.36\.0\+85\s*$", read("pubspec.yaml"), re.M)

app = read("lib/app.dart")
more = read("lib/features/more/companion_more_page.dart")
memory = read("lib/features/memory/memory_page.dart")
database = read("lib/core/database/app_database.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
chat = read("lib/features/chat/chat_page.dart")
action = read("lib/widgets/action_tint_text.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)

for route in (
    "/companion",
    "/relationship",
    "/capabilities",
    "/perception",
    "/data-advanced",
):
    assert route in app and route in more, route
for label in ("她", "你们", "能力", "手机感知", "数据与高级"):
    assert label in more, label
assert "认识第 ${relationshipAge!.dayNumber} 天" in memory
assert "relationship_started_at" in database
assert "SELECT MIN(created_at) AS first_at FROM messages" in database
assert "今天是认识第 ${age.dayNumber} 天" in prompt
assert "不得仅凭亲密语气" in prompt
assert "ActionTintText" in chat and "splitActionText" in action
assert "SpannableString" in overlay and "actionTintedText" in overlay
assert "overlaySubmitCommandPending" in overlay
assert "sharedSending || overlaySubmitCommandPending" in overlay

print("v0.36.0 UI domains, relationship age, action tint and overlay Stop validation passed")
