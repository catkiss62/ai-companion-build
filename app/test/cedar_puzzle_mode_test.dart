import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CedarToyActivityStore store;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CedarToyActivityStore(db);
  });
  tearDown(() => db.closeForTesting());

  test(
    'old hybrid progress becomes playable without restarting the puzzle',
    () async {
      final guide = await store.recordGuide(
        gameId: 'puzzle_box',
        guide: 'open progress submit',
      );
      final legacy = guide.copyWith(
        mode: CedarParticipationMode.hybrid,
        phase: CedarActivityPhase.waitingUser,
        nextActor: 'user',
        lastAction: 'progress',
        lastOutcome: '当前已开题，进度保留',
        clearNextActionAt: true,
      );
      await store.save(legacy);
      final loaded = (await store.load())!;
      expect(loaded.mode, CedarParticipationMode.puzzle);
      expect(loaded.id, guide.id);
      expect(loaded.lastOutcome, legacy.lastOutcome);
      expect(loaded.companionCanContinue, isTrue);
    },
  );

  test(
    'stored preference, structured human turn and limited investigation cadence',
    () async {
      await store.recordGuide(
        gameId: 'memoria',
        guide: 'look talk clues accuse',
      );
      Future<CedarGameSession> play(
        String actor, {
        String goal = '案发时间',
        bool explicit = false,
      }) => store.recordPlay(
        gameId: 'memoria',
        action: 'look',
        mode: CedarParticipationMode.hybrid,
        submittedParams: {'target': goal},
        investigationGoal: goal,
        nextActor: actor,
        invitationApproved: false,
        shareLevel: 'quiet',
        outcome: McpToolOutcome(
          isError: false,
          content: const [
            McpContentBlock(kind: McpContentKind.text, text: '获得一条新的证词'),
          ],
          structuredContent: explicit ? {'next_actor': actor} : null,
        ),
      );
      for (final step in [1, 2, 3]) {
        final result = await play('user');
        expect(result.nextActor, 'companion');
        expect(result.puzzle.steps, step);
        expect(
          result.nextActionAt!.difference(result.updatedAt).inSeconds,
          step == 3 ? 120 : 1,
        );
      }
      final realTurn = await play('user', explicit: true);
      expect(realTurn.nextActor, 'user');
      expect((await store.load())!.canRecheckTurn, isFalse);
      expect(await store.selectPlayMode(realTurn), isFalse);
      expect(await store.selectPlayMode(realTurn, preference: 'solo'), isTrue);
      expect((await store.load())!.nextActor, 'user');
      expect((await store.load())!.mode, CedarParticipationMode.solo);
      expect(await db.getSetting('cedar_play_mode_memoria'), 'solo');
    },
  );

  test(
    'local help is atomic, idempotent, and distinct from asking the game host',
    () async {
      final s = await store.recordGuide(
        gameId: 'soup',
        guide: 'ask host questions',
      );
      expect(s.mode, CedarParticipationMode.puzzle);
      expect(
        CedarPuzzleState.revealsSolution(s.mode, 'ask', {'text': '有关系吗'}),
        isFalse,
      );
      expect(
        CedarPuzzleState.revealsSolution(s.mode, 'submit', {'answer': '猜测'}),
        isFalse,
      );
      expect(
        CedarPuzzleState.revealsSolution(s.mode, 'cmd', {
          'command': 'show_solution',
        }),
        isTrue,
      );
      final execution = await store.beginExecution(
        gameId: 'soup',
        action: '规划',
      );
      const question = '两种解释都行得通，给主人看一下的话，你能给我一点方向吗？';
      expect(
        await store.savePuzzleChoice(
          s,
          executionId: 'stale',
          text: question,
          ask: true,
        ),
        isFalse,
      );
      expect(
        await store.savePuzzleChoice(
          s,
          executionId: execution,
          text: question,
          ask: true,
        ),
        isTrue,
      );
      expect(
        await store.savePuzzleChoice(
          s,
          executionId: execution,
          text: question,
          ask: true,
        ),
        isFalse,
      );
      await store.finishExecution(executionId: execution);
      final wait = (await store.load())!;
      final sql = await db.database;
      expect(
        (await sql.query(
          'messages',
          where: 'id=?',
          whereArgs: [wait.puzzle.questionId],
        )).single['content'],
        question,
      );
      expect(wait.phase, CedarActivityPhase.waitingUser);
      await store.rememberUserAdvice(
        '再自己想想',
        answeredQuestion: wait.puzzle.questionId,
      );
      final resumed = (await store.load())!;
      expect(resumed.puzzle.note, '再自己想想');
      expect(resumed.companionCanContinue, isTrue);
      expect(resumed.puzzle.questionId, isEmpty);
      final exec2 = await store.beginExecution(gameId: 'soup', action: '规划');
      expect(
        await store.savePuzzleChoice(
          resumed,
          executionId: exec2,
          text: '先留题；下次查时间',
          ask: false,
        ),
        isTrue,
      );
      expect((await sql.query('messages')).length, 1);
      final saved =
          jsonDecode(
                (await db.getSetting(CedarToyActivityStore.stateSettingKey))!,
              )
              as Map;
      expect(saved.toString(), contains('先留题'));
    },
  );
}
