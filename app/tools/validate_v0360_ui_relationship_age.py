#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


assert re.search(r"^version:\s*(?:0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112|0\.38\.14\+113|0\.38\.15\+114|0\.38\.16\+115|0\.38\.18\+117|0\.39\.0\+118|0\.39\.1\+119|0\.39\.2\+120|0\.39\.3\+121|0\.39\.4\+122|0\.39\.5\+123|0\.39\.6\+124|0\.39\.7\+125|0\.39\.8\+126|0\.39\.9\+127|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132)|0\.40\.4\+133)\s*$", read("pubspec.yaml"), re.M)

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
