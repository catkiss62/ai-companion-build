import 'package:ai_companion_localfirst/core/autonomy/subjective_search_seed.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/somatic_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8, 8);
  final snapshot = DesireSnapshot(
    drives: <DriveKey, double>{
      ...DesireSnapshot.defaultDrives(),
      DriveKey.curiosity: 0.68,
      DriveKey.social: 0.55,
    },
    baselines: DesireSnapshot.defaultBaselines(),
  );
  const privateText = '用户小明刚才在私人聊天里说了银行卡密码123456';
  final thought = CompanionThought(
    id: 'thought-1',
    text: privateText,
    driveKey: DriveKey.curiosity.name,
    kind: 'flit',
    strength: 0.72,
    bornAt: now.subtract(const Duration(minutes: 4)),
    updatedAt: now,
    source: 'conversation_turn:private-message',
  );
  const intent = DesireIntent(
    drive: DriveKey.curiosity,
    score: 0.78,
    reason: privateText,
    wantAction: 'discover_interest',
    thoughtId: 'thought-1',
    reasonSource: 'conversation_turn:private-message',
  );

  test('seed is deterministic and excludes raw private thought content', () {
    final first = SubjectiveSearchSeedPolicy.build(
      snapshot: snapshot,
      intent: intent,
      thoughts: <CompanionThought>[thought],
      emotions: const [],
      somatic: const [],
      now: now,
    );
    final second = SubjectiveSearchSeedPolicy.build(
      snapshot: snapshot,
      intent: intent,
      thoughts: <CompanionThought>[thought],
      emotions: const [],
      somatic: const [],
      now: now,
    );
    final exported = first.toPlannerJson().toString();

    expect(first.seedHash, second.seedHash);
    expect(first.seedHash, hasLength(64));
    expect(exported, isNot(contains(privateText)));
    expect(exported, isNot(contains('小明')));
    expect(exported, isNot(contains('123456')));
    expect(first.sourceKinds, contains('thought:user_message'));
    expect(first.questionDirection, contains('反直觉'));
  });

  test('somatic category changes direction without exporting narrative', () {
    final seed = SubjectiveSearchSeedPolicy.build(
      snapshot: snapshot,
      intent: intent,
      thoughts: <CompanionThought>[thought],
      emotions: const [],
      somatic: <SomaticAggregate>[
        SomaticAggregate(
          channel: SomaticChannel.sound,
          value: 0.66,
          sceneKey: 'private-scene',
          narrative: '这段私人身体叙述不应进入搜索',
          lastEventId: 'event-1',
          updatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ],
      now: now,
    );
    final exported = seed.toPlannerJson().toString();

    expect(seed.motiveKind, 'sensory_curiosity');
    expect(seed.questionDirection, contains('声音与听觉'));
    expect(exported, isNot(contains('私人身体叙述')));
    expect(exported, isNot(contains('private-scene')));
  });
}
