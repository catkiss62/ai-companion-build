import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_turn_state_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity window exposes the exact temporary solo pace contract', () {
    expect(CedarViewingPace.leisure.soloStepGap, const Duration(minutes: 2));
    expect(CedarViewingPace.fast.soloStepGap, const Duration(seconds: 5));
    expect(CedarViewingPace.spectate.soloStepGap, const Duration(seconds: 10));
    expect(CedarViewingPace.leisure.isWatching, isFalse);
    expect(CedarViewingPace.fast.isWatching, isTrue);
    expect(CedarViewingPace.spectate.isWatching, isTrue);
    expect(CedarViewingPace.fromKey('unknown'), CedarViewingPace.leisure);
  });

  test('solo companion turn remains a continuable autonomous activity', () {
    final session = CedarGameSession(
      id: 'solo-session',
      gameId: 'fishing',
      guide: 'real guide',
      guideComplete: true,
      mode: CedarParticipationMode.solo,
      phase: CedarActivityPhase.active,
      nextActor: 'companion',
      nextActionAt: DateTime.fromMillisecondsSinceEpoch(2000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(session.companionCanContinue, isTrue);
    expect(session.needsContinuation, isTrue);
  });

  test('explicit Cedar structured turn ownership stays authoritative', () {
    final resolved = McpTurnStateResolver.resolveStructured(
      <String, Object?>{
        'status': 'playing',
        'next_actor': 'assistant',
      },
    );

    expect(resolved?.nextActor, 'companion');
    expect(resolved?.reason, 'structured_next_actor');
  });

  test('explicit Cedar resume cadence is consumed without reinterpretation', () {
    final seconds = McpResumeAfterResolver.resolveStructured(
      <String, Object?>{
        'state': <String, Object?>{'resume_after_seconds': 7},
      },
    );

    expect(seconds, 7);
  });
}
