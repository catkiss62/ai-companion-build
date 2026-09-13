import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';

void main() {
  test('legacy solo activity becomes a due committed continuation', () {
    final session = CedarGameSession.fromJson(<String, Object?>{
      'id': 'legacy-fishing',
      'game_id': 'fishing',
      'guide': 'actions: cast, status',
      'guide_complete': true,
      'mode': 'solo',
      'phase': 'active',
      'next_actor': 'companion',
      'updated_at': 1,
    });

    expect(session.companionCanContinue, isTrue);
    expect(session.nextActionAt, isNull);
  });

  test('multi-game state preserves fishing while duel becomes active', () {
    CedarGameSession session(String game, CedarParticipationMode mode) =>
        CedarGameSession(
          id: game,
          gameId: game,
          guide: 'real guide for $game',
          guideComplete: true,
          mode: mode,
          phase: CedarActivityPhase.active,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        );

    final decoded = CedarToyActivityState.fromJson(
      CedarToyActivityState(
        activeGameId: 'duel',
        sessions: <String, CedarGameSession>{
          'fishing': session('fishing', CedarParticipationMode.solo),
          'duel': session('duel', CedarParticipationMode.coPlay),
        },
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ).toJson(),
    );

    expect(decoded.sessions.keys, containsAll(<String>['fishing', 'duel']));
    expect(decoded.activeSession?.gameId, 'duel');
    expect(decoded.hasUserTurnContinuation, isTrue);
  });

  test('real fishing reminder is parsed as a generic cross-game reference', () {
    final references = CedarToyActivityStore.crossGameReferences(
      '【双弈提醒】请调用 play(game="duel",action="rooms") 查看房间。',
    );

    expect(references, hasLength(1));
    expect(references.single.gameId, 'duel');
    expect(references.single.action, 'rooms');
  });

  test('a catalog title triggers Cedar without hardcoding a game name', () {
    const catalog =
        '小游戏: turtle_soup·海龟汤横向思维推理·作者 | duel·双弈，25款棋牌骰对弈·作者';
    expect(
      CedarToyActivityStore.catalogMentionsGame('快来双弈玩五子棋', catalog),
      isTrue,
    );
    expect(
      CedarToyActivityStore.catalogMentionsGame('今天随便聊聊', catalog),
      isFalse,
    );
  });

  test('a timed remote wait remains a background-continuable activity', () {
    final session = CedarGameSession(
      id: 'fishing-wait',
      gameId: 'fishing',
      guide: 'wait and then check status',
      guideComplete: true,
      mode: CedarParticipationMode.solo,
      phase: CedarActivityPhase.waitingRemote,
      nextActor: 'wait',
      nextActionAt: DateTime.fromMillisecondsSinceEpoch(2000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(session.companionCanContinue, isTrue);
  });
}
