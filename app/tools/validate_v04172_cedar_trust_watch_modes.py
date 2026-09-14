#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith('.github/') or path.startswith('AI_') else ROOT
    return (base / path).read_text(encoding='utf-8')


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f'{path}: missing {missing}'


require('pubspec.yaml', 'version: 0.41.73+217')
require('lib/core/agent/agent_self_reader.dart', "buildLabel = 'v0.41.73+217'")
require('test/agent_self_reader_v0416_test.dart', 'build=v0.41.73+217 schema=61')
require('lib/core/mcp/mcp_http_client.dart', "'version': '0.41.73'")
require(
    'lib/core/mcp/cedar_toy_activity.dart',
    'enum CedarViewingPace',
    "leisure('leisure', '休闲模式', Duration(minutes: 2))",
    "fast('fast', '快速模式', Duration(seconds: 5))",
    "spectate('spectate', '观战模式', Duration(seconds: 10))",
    'viewerHeartbeatTtl',
    'currentViewingPace',
    'pendingDirectShares',
    'phase: outcome.isError ? existing.phase : phase',
    'markWriteOutcomeUncertain',
)
require(
    'lib/core/mcp/mcp_turn_state_resolver.dart',
    'class McpResumeAfterResolver',
    "'resume_after_seconds'",
)
require(
    'lib/core/mcp/cedar_toy_autonomy_engine.dart',
    'session.mode == CedarParticipationMode.unknown',
    "params['wait'] = false",
    "mode == CedarParticipationMode.solo",
    '_judgeOutcome',
    'thinking: false',
    'maxTokens: 512',
    'directWhenWatched: true',
    "error.code == 'network_or_timeout'",
    "CedarAutonomyProgress('write_outcome_sync')",
)
require(
    'lib/features/chat/cedar_toy_activity_window.dart',
    'store.beginViewing()',
    'store.endViewing()',
    'CedarViewingPace.values',
    "reason: 'cedar_viewing_pace_${pace.key}'",
    '值得分享的进展会直接发到聊天',
)
require(
    'lib/core/desire/proactive_engine.dart',
    'deliverPendingCedarShareIfAny',
    "forcedThought?.source.startsWith('mcp/cedar_game:')",
    'isImmediateCedarShare',
)
require(
    'lib/core/maintenance/recovery_orchestrator.dart',
    'deliverPendingCedarShareIfAny',
    "cedarContinuationState == 'play_failed'",
    'Duration(seconds: 15)',
    'cedar_watched_share_sent',
)
require(
    'test/cedar_trust_watch_modes_v04172_test.dart',
    'exact temporary solo pace contract',
    'solo companion turn remains',
    'structured turn ownership stays authoritative',
    'resume cadence is consumed without reinterpretation',
)
require(
    '.github/workflows/build-apk.yml',
    'agent/v04173-cedar-deterministic-entry-reply-completion',
    'AI-Companion-v0.41.73-217-Cedar-Entry-Reply-Completion-APK',
    'validate_v04172_cedar_trust_watch_modes.py',
)
require(
    'AI_Companion_当前总账.md',
    'Cedar MCP 信任优先永久合同',
    'v0.41.72+216',
)

activity = read('lib/core/mcp/cedar_toy_activity.dart')
autonomy = read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
orchestrator = read('lib/core/maintenance/recovery_orchestrator.dart')
assert "phase: outcome.isError ? CedarActivityPhase.failed" not in activity
assert "params['wait'] = true" not in autonomy
assert "cedarContinuationState.endsWith('failed')" in orchestrator
assert "cedarDelay = const Duration(minutes: 5)" not in orchestrator

print('v0.41.72+216 Cedar trust/watch modes validation passed.')
