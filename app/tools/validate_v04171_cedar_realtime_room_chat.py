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


require('pubspec.yaml', 'version: 0.41.81+225')
require('lib/core/agent/agent_self_reader.dart', "buildLabel = 'v0.41.81+225'")
require('test/agent_self_reader_v0416_test.dart', 'build=v0.41.81+225 schema=61')
require(
    'lib/core/mcp/mcp_turn_state_resolver.dart',
    "'room'",
    'class McpContinuationCallResolver',
    "candidate['next_call']",
    'class McpRoomMessageResolver',
    "event['message']",
)
resolver = read('lib/core/mcp/mcp_turn_state_resolver.dart').lower()
for forbidden in ('gomoku', 'duel', '五子棋', '黑子', '白子'):
    assert forbidden not in resolver, f'generic resolver hardcodes {forbidden}'
require(
    'lib/core/mcp/cedar_toy_activity.dart',
    'continuationAction',
    'continuationParamsJson',
    'pendingRoomMessage',
    'companionCanObserve',
    'needsContinuation',
    '_repairRealtimeState',
    'action == existing.continuationAction',
    'realtimeContinuationGap = Duration(seconds: 1)',
)
require(
    'lib/core/mcp/cedar_toy_autonomy_engine.dart',
    '_observeSession',
    '_composeRoomDialogue',
    'params = CedarRoomActionPayload.withMessage(params, roomMessage)',
    "params['wait'] =",
    'Room dialogue is a session-local action annotation',
    "apiKey: apiKey",
    'AgentToolTextEnvelope.looksLikeMachinePayload',
)
require(
    'lib/core/ai/durable_generation_runner.dart',
    'final-expression',
    'cedarTurnHandedOff',
    '本机已实际提交的参数',
)
require(
    'lib/core/agent/agent_tool.dart',
    'submittedArguments',
)
require(
    'lib/core/agent/agent_tool_runner.dart',
    "reason: 'cedar_session_updated'",
    'roomMessageSent:',
    'submittedArguments:',
)
require(
    'lib/core/agent/agent_tool_text_envelope.dart',
    'looksLikeMachinePayload',
    'bare tool argument',
)
require(
    'lib/core/grounding/operational_claim_grounding_guard.dart',
    'cedar_action_argument_mismatch',
    'looksLikeMachinePayload',
)
require(
    'lib/core/maintenance/recovery_orchestrator.dart',
    "cedarContinuationState == 'observe_failed'",
    "'remote_event_companion_turn'",
    "'remote_room_message'",
    "'remote_wait_renewed'",
)
require(
    'lib/core/diagnostics/preflight_diagnostics.dart',
    "'cedarRealtime': cedarRealtime",
    "'cedarRoomMessageBodiesIncluded': false",
    "'cedarContinuationParamsIncluded': false",
    "'cedarRoomIdentityIncluded': false",
)
require(
    'lib/features/chat/cedar_toy_activity_window.dart',
    '已挂等房间事件',
    '打开 Cedar 官方游戏厅',
    'CedarToyClient.baseUrl',
)
require(
    'test/cedar_realtime_room_chat_v04171_test.dart',
    'nested singular room',
    'typed long-poll continuation',
    'public room messages',
    'truncated bare tool arguments',
    'submitted arguments',
)
require(
    'docs/TEST_CHECKLIST.md',
    'v0.41.71+215 Cedar 实时共玩与房间对话真机验收增量',
    '不再发“我下好了”',
)
require(
    '.github/workflows/build-apk.yml',
    'agent/v04181-cedar-background-agent-tools',
    'AI-Companion-v0.41.81-225-Cedar-Background-Agent-Tools-APK',
    'validate_v04171_cedar_realtime_room_chat.py',
)
require(
    'docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md',
    'v0.41.70+214 Cedar 实时共玩与房间对话真机失败取证',
    'https://toy.cedarstar.org/',
)

print('v0.41.71+215 Cedar realtime room chat validation passed.')
