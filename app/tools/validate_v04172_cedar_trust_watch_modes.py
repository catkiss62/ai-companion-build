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


require('pubspec.yaml', 'version: 0.41.82+226')
require('lib/core/agent/agent_self_reader.dart', "buildLabel = 'v0.41.82+226'")
require('test/agent_self_reader_v0416_test.dart', 'build=v0.41.82+226 schema=61')
require('lib/core/mcp/mcp_http_client.dart', "'version': '0.41.82'")
require(
    'lib/core/mcp/cedar_toy_activity.dart',
    'enum CedarViewingPace',
    "leisure('every5', '5轮回复', 5)",
    "fast('every1', '1轮回复', 1)",
    "spectate('every10', '10轮回复', 10)",
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
    'CedarActionTransportPolicy.immediateResponseParams',
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
    'CedarViewingPace.spectate',
    "reason: 'cedar_viewing_pace_${pace.key}'",
    '两次过程分享最少间隔',
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
    'fixed solo pace and durable sharing interval contract',
    'solo companion turn remains',
    'structured turn ownership stays authoritative',
    'resume cadence is consumed without reinterpretation',
)
require(
    '.github/workflows/build-apk.yml',
    'agent/v04182-cedar-state-machine-e2e',
    'AI-Companion-v0.41.82-226-Cedar-State-Machine-E2E-APK',
    'validate_v04172_cedar_trust_watch_modes.py',
)
require(
    'docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md',
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
