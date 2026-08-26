from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


phone = read("lib/features/phone/simulated_phone_page.dart")
chat = read("lib/features/chat/chat_page.dart")
segments = read("lib/core/models/chat_segment.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
text = read("lib/widgets/action_tint_text.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
overlay_formatter = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.14+113" in pubspec
assert "static const int schemaVersion = 33;" in database

# Match phone_system(1).html geometry and timing instead of approximating it.
assert "class ReferenceUnlockControl extends StatefulWidget" in phone
assert "static const double slideDistance = 100" in phone
assert "duration: const Duration(milliseconds: 2500)" in phone
assert "duration: const Duration(milliseconds: 300)" in phone
assert "Cubic(0.4, 0, 0.2, 1)" in phone
assert "width: 56" in phone and "height: 156" in phone
assert "height: 100" in phone
assert "alpha: active ? 0.18 : 0.08" in phone
assert "onVerticalDragDown: _press" in phone
assert "dragOriginY - details.globalPosition.dy" in phone
assert "duration: const Duration(milliseconds: 200)" in phone
assert "spreadRadius: 10 * expansion" in phone
lock_start = phone.index("class LockScreen")
lock_end = phone.index("class ReferenceUnlockControl", lock_start)
lock = phone[lock_start:lock_end]
assert "'上滑解锁'" in lock
assert "HomeIndicator" not in lock
assert "onTap:" not in lock
assert "AnimatedScale(" not in phone[: phone.index("class Wallpaper")]

# One durable assistant turn uses one reading rail; its ordered chunks remain
# visible through dividers and the v0.38.13 live body/scroll contract remains.
assert "class _AssistantTranscriptSurface" in chat
assert "class _AssistantSegmentDivider" in chat
assert "width: double.infinity" in chat
assert "if (index > 0) const _AssistantSegmentDivider()" in chat
assert "class _UserBubbleSurface" in chat
assert "IntrinsicWidth(" in chat
assert "_BubbleTailPainter" not in chat
assert "_streamingBodyTailKey" in chat
assert "NotificationListener<UserScrollNotification>" in chat
assert "emitDeltas: true," in runner
assert "action: 'stream_preserved'" in runner

# New text follows action-line + corner-quoted-dialogue grammar. Old bracketed
# history is still parsed, while both renderers hide delimiters and share gold.
assert "nextLineIsDialogue" in segments
assert "return segment.text;" in visuals
assert "const chatDialogueGold = Color(0xFFE7D8A7);" in text
assert "stripActionDelimitersForDisplay" in text
assert "不加括号" in rules and "统一用直角引号「」" in rules
assert "不加括号" in prompt and "统一用「」" in prompt
assert "OverlayDialogueFormatter.visibleText(value)" in overlay
assert "ForegroundColorSpan(Color.rgb(231, 216, 167))" in overlay
assert "fun visibleText(value: String)" in overlay_formatter
assert "fun dialogueRanges(value: String)" in overlay_formatter

# Automatic reasoning translation is deliberately isolated to a later batch.
assert "reasoning_translation" not in database

assert "python3 tools/validate_v03814_reference_unlock_chat_transcript_ui.py" in workflow
assert "grep -Fqx 'version: 0.38.14+113' app/pubspec.yaml" in workflow
assert "AI-Companion-v0.38.14-113-Reference-Unlock-Chat-Transcript-UI-APK" in workflow
assert "agent/v03814-unlock-chat-transcript-ui" in workflow

print("v0.38.14 reference unlock and chat transcript UI validated")
