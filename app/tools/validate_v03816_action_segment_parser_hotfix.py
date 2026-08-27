from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


segment = read("lib/core/models/chat_segment.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
chat = read("lib/features/chat/chat_page.dart")
text = read("lib/widgets/action_tint_text.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
tests = read("test/chat_visuals_test.dart")
database = read("lib/core/database/app_database.dart")
pubspec = read("pubspec.yaml")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.16+115" in pubspec
assert "static const int schemaVersion = 33;" in database

# The parser must skip the required visual blank line before deciding whether
# a bracketless source line is the action paired with the quoted dialogue.
assert "while (nextContentIndex < lines.length" in segment
assert "lines[nextContentIndex].trim().isEmpty" in segment
assert "final nextContentIsDialogue" in segment
assert "kind: nextContentIsDialogue || looksLikeLegacyAction" in segment

# Existing v0.38.15 rows stored segments_json as derived dialogue segments.
# Loading them must self-heal from the authoritative raw message content.
assert "final reparsed = parseAssistantText(fallbackText);" in segment
assert "if (reparsedActionCount > storedActionCount) return reparsed;" in segment
assert "blank line between action and dialogue keeps action semantics" in tests
assert "stored v03815 dialogue misclassification self-heals from source" in tests
assert "blank-line ordinary prose without quoted dialogue stays dialogue" in tests
assert "她把耳鳍往后压了压，尾尖停在半空。" in tests

# The repair must retain the approved v0.38.13-v0.38.15 presentation and
# routing behavior instead of replacing it with another rendering path.
assert ".join('\\n\\n')" in visuals
assert "assistantStreamingTranscriptBlocks(content)" in chat
assert "const chatDialogueGold = Color(0xFFFDE68A);" in text
assert "fontStyle: FontStyle.italic" in text
assert "emitDeltas: false," in runner
assert "showGenerationDraft" in chat
assert 'onOpenChat = { showChatOverlay("pet_double_tap_menu") }' in overlay
assert 'smallButton("打开") { openFullApp(openChat = true) }' in overlay
assert "double _panelOpacity = 0.75;" in chat
assert "horizontal: 14" in chat and "vertical: 11" in chat

assert "python3 tools/validate_v03816_action_segment_parser_hotfix.py" in workflow
assert "grep -Fqx 'version: 0.38.16+115' app/pubspec.yaml" in workflow
assert "AI-Companion-v0.38.16-115-Action-Segment-Parser-Hotfix-APK" in workflow
assert "agent/v03816-action-segment-parser-hotfix" in workflow

print("v0.38.16 action segment parser hotfix validated")
