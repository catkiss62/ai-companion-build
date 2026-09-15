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


require('pubspec.yaml', 'version: 0.41.70+214')
require('lib/core/agent/agent_self_reader.dart', "buildLabel = 'v0.41.70+214'")
require('test/agent_self_reader_v0416_test.dart', 'build=v0.41.70+214 schema=61')
require(
    'lib/core/agent/agent_tool_text_envelope.dart',
    'class AgentToolTextEnvelope',
    'shouldHoldFromVisibleStream',
    'detected: true, valid: false',
)
require(
    'lib/core/ai/durable_generation_runner.dart',
    'AgentToolTextEnvelope.parse(normalizedContent)',
    "invalid_text_tool_envelope",
    'AgentToolTextEnvelope.shouldHoldFromVisibleStream(content)',
    'latestUserText: user.content',
)
require(
    'lib/core/grounding/operational_claim_grounding_guard.dart',
    '_machineProtocol',
    'machine_protocol_leak',
)
require(
    'lib/core/agent/agent_participation_consent.dart',
    'class AgentParticipationConsentPolicy',
    'explicitlyGranted',
    'describesExistingRoom',
)
require(
    'lib/core/agent/agent_tool_runner.dart',
    'AgentParticipationConsentPolicy.explicitlyGranted(latestUserText)',
    'McpTurnStateResolver.resolveStructured(outcome.structuredContent)',
    '结构化回合状态',
    "continuationRecommended: CedarAgentTurnPolicy.continueInCurrentTurn",
)
require(
    'lib/core/agent/agent_tool.dart',
    'final bool continuationRecommended',
)
require(
    'lib/core/mcp/mcp_turn_state_resolver.dart',
    'class McpTurnStateResolver',
    'structured_participant_identity',
    'structured_seat_ownership',
)
generic_resolver = read('lib/core/mcp/mcp_turn_state_resolver.dart').lower()
for forbidden in ('gomoku', 'duel', '五子棋', '黑子', '白子'):
    assert forbidden not in generic_resolver, f'generic resolver hardcodes {forbidden}'
require(
    'lib/core/mcp/cedar_toy_autonomy_engine.dart',
    'structured?.nextActor',
    'McpTurnStateResolver.resolveStructured(outcome.structuredContent)',
)
require(
    'lib/core/desire/proactive_engine.dart',
    "reasonTag: 'active_shared_game'",
    '旧的游戏分享已延后',
)
require(
    'test/agent_mcp_runtime_hardening_v04170_test.dart',
    'provider DSML is normalized',
    'either direction of invitation',
    'structured participant identity',
)
require(
    'docs/TEST_CHECKLIST.md',
    'v0.41.70+214 Agent/MCP 通用运行时加固真机验收增量',
    '正文不得出现 DSML',
)
require(
    '.github/workflows/build-apk.yml',
    'agent/v04170-agent-mcp-runtime-hardening',
    'AI-Companion-v0.41.70-214-Agent-MCP-Runtime-Hardening-APK',
    'validate_v04170_agent_mcp_runtime_hardening.py',
)
require(
    'docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md',
    'v0.41.70+214',
    'Agent/MCP 通用运行时加固',
)

print('v0.41.70+214 Agent/MCP runtime hardening validation passed.')
