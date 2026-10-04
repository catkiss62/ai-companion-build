import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_delivery_budget.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/proactive_frequency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  var serial = 0;
  setUp(
    () async => db = await AppDatabase.createForTesting(databaseFactoryFfi),
  );
  tearDown(() async => db.closeForTesting());
  DateTime time(int hour, [int minute = 0, int day = 5]) =>
      DateTime(2026, 10, day, hour, minute);
  Future<void> history(
    DateTime at, {
    String decision = 'sent',
    String source = 'attachment:test',
  }) async {
    await (await db.database).insert('proactive_history', {
      'id': 'history-${serial++}',
      'trigger_reason': source,
      'decision': decision,
      'created_at': at.millisecondsSinceEpoch,
    });
  }

  Future<ProactiveDeliveryBudget> budget(
    DateTime at, [
    ProactiveFrequencyMode mode = ProactiveFrequencyMode.quiet,
  ]) async => ProactiveDeliveryBudget.read(await db.database, at, mode: mode);
  Future<String?> send(
    DateTime at, {
    DateTime? started,
    String? id,
    bool enforce = true,
    String reason = 'attachment:test',
  }) => db.commitProactiveMessageIfCurrent(
    message: ChatMessage(
      id: id ?? 'send-${serial++}',
      role: 'assistant',
      content: '具体的新想法',
      createdAt: at,
      isProactive: true,
    ),
    evaluationStartedAt: started ?? at,
    deliveryAt: at,
    proactiveTriggerReason: reason,
    enforceProactiveBudget: enforce,
  );

  for (final entry in {
    ProactiveFrequencyMode.quiet: [3, 6, 10],
    ProactiveFrequencyMode.natural: [6, 12, 18],
    ProactiveFrequencyMode.frequent: [8, 16, 24],
  }.entries) {
    test(
      '${entry.key.name} releases cumulative quotas at exact boundaries',
      () {
        final mode = entry.key;
        for (final hour in [0, 5, 8]) {
          expect(mode.releasedLimit(time(hour)), 2);
        }
        expect(mode.releasedLimit(time(9)), entry.value[0]);
        expect(mode.releasedLimit(time(13, 59)), entry.value[0]);
        expect(mode.releasedLimit(time(14)), entry.value[1]);
        expect(mode.releasedLimit(time(18, 59)), entry.value[1]);
        expect(mode.releasedLimit(time(19)), entry.value[2]);
        expect(mode.releasedLimit(time(23, 59)), entry.value[2]);
      },
    );
  }
  test('unused morning allowance carries forward without borrowing', () async {
    await history(time(9));
    expect((await budget(time(12))).remaining, 2);
    expect((await budget(time(14))).remaining, 5);
    expect((await budget(time(19))).remaining, 9);
    for (final hour in [10, 11]) {
      await history(time(hour));
    }
    expect((await budget(time(13))).blockReason(), 'daytime_window_ceiling');
    expect((await budget(time(14))).remaining, 3);
  });
  test(
    'mode switches reuse actual history, no refunds or negative balance',
    () async {
      for (final hour in [9, 10, 11, 12, 13]) {
        await history(time(hour));
      }
      expect(
        (await budget(time(16), ProactiveFrequencyMode.frequent)).remaining,
        11,
      );
      expect(
        (await budget(time(16), ProactiveFrequencyMode.natural)).remaining,
        7,
      );
      expect((await budget(time(16))).remaining, 1);
      for (final hour in [14, 15, 16, 17, 18, 19]) {
        await history(time(hour));
      }
      expect((await budget(time(23))).remaining, 0);
      expect((await budget(time(9, 0, 6))).remaining, 3);
    },
  );
  test(
    'day exhaustion does not consume night and night does not consume next day',
    () async {
      for (var i = 0; i < 10; i++) {
        await history(time(10 + i, 0, 4));
      }
      expect((await budget(time(0))).remaining, 2);
      await history(time(0));
      await history(time(5));
      expect((await budget(time(8))).blockReason(), 'night_contact_ceiling');
      expect((await budget(time(9))).remaining, 3);
      expect((await budget(time(9))).nightUsed, 2);
    },
  );
  test('failures WAIT and interrupted candidates never spend quota', () async {
    for (final status in [
      'wait',
      'reply_incomplete',
      'preempted_by_user',
      'minimum_gap',
    ]) {
      await history(time(10), decision: status);
    }
    expect((await budget(time(12))).used, 0);
    expect((await budget(time(12))).lastSentAt, isNull);
  });
  test(
    'background sources share quota; explicit game reports are separate',
    () async {
      await history(time(9), source: 'game_share:curiosity:outcome');
      await history(time(10), source: 'contemplation:reflection');
      await history(time(11), source: 'game_share:immediate:task_result');
      expect((await budget(time(13))).used, 2);
      expect((await budget(time(13))).lastSentAt, time(10));
    },
  );
  test(
    'physical cooldown and two-hour guard survive midnight and 09:00',
    () async {
      await history(time(23, 55, 4));
      expect((await budget(time(0))).remaining, 2);
      expect((await budget(time(0))).blockReason(), 'minimum_gap');
      await history(time(8, 55));
      expect((await budget(time(9))).blockReason(), 'minimum_gap');
      await history(time(7, 45));
      expect((await budget(time(9, 30))).blockReason(), 'short_window_ceiling');
    },
  );
  test('successful commit atomically records a single send', () async {
    expect(await send(time(10), id: 'one'), isNull);
    expect((await db.messageById('one'))?.isProactive, isTrue);
    expect((await budget(time(11))).used, 1);
    expect(await send(time(10, 1)), 'minimum_gap');
    expect((await budget(time(11))).used, 1);
  });
  test(
    'concurrent final candidates cannot spend the final slot twice',
    () async {
      await history(time(0));
      final results = await Future.wait([send(time(4)), send(time(4))]);
      expect(results.where((v) => v == null).length, 1);
      expect((await budget(time(6))).nightUsed, 2);
    },
  );
  test('profile is re-read at final commit after generation', () async {
    for (final hour in [9, 10, 11]) {
      await history(time(hour));
    }
    await db.setSetting(ProactiveFrequencyPolicy.settingKey, 'frequent');
    expect(
      (await ProactiveDeliveryBudget.read(
        await db.database,
        time(13),
      )).remaining,
      5,
    );
    await db.setSetting(ProactiveFrequencyPolicy.settingKey, 'quiet');
    expect(await send(time(13)), 'daytime_window_ceiling');
    expect((await budget(time(13))).used, 3);
  });
  test(
    'midnight and 09:00 discard stale context; 14:00 releases naturally',
    () async {
      expect(
        await send(time(0), started: time(23, 59, 4)),
        'proactive_window_changed',
      );
      expect(
        await send(time(9), started: time(8, 59)),
        'proactive_window_changed',
      );
      expect((await budget(time(12))).used, 0);
      expect(await send(time(14), started: time(13, 59)), isNull);
    },
  );
  test('active-brain and user preemption never leave quota evidence', () async {
    await db.setSetting('active_brain', '0');
    expect(await send(time(10)), 'inactive_brain');
    await db.setSetting('active_brain', '1');
    await db.insertMessage(
      ChatMessage(
        id: 'user',
        role: 'user',
        content: '等一下',
        createdAt: time(10, 1),
      ),
    );
    expect(await send(time(10, 2), started: time(10)), 'new_user');
    expect((await budget(time(12))).used, 0);
  });
  test(
    'failed message insert rolls back quota; requested game remains deliverable',
    () async {
      expect(await send(time(10), id: 'same'), isNull);
      await expectLater(
        send(time(13), id: 'same'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await budget(time(14))).used, 1);
      expect(
        await send(
          time(10, 1),
          enforce: false,
          reason: 'game_share:immediate:result',
        ),
        isNull,
      );
      expect((await budget(time(14))).used, 1);
    },
  );
  test(
    'export and restore preserve sent evidence without a reset counter',
    () async {
      expect(await send(time(10)), isNull);
      final backup = await db.exportAll();
      await db.importAll(backup);
      expect((await budget(time(12))).used, 1);
      expect((await budget(time(12), ProactiveFrequencyMode.frequent)).used, 1);
    },
  );
}
