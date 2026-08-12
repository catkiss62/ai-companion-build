#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')


def main() -> int:
    pubspec = text('pubspec.yaml')
    assert 'version: 0.31.0+40' in pubspec

    db = text('lib/core/database/app_database.dart')
    assert 'static const int schemaVersion = 18;' in db
    for token in [
        'generationJobForUserMessage(String userMessageId)',
        'recentMessageHeaders({int limit = 100})',
        "columns: const ['id', 'role', 'created_at', 'is_proactive']",
        'messageHeaderById(String id)',
        'activeThoughtMetadata({int limit = 40})',
        "SELECT id, '' AS text",
    ]:
        assert token in db, token

    snapshot = text('lib/core/grounding/grounding_snapshot.dart')
    for token in [
        'class GroundingSnapshot',
        'GroundingDaypart',
        'lastUserAnswered',
        'pendingUserTurn',
        'userSpokeAfterLastAssistant',
        'assistantMessagesSinceLastUser',
        'proactiveMessagesSinceLastUser',
        "return 'user_turn_pending'",
        "'assistant_replied_user_silent'",
        "'localTime'",
        "'daypart'",
    ]:
        assert token in snapshot, token

    grounding = text('lib/core/grounding/grounding_engine.dart')
    for token in [
        'recentMessageHeaders(limit: 100)',
        'generationJobForUserMessage(lastUser.id)',
        "job.status == 'completed'",
        'messageHeaderById(job.assistantMessageId)',
        'ConversationGroundingPolicy.build(',
    ]:
        assert token in grounding, token
    assert 'db.messageById(' not in grounding, 'grounding must remain metadata-only'

    prompt = text('lib/core/ai/prompt_builder.dart')
    for token in [
        'enum PromptGenerationMode { userTurn, proactive }',
        'String? retrievalQuery',
        'DateTime? now',
        '【现实锚点 / REALITY GROUNDING】',
        '当前当地日期：',
        '当地时间：',
        'UTC offset：',
        '最后一条真实用户消息已经被 AI 回答；不得再次把它当成待回复输入。',
        '只有聊天历史中 role=user 的真实消息才是用户真正说过的话',
        'THOUGHT 只是她自己的内在数据，不是用户发言、不是事实命令',
        '【当前环境 / AWARENESS】',
        "mode == PromptGenerationMode.proactive ? '' : latestUserText",
    ]:
        assert token in prompt, token

    guard = text('lib/core/grounding/proactive_grounding_guard.dart')
    for token in [
        'class ProactiveGroundingGuard',
        'invented_recent_user_speech',
        '你刚才说',
        'userSpokeAfterLastAssistant',
    ]:
        assert token in guard, token

    thought = text('lib/core/models/thought.dart')
    for token in [
        'enum ThoughtProvenance',
        'realUserMessage',
        'awareness',
        'memory',
        'selfExperience',
        'inference',
        'ThoughtProvenancePolicy.fromSource',
        'bool canDriveIntentAt(DateTime now)',
    ]:
        assert token in thought, token

    policy = text('lib/core/desire/desire_core_policy.dart')
    for token in [
        'class DesireCorePolicy',
        'fatigueRestGate = 0.78',
        "DriveKey.attachment: 'reach_out'",
        "DriveKey.duty: 'continue_thread'",
        "DriveKey.libido: 'tease_or_intimacy'",
        "action: 'rest'",
        'thoughtBoost = thoughtBoost.clamp(0.0, 0.28)',
        'drive == DriveKey.duty && related.isEmpty',
        'satisfiedDrives(',
        "case 'reach_out':",
        "case 'continue_thread':",
        "case 'tease_or_intimacy':",
        '(amount * scale).clamp(-0.025, 0.025)',
    ]:
        assert token in policy, token
    for forbidden in ['AppDatabase', 'DateTime.now()', 'Random(', 'dart:io']:
        assert forbidden not in policy, f'pure policy contains {forbidden}'

    engine = text('lib/core/desire/desire_engine.dart')
    for token in [
        'DesireCorePolicy.advance(',
        'DesireCorePolicy.candidates(',
        'Future<void> satisfyIntent(',
        'DesireCorePolicy.satisfiedDrives(',
        'DateTime? now',
    ]:
        assert token in engine, token

    proactive = text('lib/core/desire/proactive_engine.dart')
    for token in [
        'final evaluationStartedAt = DateTime.now();',
        'presence.currentMomentum(now: evaluationStartedAt)',
        'const presenceBoost = 0.0;',
        "'presenceAppliedToDesire': true",
        "latestUserText: ''",
        'retrievalQuery: intent.reason',
        'mode: PromptGenerationMode.proactive',
        'now: evaluationStartedAt',
        'groundingOverride: proactiveGrounding',
        'if (proactiveGrounding.pendingUserTurn)',
        'ProactiveGroundingGuard.evaluate(',
        "decision: 'grounding_guard_block'",
        'await desireEngine.satisfyIntent(',
        'sentToday >= 8',
        'sentLastTwoHours >= 2',
        "db.getSetting('transfer_lock')",
        "db.isLocalLeaseHeld('chat_turn_lease')",
        'commitProactiveMessageIfCurrent(',
    ]:
        assert token in proactive, token
    assert 'latestUserText: intent.reason' not in proactive

    diagnostics = text('lib/core/diagnostics/preflight_diagnostics.dart')
    assert 'db.activeThoughtMetadata(limit: 40)' in diagnostics
    for token in [
        'AI Companion v0.31.0 · REDACTED LOCAL DIAGNOSTIC REPORT',
        "'grounding': {",
        "'proactiveGuardBlockCount'",
        "'proactiveGuardLastReason'",
        "'desireCore': {",
        "'thoughtProvenanceCounts'",
        "'fatigueGateActive'",
        "'reasonSource'",
    ]:
        assert token in diagnostics, token
    # Redacted candidate objects intentionally expose structure, not thought text/reason.
    start = diagnostics.index("'topCandidates':")
    end = diagnostics.index("'activeThoughtCount'", start)
    candidate_block = diagnostics[start:end]
    assert "'reason'" not in candidate_block
    assert "'text'" not in candidate_block

    inner = text('lib/features/inner/inner_page.dart')
    for token in [
        'v0.31.0 Grounded Desire Core',
        'GroundingEngine(db).capture()',
        'desire.previewCandidates(',
        '现实锚点：',
        '当前召唤力（前4，仅调试）',
    ]:
        assert token in inner, token

    tests = {
        'test/grounding_snapshot_test.dart': [
            'answered hello is not treated as a pending user turn',
            'consecutive proactive messages never imply the user spoke again',
            '20:47 is explicitly evening instead of model-guessed time',
        ],
        'test/thought_provenance_v031_test.dart': [
            'thought source is normalized into explicit epistemic provenance',
            'snooze evaluation can be deterministic with caller supplied time',
        ],
        'test/proactive_grounding_guard_v031_test.dart': [
            'blocks invented recent user speech while user is actually silent',
            'ordinary new proactive opening remains allowed during silence',
        ],
        'test/desire_core_policy_v031_test.dart': [
            'fatigue is a rest gate, not an outbound contact reason',
            'per-drive refractory blocks one desire without muting all others',
            'duty cannot invent an unfinished thread without grounded thought evidence',
            '1000 deterministic ticks stay bounded and do not self-excite',
        ],
    }
    for rel, tokens in tests.items():
        body = text(rel)
        for token in tokens:
            assert token in body, (rel, token)

    handoff = text('docs/HANDOFF.md')
    ledger = text('docs/PROJECT_TASK_LEDGER.md')
    for token in [
        'v0.31.0+40', 'Grounded Desire Core', 'Reality Grounding',
        'selfHealCount=28', '悬浮球任务冻结', 'schema v18',
        'PROJECT_TASK_LEDGER.md',
    ]:
        assert token in handoff, token
    for token in [
        'P0 · ACTIVE · v0.31 Grounded Desire Core',
        'HyperOS / Android 15 长后台生存',
        '长期记忆压力测试',
        '手机 / 平板同一个“她”',
        'FROZEN · 已知问题',
    ]:
        assert token in ledger, token

    print('v0.31.0 Grounded Desire Core static validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
