import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_live_share_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CedarToyActivityStore store;
  late CedarLiveSharePolicy shares;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CedarToyActivityStore(db);
    shares = CedarLiveSharePolicy(db);
    await store.recordGuide(
      gameId: 'white_room',
      guide: '单人 explore state get_result wait',
    );
  });
  tearDown(() => db.closeForTesting());
  Future<CedarGameSession> step(
    int n, {
    String action = 'explore',
    bool failed = false,
    int resume = 0,
  }) => store.recordPlay(
    gameId: 'white_room',
    action: action,
    outcome: McpToolOutcome(
      isError: failed,
      content: [McpContentBlock(kind: McpContentKind.text, text: '实际发现$n')],
    ),
    mode: CedarParticipationMode.solo,
    nextActor: 'companion',
    shareLevel: 'quiet',
    invitationApproved: false,
    resumeAfterSeconds: resume,
  );
  Future<void> deliver(String id) async {
    await db.insertMessage(
      ChatMessage(
        id: 'cedar-share:$id',
        role: 'assistant',
        content: '实际分享',
        createdAt: DateTime.now(),
      ),
    );
    await shares.noteDelivered(id);
    await store.removeDirectShare(id);
  }

  test(
    'legacy speed keys migrate to five; equal cadence persists outside viewer',
    () async {
      for (final old in ['leisure', 'fast', 'spectate']) {
        await db.setSetting(CedarToyActivityStore.viewingPaceSettingKey, old);
        expect((await store.currentViewingPace()).shareRounds, 5);
      }
      await store.setViewingPace(CedarViewingPace.spectate);
      await store.endViewing();
      await store.beginViewing();
      expect((await store.currentViewingPace()).shareRounds, 10);
      for (final pace in CedarViewingPace.values) {
        expect(pace.soloStepGap, const Duration(minutes: 2));
        expect(pace.isWatching, false);
      }
      final session = await step(1, resume: 5);
      expect(
        session.nextActionAt!.difference(session.updatedAt),
        const Duration(minutes: 2),
      );
    },
  );

  test('default five counts only successful game mutations; quiet alone never forces a reply', () async {
    for (var n = 1; n <= 4; n++) {
      await shares.offer(await step(n), share: true, now: DateTime.now());
    }
    expect(await store.pendingDirectShares(), isEmpty);
    for (final action in ['state', 'get_result', 'wait']) {
      await step(0, action: action);
    }
    await step(0, failed: true);
    expect((await store.loadState()).completedPlayRounds, 4);
    expect(await shares.intervalElapsed(), false);
    final fifth = await step(5);
    await shares.offer(fifth, share: false, now: DateTime.now());
    expect(await store.pendingDirectShares(), isEmpty);
    await shares.offer(fifth, share: true, now: DateTime.now());
    final id = (await store.pendingDirectShares()).single;
    final text = (await db.thoughtById(id))!.text;
    for (var n = 1; n <= 5; n++) {
      expect(text, contains('实际发现$n'));
    }
  });

  test('ordinary proactive message IDs acknowledge the same share interval idempotently', () async {
    for (var n = 1; n <= 5; n++) {
      await step(n);
    }
    await shares.offer((await store.load())!, share: true, now: DateTime.now());
    final id = (await store.pendingDirectShares()).single;
    await shares.noteDelivered(id, messageId: 'not-committed');
    expect(await shares.intervalElapsed(), true);
    await db.insertMessage(ChatMessage(id: 'ordinary-proactive-id',
      role: 'assistant', content: '实际分享', createdAt: DateTime.now()));
    await shares.noteDelivered(id, messageId: 'ordinary-proactive-id');
    expect(await shares.intervalElapsed(), false);
    for (var n = 6; n <= 9; n++) {
      await step(n);
    }
    await shares.noteDelivered(id, messageId: 'ordinary-proactive-id');
    expect(await shares.intervalElapsed(), false);
    await step(10);
    expect(await shares.intervalElapsed(), true);
  });

  test('legacy ordinary progress settles only its own saved event', () async {
    for (var n = 1; n <= 5; n++) {
      await step(n);
    }
    final session = (await store.load())!;
    await db.upsertThought(id: 'legacy-progress', text: '实际发现5',
      drive: DriveKey.curiosity, kind: 'flit', strength: .8,
      source: 'mcp/cedar_game:white_room:${session.events.last.id}');
    await db.insertMessage(ChatMessage(id: 'ordinary-legacy-message',
      role: 'assistant', content: '实际发现5', createdAt: DateTime.now()));
    await shares.noteDelivered('legacy-progress', messageId: 'ordinary-legacy-message');
    for (var n = 6; n <= 10; n++) {
      await step(n);
    }
    await shares.offer((await store.load())!, share: true, now: DateTime.now());
    final id = (await store.pendingDirectShares()).single;
    expect((await db.thoughtById(id))!.text, isNot(contains('实际发现5')));
    expect((await db.thoughtById(id))!.text, contains('实际发现6'));
  });

  test('actual delivery starts next interval; pending writer aggregation is frozen once', () async {
    for (var n = 1; n <= 5; n++) {
      await step(n);
    }
    await shares.offer((await store.load())!, share: true, now: DateTime.now());
    final id = (await store.pendingDirectShares()).single;
    await step(6);
    await step(7);
    await shares.refreshPending(id);
    expect((await db.thoughtById(id))!.text, contains('实际发现7'));
    await deliver(id);
    for (var n = 8; n <= 11; n++) {
      await shares.offer(await step(n), share: true, now: DateTime.now());
    }
    expect(await store.pendingDirectShares(), isEmpty);
    await shares.noteDelivered(
      id,
    ); // Recovery of an already committed message is idempotent.
    final next = await step(12);
    await shares.offer(next, share: true, now: DateTime.now());
    final nextId = (await store.pendingDirectShares()).single;
    expect((await db.thoughtById(nextId))!.text, isNot(contains('实际发现7')));
    expect((await db.thoughtById(nextId))!.text, contains('实际发现8'));
  });

  test(
    'ten-round batch retains the first discovery instead of only last six',
    () async {
      await store.setViewingPace(CedarViewingPace.spectate);
      for (var n = 1; n <= 10; n++) {
        await shares.offer(await step(n), share: n == 10, now: DateTime.now());
      }
      final id = (await store.pendingDirectShares()).single;
      final text = (await db.thoughtById(id))!.text;
      expect(text, contains('实际发现1'));
      expect(text, contains('实际发现10'));
      expect(
        CedarLiveSharePolicy.evidence(
          (await store.load())!,
          DateTime.now(),
        ).length,
        10,
      );
    },
  );

  test(
    'expired pending thought cannot permanently block later discoveries',
    () async {
      for (var n = 1; n <= 5; n++) {
        await step(n);
      }
      await shares.offer(
        (await store.load())!,
        share: true,
        now: DateTime.now(),
      );
      final stale = (await store.pendingDirectShares()).single;
      await (await db.database).update(
        'thoughts',
        {'lifecycle_state': 'archived'},
        where: 'id = ?',
        whereArgs: [stale],
      );
      await shares.offer(await step(6), share: true, now: DateTime.now());
      final replacement = (await store.pendingDirectShares()).single;
      expect(replacement, isNot(stale));
      expect((await db.thoughtById(replacement))!.text, contains('实际发现1'));
      expect((await db.thoughtById(replacement))!.text, contains('实际发现6'));
    },
  );

  test('delivered result settles old queued progress but preserves newer resumed events', () async {
    for (var n = 1; n <= 5; n++) {
      await step(n);
    }
    await shares.offer((await store.load())!, share: true, now: DateTime.now());
    final old = (await store.pendingDirectShares()).single;
    final cutoff = (await db.thoughtById(old))!.bornAt;
    // Report rows use milliseconds but the covered game result retains
    // microseconds in the same recorded millisecond.
    final covered = (await store.load())!;
    await store.save(
      covered.copyWith(
        events: covered.events
            .map(
              (event) => event.id != covered.events.last.id
                  ? event
                  : CedarGameEvent(
                      id: event.id,
                      kind: event.kind,
                      action: event.action,
                      summary: event.summary,
                      createdAt: cutoff.add(const Duration(microseconds: 500)),
                    ),
            )
            .toList(),
      ),
    );
    await db.upsertThought(
      id: 'cedar-report:task',
      text: '实际结束结果',
      drive: DriveKey.curiosity,
      kind: 'flit',
      strength: .96,
      bornAt: cutoff,
      source: 'mcp/cedar_game:white_room:task:task',
    );
    await store.queueDirectShare('cedar-report:task');
    final later = await step(6);
    // Ensure the resumed event is strictly later than the report cutoff.
    final adjusted = later.copyWith(
      events: later.events
          .map(
            (event) => event.id != later.events.last.id
                ? event
                : CedarGameEvent(
                    id: event.id,
                    kind: event.kind,
                    action: event.action,
                    summary: event.summary,
                    createdAt: cutoff.add(const Duration(seconds: 1)),
                  ),
          )
          .toList(),
    );
    await store.save(adjusted);
    await deliver('cedar-report:task');
    expect(await store.pendingDirectShares(), isEmpty);
    await shares.offer(
      adjusted,
      share: true,
      now: cutoff.add(const Duration(seconds: 2)),
    );
    final next = (await store.pendingDirectShares()).single;
    expect((await db.thoughtById(next))!.text, contains('实际发现6'));
    expect((await db.thoughtById(next))!.text, isNot(contains('实际发现5')));
  });

  test('one round remains a minimum, config changes also gate pending shares; reports bypass', () async {
    await store.setViewingPace(CedarViewingPace.fast);
    final session = await step(1);
    await shares.offer(session, share: false, now: DateTime.now());
    expect(await store.pendingDirectShares(), isEmpty);
    await shares.offer(session, share: true, now: DateTime.now());
    final id = (await store.pendingDirectShares()).single;
    final source = (await db.thoughtById(id))!.source;
    final day = DateTime.now();
    final daytime = DateTime(day.year, day.month, day.day, 12);
    expect(await shares.deliveryAllowed(id, source, now: daytime), true);
    await store.setViewingPace(CedarViewingPace.spectate);
    expect(await shares.deliveryAllowed(id, source, now: daytime), false);
    await db.setSetting('cedar_toy_game_share_enabled', '0');
    expect(
      await shares.deliveryAllowed(
        'cedar-report:task',
        'mcp/cedar_game:white_room:task:task',
      ),
      true,
    );
    expect(
      await shares.deliveryAllowed(
        'cedar-terminal:event',
        'mcp/cedar_game:white_room:terminal:event',
        now: daytime,
      ),
      true,
    );
    final state = jsonDecode(
      (await db.getSetting(CedarToyActivityStore.stateSettingKey))!,
    );
    expect(state['completed_play_rounds'], 1);
  });
}
