from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


chat = read("lib/features/chat/chat_page.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
text = read("lib/widgets/action_tint_text.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
rule_defaults = read("lib/core/rules/rule_layer_defaults.dart")
database = read("lib/core/database/app_database.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
phone = read("lib/features/phone/simulated_phone_page.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
overlay_formatter = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
pubspec = read("pubspec.yaml")
aggressive_dialogue = "version: 0.41.22+161" in pubspec
lifelike_ablation = any(version in pubspec for version in (
    "version: 0.41.23+162", "version: 0.41.24+163"
))
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.16+115" in pubspec
assert "static const int schemaVersion = 33;" in database

# Removing visible brackets must preserve the pre-existing typography:
# action/state is italic, dialogue is normal novel-gold, and a blank line
# separates the two in stored, historical and streaming presentations.
assert "const chatDialogueGold = Color(0xFFFDE68A);" in text
assert "fontStyle: FontStyle.italic" in text
assert "style: segment.isDialogue ? dialogue : action" in text
assert "RegExp(r'([^\\n])\\n(?=「)')" in text
assert ".join('\\n\\n')" in visuals
assert "assistantStreamingTranscriptBlocks" in visuals
assert "assistantStreamingTranscriptBlocks(content)" in chat
if lifelike_ablation:
    assert "当前动作神态消融实验已启用" in prompt
    assert "零或一段真正增加潜台词的短动作" in prompt
elif aggressive_dialogue:
    assert "普通聊天最终正文只写真正说出口的话" in prompt
    assert "普通聊天最终正文只写真正说出口的话" in prompt
else:
    assert "动作行后空一行" in prompt
    assert rules.count("动作行后空一行") >= 2
    assert "动作行后空一行，再写它修饰的对白" in rules
assert "legacyEditableRuleLayerSha256V03814" in rule_defaults
assert "...legacyEditableRuleLayerSha256V03814.entries" in database

# The native floating chat has the same typography and spacing contract.
assert "StyleSpan(Typeface.ITALIC)" in overlay
assert "StyleSpan(Typeface.NORMAL)" in overlay
assert any(token in overlay for token in (
    "ForegroundColorSpan(Color.rgb(253, 230, 138))",
    "ForegroundColorSpan(dialogueTintColor())",
))
assert "Color.rgb(253, 230, 138)" in overlay
assert "OverlayDialogueFormatter.actionRanges(visible)" in overlay
assert "fun actionRanges(value: String)" in overlay_formatter
assert 'Regex("([^\\\\n])\\\\n(?=「)")' in overlay_formatter

# New/unset chat panels start at 75%. Existing explicit values remain stored.
assert "double _panelOpacity = 0.75;" in chat
assert "'chat_panel_opacity': '0.75'" in database
assert database.count("'chat_panel_opacity': '0.75'") >= 2

# User bubbles remain content-sized and tailless, with slightly wider internal
# left/right breathing room.
assert "IntrinsicWidth(" in chat
assert "horizontal: 14" in chat and "vertical: 11" in chat
assert "_BubbleTailPainter" not in chat

# This hotfix must not disturb the already accepted unlock, streaming or
# two-level overlay routing behavior. A later release may add a separately
# keyed manual reasoning-translation cache without altering body formatting.
assert "class ReferenceUnlockControl" in phone
assert "static const double slideDistance = 100" in phone
assert "emitDeltas: false," in runner
assert "showGenerationDraft" in chat
assert 'onOpenChat = { showChatOverlay("pet_double_tap_menu") }' in overlay
assert 'smallButton("打开") { openFullApp(openChat = true) }' in overlay
if "reasoning_translation" in database:
    assert "CREATE TABLE IF NOT EXISTS reasoning_translations" in database
    assert "PRIMARY KEY (scope, message_id)" in database

assert "python3 tools/validate_v03815_chat_style_regression_hotfix.py" in workflow
assert "grep -Fqx 'version: 0.38.16+115' app/pubspec.yaml" in workflow
assert "AI-Companion-v0.38.16-115-Action-Segment-Parser-Hotfix-APK" in workflow
assert "agent/v03816-action-segment-parser-hotfix" in workflow

print("v0.38.15 chat style regression hotfix validated")
