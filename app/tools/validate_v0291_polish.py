#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert 'version: 0.29.1+35' in pubspec or 'version: 0.30.0+36' in pubspec

    segmenter = (ROOT / 'lib/core/tts/tts_sentence_segmenter.dart').read_text(encoding='utf-8')
    assert '_isLayoutBreak' in segmenter
    for token in ["c == '\\n'", "c == '\\r'", "c == '\\u2028'", "c == '\\u2029'"]:
        assert token in segmenter, token
    assert "c == '\\n' &&" not in segmenter
    for token in ["c == '。'", "c == '！'", "c == '？'", "c == '；'", "c == '.'", "c == '!'", "c == '?'", "c == ';'"]:
        assert token in segmenter, token

    chat = (ROOT / 'lib/features/chat/chat_page.dart').read_text(encoding='utf-8')
    completed = chat[chat.index('class _MessageBubble'):chat.index('class _StreamingBubble')]
    assert completed.index('ReasoningPanel(') < completed.index('SelectableText(message.content')
    streaming = chat[chat.index('class _StreamingBubble'):]
    assert streaming.index('ReasoningPanel(') < streaming.index('SelectableText(controller.streamingContent)')

    server = (ROOT / 'lib/core/platform/background_chat_command_server.dart').read_text(encoding='utf-8')
    assert "db.recentMessages(limit: 8)" in server
    overlay_case = server[server.index("case 'overlayOpened':"):server.index("case 'sendMessage':")]
    assert 'unawaited(_warmOverlayController())' in overlay_case
    assert overlay_case.index('db.recentMessages(limit: 8)') < overlay_case.index('_warmOverlayController')

    overlay = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in [
        'BUBBLE_WINDOW_DP = 62', 'BUBBLE_AVATAR_DP = 50', 'BUBBLE_BADGE_DP = 20',
        'OVERLAY_RECENT_LIMIT = 8', 'badge?.bringToFront()', 'translationZ = dp(12).toFloat()',
        'smallInlineAction("🧠 思考")',
    ]:
        assert token in overlay, token
    adapter = overlay[overlay.index('private inner class NativeChatAdapter'):overlay.index('private fun proactiveIntentLabel')]
    assert adapter.index('smallInlineAction("🧠 思考")') < adapter.index('text = message.content')

    handoff = ROOT / 'docs/HANDOFF.md'
    assert handoff.exists()
    text = handoff.read_text(encoding='utf-8')
    for token in ['v0.29.1', 'v0.29.0', 'schema v18', 'MejuTTS_A2_OriginalNative_v2.5.apk', 'Active Brain']:
        assert token in text, token

    print('v0.29.1 TTS/UI/HANDOFF static validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
