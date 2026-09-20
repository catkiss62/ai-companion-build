import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_selection_policy.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

const _cedarPlaySuccess = AgentToolResult(
  toolId: 'cedar_toy.play',
  status: AgentToolStatus.succeeded,
  displayText: '已取得真实游玩结果',
  promptData: '【Cedar Toy 真实 游玩 Outcome】',
);

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  test('fishing ambience cannot masquerade as a running Cedar action', () {
    for (final text in <String>[
      '主人，漂还是没动，图鉴也还是那几条老面孔。',
      '我就把鱼漂挂着等待，看看什么时候咬钩。',
      '鱼饵补齐了，我又坐回池塘边上了。',
      '钓鱼多省事，甩出去挂着就行。',
    ]) {
      final result = OperationalClaimGroundingGuard.evaluate(text: text);
      expect(result.allowed, isFalse, reason: text);
      expect(result.reason, 'ungrounded_cedar_live_state');
    }
  });

  test('not played, future intent and historical time remain honest', () {
    for (final text in <String>[
      '我其实还没有去玩，只是又想起钓鱼了。',
      '我打算待会儿去钓鱼，但现在还没开始。',
      '上次钓鱼时，鱼漂确实半天没动。',
      '昨天我坐在池塘边等过一阵。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: text).allowed,
        isTrue,
        reason: text,
      );
    }
  });

  test('a current successful Cedar outcome grounds current play', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我正在钓鱼，鱼漂刚有动静。',
        currentToolResults: const [_cedarPlaySuccess],
      ).allowed,
      isTrue,
    );
  });

  test('pre-upgrade attachment game thought is curiosity at selection', () {
    final thought = CompanionThought(
      id: 'legacy-fishing-thread',
      text: '我还惦记着补满鱼饵后继续钓池塘。',
      driveKey: DriveKey.attachment.name,
      kind: 'fixation',
      strength: 0.8,
      bornAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
      source: 'self_drive/thread',
      topicKey: 'shared.activity.fishing',
    );
    final legacy = DesireIntent(
      drive: DriveKey.attachment,
      score: 0.8,
      reason: thought.text,
      wantAction: 'reach_out',
      thoughtId: thought.id,
      reasonSource: thought.source,
    );
    final selected = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[legacy],
      thoughtsById: <String, CompanionThought>{thought.id: thought},
      recentIntentKinds: const <String>[],
      now: now,
    );

    expect(selected?.intent.drive, DriveKey.curiosity);
    expect(selected?.intent.wantAction, 'check_in');
    expect(selected?.intentKind, 'curiosity');
  });
}
