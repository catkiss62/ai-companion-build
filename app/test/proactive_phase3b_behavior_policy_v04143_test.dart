import 'dart:convert';

import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_selection_policy.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_thought_readiness_policy.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionThought _thought({
  required String id,
  required double strength,
  required String source,
  String topicKey = '',
}) {
  final at = DateTime.utc(2026, 9, 6, 8);
  return CompanionThought(
    id: id,
    text: 'local-only thought',
    driveKey: DriveKey.curiosity.name,
    kind: 'flit',
    strength: strength,
    bornAt: at,
    updatedAt: at,
    source: source,
    topicKey: topicKey,
  );
}

DesireIntent _intent({
  required String action,
  required double score,
  CompanionThought? thought,
}) =>
    DesireIntent(
      drive: DriveKey.curiosity,
      score: score,
      reason: 'local selection reason',
      wantAction: action,
      thoughtId: thought?.id,
      reasonSource: thought?.source ?? 'drive_state',
    );

void main() {
  final now = DateTime.utc(2026, 9, 6, 12);

  test('weak legacy thought cannot initiate autonomous behavior', () {
    expect(
      ProactiveThoughtReadinessPolicy.isReady(
        _thought(id: 'weak', strength: 0.13, source: 'internal'),
        now,
      ),
      isFalse,
    );
    expect(
      ProactiveThoughtReadinessPolicy.isReady(
        _thought(
          id: 'web',
          strength: 0.62,
          source: 'public_web_candidate:c1',
        ),
        now,
      ),
      isTrue,
    );
  });

  test('discovery is a first-class behavior candidate', () {
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'discover_interest', score: 0.72),
      ],
      thoughtsById: const <String, CompanionThought>{},
      recentIntentKinds: const <String>[],
      now: now,
    )!;
    expect(result.behaviorKind, 'public_web_discovery');
  });

  test('wait is a first-class non-action candidate', () {
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'wait', score: 0.76),
        _intent(action: 'ask_user', score: 0.60),
      ],
      thoughtsById: const <String, CompanionThought>{},
      recentIntentKinds: const <String>[],
      now: now,
    )!;
    expect(result.behaviorKind, 'wait');
    expect(result.selectedOriginalScore, 0.76);
  });

  test('rest remains a real winner inside shared competition', () {
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        DesireIntent(
          drive: DriveKey.fatigue,
          score: 0.78,
          reason: 'sleep pressure',
          wantAction: 'rest',
          reasonSource: 'drive_state',
        ),
        _intent(action: 'ask_user', score: 0.77),
      ],
      thoughtsById: const <String, CompanionThought>{},
      recentIntentKinds: const <String>['gentle_ping'],
      now: now,
      samplingUnit: 0.99,
    )!;
    expect(result.behaviorKind, 'rest');
  });

  test('recent discovery cooldown lets a message win', () {
    final thought = _thought(
      id: 'fresh',
      strength: 0.70,
      source: 'self_drive/local',
      topicKey: 'fresh.topic',
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'discover_interest', score: 0.78),
        _intent(action: 'ask_user', score: 0.68, thought: thought),
      ],
      thoughtsById: <String, CompanionThought>{thought.id: thought},
      recentIntentKinds: const <String>[],
      recentBehaviors: <Map<String, Object?>>[
        <String, Object?>{
          'behavior_kind': 'public_web_discovery',
          'source_type': 'drive_state',
          'intent_kind': 'curiosity',
          'topic_hash': '',
          'status': 'completed',
          'started_at':
              now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
        },
      ],
      now: now,
    )!;
    expect(result.behaviorKind, 'proactive_message');
    expect(result.intent.thoughtId, thought.id);
  });

  test('completed visible action blocks the same visible topic', () {
    final repeated = _thought(
      id: 'repeat',
      strength: 0.80,
      source: 'internal',
      topicKey: 'old.topic',
    );
    final hash = sha256.convert(utf8.encode('old.topic')).toString();
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'ask_user', score: 0.82, thought: repeated),
      ],
      thoughtsById: <String, CompanionThought>{repeated.id: repeated},
      recentIntentKinds: const <String>[],
      recentBehaviors: <Map<String, Object?>>[
        <String, Object?>{
          'behavior_kind': 'public_web_share',
          'source_type': 'public_web',
          'intent_kind': 'social_share',
          'topic_hash': '',
          'status': 'completed',
          'started_at':
              now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        },
        <String, Object?>{
          'behavior_kind': 'proactive_message',
          'source_type': 'internal',
          'intent_kind': 'curiosity',
          'topic_hash': hash,
          'status': 'completed',
          'started_at':
              now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
        },
      ],
      now: now,
    )!;
    expect(result.cooldownPenalty, 1.0);
    expect(result.intent.score, 0.0);
  });

  test('blocked message does not pretend the topic was handled', () {
    final repeated = _thought(
      id: 'blocked-repeat',
      strength: 0.80,
      source: 'internal',
      topicKey: 'presence:phone_activity',
    );
    final hash =
        sha256.convert(utf8.encode('presence:phone_activity')).toString();
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'ask_user', score: 0.82, thought: repeated),
      ],
      thoughtsById: <String, CompanionThought>{repeated.id: repeated},
      recentIntentKinds: const <String>[],
      recentBehaviors: <Map<String, Object?>>[
        <String, Object?>{
          'behavior_kind': 'proactive_message',
          'source_type': 'internal',
          'intent_kind': 'curiosity',
          'topic_hash': hash,
          'status': 'blocked',
          'started_at':
              now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
        },
      ],
      now: now,
    )!;
    expect(result.cooldownPenalty, 0.0);
    expect(result.intent.score, 0.82);
  });

  test('completed rest does not suppress a later drive message', () {
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'check_in', score: 0.72),
      ],
      thoughtsById: const <String, CompanionThought>{},
      recentIntentKinds: const <String>[],
      recentBehaviors: <Map<String, Object?>>[
        <String, Object?>{
          'behavior_kind': 'rest',
          'source_type': 'drive_state',
          'intent_kind': 'gentle_ping',
          'topic_hash': sha256.convert(utf8.encode('drive_state')).toString(),
          'status': 'completed',
          'started_at':
              now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
        },
      ],
      now: now,
    )!;
    expect(result.cooldownPenalty, 0.0);
    expect(result.intent.score, 0.72);
  });

  test('visible delivery does not hard-block quiet discovery of same topic', () {
    final topic = _thought(
      id: 'quiet-discovery',
      strength: 0.80,
      source: 'self_drive/local',
      topicKey: 'shared.topic',
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'discover_interest', score: 0.78, thought: topic),
      ],
      thoughtsById: <String, CompanionThought>{topic.id: topic},
      recentIntentKinds: const <String>[],
      recentBehaviors: <Map<String, Object?>>[
        <String, Object?>{
          'behavior_kind': 'proactive_message',
          'source_type': 'drive_state',
          'intent_kind': 'attachment',
          'topic_hash':
              sha256.convert(utf8.encode('shared.topic')).toString(),
          'status': 'completed',
          'started_at':
              now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        },
      ],
      now: now,
    )!;
    expect(result.behaviorKind, 'public_web_discovery');
    expect(result.cooldownPenalty, 0.0);
    expect(result.intent.score, 0.78);
  });

  test('delivery keeps original motive strength after selection downrank', () {
    final result = ProactiveSelectionPolicy.select(
      candidates: <DesireIntent>[
        _intent(action: 'ask_user', score: 0.82),
      ],
      thoughtsById: const <String, CompanionThought>{},
      recentIntentKinds: const <String>['curiosity'],
      now: now,
    )!;
    expect(result.intent.score, lessThan(0.82));
    expect(result.selectedOriginalScore, 0.82);
  });
}
