#!/usr/bin/env python3
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')


def sha(rel: str) -> str:
    return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()


def require(body: str, *tokens: str) -> None:
    for token in tokens:
        assert token in body, token


def main() -> int:
    assert 'version: 0.31.2+44' in text('pubspec.yaml')

    db = text('lib/core/database/app_database.dart')
    require(
        db,
        'static const int schemaVersion = 19;',
        "oldVersion < 19",
        'provider_reasoning TEXT NOT NULL DEFAULT',
        'companion_voice INTEGER NOT NULL DEFAULT 0',
        "'companion_voice_enabled', 'value': '0'",
        "row['provider_reasoning'] = row['reasoning_content'] ?? '';",
        "row['companion_voice'] = 0;",
    )

    model = text('lib/core/models/chat_message.dart')
    require(
        model,
        'final String reasoningContent;',
        'final String providerReasoning;',
        'final bool companionVoice;',
        "'provider_reasoning': providerReasoning",
        "'companion_voice': companionVoice ? 1 : 0",
    )

    protocol = text('lib/core/ai/companion_voice_protocol.dart')
    require(
        protocol,
        'class CompanionVoiceProtocol',
        "static const String settingKey = 'companion_voice_enabled';",
        '<companion_inner>',
        '<companion_reply>',
        'COMPANION VOICE OUTPUT CONTRACT',
        'inner_agent_planning',
        'inner_not_first_person',
        'reply_agent_planning',
        'reply_wait_user_turn',
        'COMPANION VOICE CORRECTION · ONE RETRY',
        'parseCandidate',
        'safeReplyFromContent',
        'streamableInnerPreview',
        'DeepSeek 原生双通道',
        '80～220 个中文字',
        '全角括号神态',
        '不强迫每轮撒娇、暧昧或动作描写',
        '保持 AI 身份与 REALITY GROUNDING',
    )
    assert protocol.count('COMPANION VOICE OUTPUT CONTRACT') == 1

    runner = text('lib/core/ai/durable_generation_runner.dart')
    require(
        runner,
        'CompanionVoiceProtocol.enabledFromSetting(',
        'emitDeltas: !companionVoiceEnabled',
        'emitCompanionPreview: companionVoiceEnabled',
        "finishReason: 'companion_voice_preview'",
        "finishReason: 'companion_voice_final'",
        'var parsed = CompanionVoiceProtocol.parseCandidate(',
        'fallbackReply = CompanionVoiceProtocol.safeReplyFromContent(',
        'correctionCode: parsed.failureCode',
        'providerReasoning: generated.reasoning',
        'companionVoice: companionVoiceEnabled',
        '_noteCompanionVoiceRetry(',
        '_noteCompanionVoiceBlock(',
        "finalContent = fallbackReply;",
        "visibleInner = '';",
    )
    assert runner.count('correctionCode: parsed.failureCode') == 1

    controller = text('lib/features/chat/chat_controller.dart')
    require(
        controller,
        "delta.finishReason == 'companion_voice_preview'",
        "delta.finishReason == 'companion_voice_final'",
        'streamingReasoning = delta.reasoning;',
        'streamingContent = delta.content;',
    )
    assert controller.count("delta.finishReason == 'companion_voice_preview'") == 2
    assert controller.count("delta.finishReason == 'companion_voice_final'") == 2

    proactive = text('lib/core/desire/proactive_engine.dart')
    require(
        proactive,
        'CompanionVoiceProtocol.attachAtTail(',
        'CompanionVoiceProtocol.parseCandidate(',
        'voiceCorrectionCode: voiceRetry ? retryReason :',
        'var prepared = prepareCandidate(candidate);',
        'return blockCompanionVoice(prepared.voiceFailure);',
        'providerReasoning: prepared.providerReasoning',
        'companionVoice: companionVoiceEnabled',
        "decision: 'companion_voice_wait'",
    )
    # Both Voice and Grounding share this single retry call site.
    assert proactive.count('final retried = await generateCandidate(') == 1

    settings = text('lib/features/settings/settings_page.dart')
    require(
        settings,
        "title: const Text('伴侣式内心与回应')",
        "(await db.getSetting('companion_voice_enabled')) == '1'",
        "companionVoiceEnabled ? '1' : '0'",
        '!companionVoiceEnabled',
        '关闭后直接使用模型原始输出',
    )

    page = text('lib/features/chat/chat_page.dart')
    panel = text('lib/widgets/reasoning_panel.dart')
    require(controller, '!streamingCompanionVoice', 'playText(result.assistant!.content')
    require(page, 'companionVoice: message.companionVoice', 'controller.streamingCompanionVoice')
    require(panel, "'🧠 内心'", "'🧠 思考'")

    diagnostics = text('lib/core/diagnostics/preflight_diagnostics.dart')
    require(
        diagnostics,
        "'companionVoice': {",
        "'retryCount'",
        "'blockCount'",
        'AI Companion v0.31.2+44 · REDACTED LOCAL DIAGNOSTIC REPORT',
    )

    tests = text('test/companion_voice_protocol_v0312_test.dart')
    require(
        tests,
        'parses independent inner voice and final reply',
        'rejects provider-style agent planning',
        'rejects malformed or non-first-person inner block',
        'WAIT is reserved for proactive mode',
        'attaches contract exactly once at the real prompt tail',
        'accepts DeepSeek native reasoning and content channels',
        'safe reply fallback never leaks inner blocks or Agent plans',
        'streams only reversible first-person inner previews',
    )

    migration_validator = text('tools/validate_companion_voice_v19_sql.py')
    require(
        migration_validator,
        'v18 -> v19 preserves legacy reasoning',
        'companion_voice_enabled',
        'provider_reasoning',
        'companion_voice',
    )

    # v0.31.2 must not alter Android overlay or the frozen TTS implementation.
    assert sha('android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt') == 'a622f882573c3e230627e9db01e0c58215440670c75147149b2509a79489ad6d'
    assert sha('android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt') == 'c581b4cb93c5979ccb5d413904cd43dd1a7046a0d66ab7b75acf6e4cfbafc36b'
    assert sha('lib/core/tts/tts_service.dart') == '691605c38107e1d4293f1fdbb176e51392555c7d39ee07abe006f0c01cffa47f'
    assert sha('lib/core/tts/tts_playback_queue.dart') == '4cdd466553664b3039d81c30ff4cad2cb71dc2ea8fb6234a5371c153a8adfc5b'
    assert sha('lib/core/desire/desire_core_policy.dart') == 'd28f0fb575ed2d7b32bb186e5058c07432a30a5aa81b76a5474a9f298c7dcab5'
    assert sha('lib/core/desire/desire_engine.dart') == '1d46d85ba9a3f0c851430994bba93dbd8afd1ce735a01ce023795702f0c89af9'
    assert sha('lib/core/desire/self_drive_engine.dart') == '6fbd88b10a733a43f9a9604c546f96bcd4b5a38a75790038bf4b1040820cc968'

    print('v0.31.2+44 streaming inner and richer voice validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
