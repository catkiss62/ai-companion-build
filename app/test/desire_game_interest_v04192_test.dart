import 'dart:convert';

import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/desire_satisfaction_ledger.dart';
import 'package:ai_companion_localfirst/core/desire/game_engagement_policy.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_selection_policy.dart';
import 'package:ai_companion_localfirst/core/desire/self_drive_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  test('game engagement flows, saturates, cools and becomes available again', () {
    GameEngagementSnapshot evaluate(List<Duration> ages) =>
        GameEngagementPolicy.evaluate(
          now: now,
          outcomeTimes: ages.map(now.subtract),
          notableTimes: const <DateTime>[],
        );

    final spark = evaluate(const <Duration>[Duration(minutes: 10)]);
    final flow = evaluate(const <Duration>[
      Duration(minutes: 10),
      Duration(minutes: 25),
      Duration(minutes: 40),
    ]);
    final saturated = evaluate(List<Duration>.generate(
      9,
      (index) => Duration(minutes: 5 + index * 4),
    ));
    final cooling = evaluate(List<Duration>.generate(
      9,
      (index) => Duration(hours: 3, minutes: index),
    ));
    final available = evaluate(const <Duration>[Duration(hours: 9)]);

    expect(spark.phase, GameEngagementPhase.spark);
    expect(flow.phase, GameEngagementPhase.flow);
    expect(saturated.phase, GameEngagementPhase.saturated);
    expect(saturated.scoreAdjustment, lessThan(flow.scoreAdjustment));
    expect(cooling.phase, GameEngagementPhase.cooling);
    expect(cooling.scoreAdjustment, lessThan(0));
    expect(available.phase, GameEngagementPhase.available);
    expect(available.saturation, 0);
  });

  test('negative affect can interrupt otherwise active game momentum', () {
    final outcomes = <DateTime>[
      now.subtract(const Duration(minutes: 10)),
      now.subtract(const Duration(minutes: 25)),
    ];
    final neutral = GameEngagementPolicy.evaluate(
      now: now,
      outcomeTimes: outcomes,
      notableTimes: const <DateTime>[],
    );
    final distressed = GameEngagementPolicy.evaluate(
      now: now,
      outcomeTimes: outcomes,
      notableTimes: const <DateTime>[],
      negativeRestlessness: 0.85,
    );

    expect(distressed.scoreAdjustment, lessThan(neutral.scoreAdjustment));
    expect(distressed.moodAdjustment, closeTo(-0.119, 0.001));
  });

  test('not-due checkpoint never enters proactive competition', () {
    expect(
      CedarResumeEligibilityPolicy.canEnterCompetition(
        const Duration(minutes: 1),
      ),
      isFalse,
    );
    expect(
      CedarResumeEligibilityPolicy.canEnterCompetition(Duration.zero),
      isTrue,
    );
    expect(CedarResumeEligibilityPolicy.canEnterCompetition(null), isFalse);
  });

  test('ordinary game threads use curiosity instead of attachment', () {
    expect(
      SelfReviewDrivePolicy.forThread(
        topicKey: 'shared.activity.fishing',
        title: '鱼塘图鉴还没收齐',
        detail: '下次再看看',
        importance: 0.67,
      ),
      DriveKey.curiosity,
    );
    expect(
      SelfReviewDrivePolicy.forThread(
        topicKey: 'relationship.followup',
        title: '还想和你聊聊',
        detail: '',
        importance: 0.67,
      ),
      DriveKey.attachment,
    );
  });

  test('Cedar and shared activity use one semantic game domain', () {
    expect(
      ProactiveSelectionPolicy.canonicalTopic('cedar_game:fishing'),
      'game:fishing',
    );
    expect(
      ProactiveSelectionPolicy.canonicalTopic('shared.activity.fishing'),
      'game:fishing',
    );
    expect(
      ProactiveSelectionPolicy.canonicalTopic(
        '',
        reasonSource: 'mcp/cedar_game:fishing:play:123',
      ),
      'game:fishing',
    );
  });

  test('game sharing is a separate behavior lane from playing', () {
    final thought = CompanionThought(
      id: 'game-event',
      text: '真实游戏结果',
      driveKey: DriveKey.curiosity.name,
      kind: 'flit',
      strength: 0.8,
      bornAt: now,
      updatedAt: now,
      source: 'mcp/cedar_game:fishing:play:123',
      topicKey: 'cedar_game:fishing',
    );
    final share = DesireIntent(
      drive: DriveKey.curiosity,
      score: 0.8,
      reason: thought.text,
      wantAction: 'share_thought',
      thoughtId: thought.id,
      reasonSource: thought.source,
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[share],
      thoughtsById: <String, CompanionThought>{thought.id: thought},
      recentIntentKinds: const <String>[],
      now: now,
    );

    expect(result?.behaviorKind, 'game_share');
    expect(
      ProactiveSelectionPolicy.behaviorKindFor(
        DesireIntent(
          drive: DriveKey.curiosity,
          score: 0.8,
          reason: '继续',
          wantAction: 'resume_game',
          reasonSource: 'mcp/cedar_game:fishing:episode',
        ),
        sourceType: 'mcp',
      ),
      'play_game',
    );
  });

  test('causal satisfaction ledger round-trips and keeps source metadata', () {
    final ledger = DesireSatisfactionLedger(startedAt: now)
        .record(
          drive: DriveKey.curiosity,
          actionLane: 'play_game',
          source: 'mcp/cedar_game:fishing',
          now: now.add(const Duration(minutes: 2)),
        )
        .record(
          drive: DriveKey.curiosity,
          actionLane: 'play_game',
          source: 'mcp/cedar_game:fishing',
          now: now.add(const Duration(minutes: 4)),
        );
    final restored = DesireSatisfactionLedger.fromJson(
      jsonDecode(jsonEncode(ledger.toJson())) as Map,
      fallbackNow: now,
    );

    expect(restored.actions['play_game']?.count, 2);
    expect(
      restored.actions['play_game']?.source,
      'mcp/cedar_game:fishing',
    );
    expect(
      DesireSatisfactionLedgerController.laneFor(
        action: 'share_thought',
        source: 'mcp/cedar_game:fishing:play:123',
      ),
      'game_share',
    );
  });

  test('long-unused eligible lane gets only a bounded opportunity boost', () {
    final candidate = DesireIntent(
      drive: DriveKey.curiosity,
      score: 0.60,
      reason: '看看别的东西',
      wantAction: 'discover_interest',
      reasonSource: 'internal',
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[candidate],
      thoughtsById: const <String, CompanionThought>{},
      recentIntentKinds: const <String>[],
      now: now,
      satisfactionLedgerStartedAt: now.subtract(const Duration(days: 4)),
    );

    expect(result?.opportunityBoost, 0.06);
    expect(result?.intent.score, closeTo(0.66, 0.0001));
  });
}
