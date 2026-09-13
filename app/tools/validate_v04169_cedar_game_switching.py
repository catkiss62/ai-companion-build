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


require('pubspec.yaml', 'version: 0.41.69+213')
require('lib/core/agent/agent_self_reader.dart', "buildLabel = 'v0.41.69+213'")
require(
    'lib/core/mcp/cedar_toy_activity.dart',
    "stateSettingKey = 'cedar_toy_activity_state_v2'",
    'class CedarQueuedSwitch',
    'class CedarCrossGameNotice',
    'class CedarGameExecution',
    'crossGameReferences',
    'nextActionAt',
    'continuationGap = Duration(minutes: 2)',
    'resumeAfterSeconds',
)
require(
    'lib/core/mcp/cedar_toy_autonomy_engine.dart',
    'continueDue',
    'queued_guide_ready',
    'companionCanContinue',
    'beginExecution',
    '_advanceSession',
    '_verifyOutcome',
)
require(
    'lib/core/ai/durable_generation_runner.dart',
    'cedarExplicitRequest',
    'hasUserTurnContinuation',
    '当前游戏的指南绝不授权另一个游戏',
)
require(
    'lib/core/agent/agent_tool_runner.dart',
    'loadSession(game)',
    'queueSwitch(',
    '目标游戏已进入可靠切换队列',
    '_verifyCedarOutcome',
)
require(
    'lib/core/maintenance/recovery_orchestrator.dart',
    'continueCedarActivityIfDue',
    'cedarContinuationDelay',
    'local_heartbeat_after_cedar_continuation',
)
require(
    'lib/features/chat/cedar_toy_activity_window.dart',
    '正在执行',
    '接下来切换到',
    '跨游戏提醒',
    'ChoiceChip',
)
require(
    'lib/core/grounding/operational_claim_grounding_guard.dart',
    '杀进去',
    '进房',
)
require(
    'docs/TEST_CHECKLIST.md',
    'v0.41.69+213 Cedar 切换与后台续步真机验收增量',
    'fishing → duel / rooms',
    'resume_after_seconds',
)
require(
    '.github/workflows/build-apk.yml',
    'agent/v04169-cedar-game-switching',
    'AI-Companion-v0.41.69-213-Cedar-Game-Switching-APK',
    'validate_v04169_cedar_game_switching.py',
)
require(
    'AI_Companion_当前总账.md',
    'v0.41.69+213',
    '旧钓鱼',
    '后台续步',
)

print('v0.41.69+213 Cedar game switching validation passed.')
