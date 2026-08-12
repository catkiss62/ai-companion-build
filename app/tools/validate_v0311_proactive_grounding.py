#!/usr/bin/env python3
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')


def sha(rel: str) -> str:
    return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()


def main() -> int:
    pubspec = text('pubspec.yaml')
    assert 'version: 0.31.1+41' in pubspec

    # Proactive history must be structurally separated from current user turns.
    policy = text('lib/core/grounding/prompt_history_policy.dart')
    for token in [
        'class PromptHistoryPolicy',
        'userTurnHistory(',
        'proactiveHistoryTranscript(',
        'ANSWERED CHAT HISTORY',
        'REAL_USER_HISTORY',
        'ASSISTANT_HISTORY',
        'ASSISTANT_PROACTIVE_HISTORY',
        "'role': 'system'",
    ]:
        assert token in policy, token

    prompt = text('lib/core/ai/prompt_builder.dart')
    for token in [
        'PromptHistoryPolicy.proactiveHistoryTranscript(recent)',
        'PromptHistoryPolicy.userTurnHistory(recent)',
        'CURRENT_USER_TURN = NONE',
        'ANSWERED_HISTORY_ONLY = true',
        '推理阶段和最终正文都不得把 ANSWERED CHAT HISTORY',
        'REAL_USER_MESSAGE / REAL_USER_HISTORY',
    ]:
        assert token in prompt, token

    guard = text('lib/core/grounding/proactive_grounding_guard.dart')
    for token in [
        'class ProactiveReasoningGroundingGuard',
        'reasoning_replied_answered_history',
        'reasoning_invented_current_user_turn',
        'lastUserAnswered',
        'pendingUserTurn',
        'lastUserText',
    ]:
        assert token in guard, token

    proactive = text('lib/core/desire/proactive_engine.dart')
    for token in [
        'ProactiveReasoningGroundingGuard.evaluate(',
        "db.getSetting('grounding_retry_count')",
        "db.setSetting('grounding_retry_last_reason', reason)",
        'REALITY GROUNDING CORRECTION · ONE RETRY',
        'CURRENT_USER_TURN = NONE',
        'var candidate = await generateCandidate(context);',
        'final retried = await generateCandidate(retryContext);',
        'reasoningContent: candidate.reasoning',
    ]:
        assert token in proactive, token
    assert proactive.count('generateCandidate(retryContext)') == 1, 'grounding correction must be one retry only'

    diagnostics = text('lib/core/diagnostics/preflight_diagnostics.dart')
    for token in [
        'AI Companion v0.31.1 · REDACTED LOCAL DIAGNOSTIC REPORT',
        "'proactiveGroundingRetryCount'",
        "'proactiveGroundingRetryLastAt'",
        "'proactiveGroundingRetryLastReason'",
    ]:
        assert token in diagnostics, token

    # Timestamps are presentation metadata, never part of ChatMessage.content.
    formatter = text('lib/features/chat/chat_timestamp_formatter.dart')
    chat_page = text('lib/features/chat/chat_page.dart')
    controller = text('lib/features/chat/chat_controller.dart')
    for token in [
        'class ChatTimestampFormatter',
        'static String time(DateTime value)',
        'shouldShowDateSeparator(',
        'dateSeparator(',
    ]:
        assert token in formatter, token
    for token in [
        'ChatTimestampFormatter.time(message.createdAt)',
        'ChatTimestampFormatter.shouldShowDateSeparator(',
        '_DateSeparator(createdAt: message.createdAt)',
    ]:
        assert token in chat_page, token
    assert 'message.copyWith(content:' not in chat_page
    assert 'playText(message.content, manual: true)' in controller

    tests = {
        'test/prompt_history_policy_v0311_test.dart': [
            'proactive history contains no role=user current turn',
            'ANSWERED CHAT HISTORY',
            'REAL_USER_HISTORY',
        ],
        'test/chat_timestamp_formatter_v0311_test.dart': [
            'formats message time without modifying message content',
            'date separator appears only when local calendar day changes',
            'today and yesterday labels are chat-app friendly',
        ],
        'test/proactive_grounding_guard_v031_test.dart': [
            'reasoning guard blocks replying to answered hello as current turn',
            'reasoning guard allows remembering old hello without treating it as current',
        ],
    }
    for rel, tokens in tests.items():
        body = text(rel)
        for token in tokens:
            assert token in body, (rel, token)

    # Overlay is explicitly frozen in this stage: Android overlay/activity bytes
    # must stay exactly at the v0.31.0 baseline.
    assert sha('android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt') == 'a622f882573c3e230627e9db01e0c58215440670c75147149b2509a79489ad6d'
    assert sha('android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt') == 'c581b4cb93c5979ccb5d413904cd43dd1a7046a0d66ab7b75acf6e4cfbafc36b'

    # TTS presentation guard: message timestamps cannot leak into speech by
    # altering the established service/queue implementation.
    assert sha('lib/core/tts/tts_service.dart') == '691605c38107e1d4293f1fdbb176e51392555c7d39ee07abe006f0c01cffa47f'
    assert sha('lib/core/tts/tts_playback_queue.dart') == '4cdd466553664b3039d81c30ff4cad2cb71dc2ea8fb6234a5371c153a8adfc5b'

    handoff = text('docs/HANDOFF.md')
    ledger = text('docs/PROJECT_TASK_LEDGER.md')
    for token in [
        'v0.31.1+41',
        'Proactive Context Isolation',
        'Reasoning Grounding',
        'Chat Timestamps',
        '悬浮球任务冻结',
    ]:
        assert token in handoff, token
    for token in [
        'Proactive Context Isolation',
        'Reasoning Grounding',
        '聊天时间 metadata 展示',
        'Notification Experience',
        'FROZEN · 已知问题',
    ]:
        assert token in ledger, token

    print('v0.31.1 Proactive Grounding + Chat Timestamps static validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
