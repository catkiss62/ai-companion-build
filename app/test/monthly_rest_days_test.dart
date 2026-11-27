import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/memory/monthly_rest_days.dart';
import 'package:ai_companion_localfirst/core/memory/remembered_user_facts.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/features/memory/monthly_rest_days_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
  });

  test(
    'month boundaries, invalid data, empty confirmation and reset',
    () async {
      final feb = DateTime(2028, 2, 29, 23, 59);
      final mar = DateTime(2028, 3, 1);
      expect((await MonthlyRestDays.read(db, feb)).days, isNull);
      await MonthlyRestDays(feb, [29, 2, 2]).save(db);
      expect((await MonthlyRestDays.read(db, feb)).days, [2, 29]);
      expect((await MonthlyRestDays.read(db, mar)).days, isNull);
      await MonthlyRestDays(mar, []).save(db);
      expect((await MonthlyRestDays.read(db, mar)).days, isEmpty);
      await db.setSetting(MonthlyRestDays(feb, null).key, '[30]');
      expect((await MonthlyRestDays.read(db, feb)).days, isNull);
      await MonthlyRestDays(mar, null).save(db);
      expect((await MonthlyRestDays.read(db, mar)).days, isNull);
      expect(
        MonthlyRestDays(DateTime(2028, 12), null).key,
        isNot(MonthlyRestDays(DateTime(2029, 1), null).key),
      );
    },
  );

  test(
    'normal and proactive prompts place roster immediately after manual facts',
    () async {
      await RememberedUserFactsStore(db).save(
        const RememberedUserFacts([
          RememberedUserFact(subject: '早餐', content: '八点'),
        ]),
      );
      final date = DateTime(2028, 2, 10, 12);
      await MonthlyRestDays(date, [3, 18]).save(db);
      for (final mode in PromptGenerationMode.values) {
        final prompt = await PromptBuilder(db).buildChatPrompt(
          latestUserText: '今天休息吗',
          recent: [],
          desire: DesireSnapshot(),
          thoughts: [],
          mode: mode,
          now: date,
          nsfwActive: false,
          nsfwReferenceActive: false,
        );
        final messages = prompt.messages
            .map((m) => m['content'].toString())
            .toList();
        final facts = messages.indexWhere((s) => s.contains('用户明确保存的日常事实'));
        expect(facts, greaterThan(0));
        expect(messages[facts + 1], contains('3、18 日'));
      }
    },
  );

  test(
    'disabled roster omits both unknown and saved schedules from both chat modes',
    () async {
      final date = DateTime(2028, 2, 11);
      expect(await MonthlyRestDays.enabled(db), isTrue);
      await MonthlyRestDays.setEnabled(db, false);
      for (final selected in [
        null,
        <int>[],
        [4, 22],
      ]) {
        await MonthlyRestDays(date, selected).save(db);
        for (final mode in PromptGenerationMode.values) {
          final built = await PromptBuilder(db).buildChatPrompt(
            latestUserText: '今天休息吗',
            recent: [],
            desire: DesireSnapshot(),
            thoughts: [],
            mode: mode,
            now: date,
            nsfwActive: false,
            nsfwReferenceActive: false,
          );
          expect(
            built.messages.map((m) => m['content']).join(),
            isNot(contains('用户手动登记的月度排班')),
          );
        }
      }
      expect((await MonthlyRestDays.read(db, date)).days, [4, 22]);
      expect(await MonthlyRestDays.forPrompt(db, DateTime(2028, 3)), isNull);
      await MonthlyRestDays.setEnabled(db, true);
      expect((await MonthlyRestDays.forPrompt(db, date))!.days, [4, 22]);
      expect(
        (await MonthlyRestDays.forPrompt(db, DateTime(2028, 3)))!.days,
        isNull,
      );
    },
  );

  testWidgets('calendar keeps draft private until saved and permits reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MonthlyRestDaysCard(db)),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(
      (await tester.runAsync(
        () => MonthlyRestDays.read(db, DateTime.now()),
      ))!.days,
      isNull,
    );
    await tester.tap(find.text('保存本月排班'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(find.text('排班已确认 · 1 天休息'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(await tester.runAsync(() => MonthlyRestDays.enabled(db)), isFalse);
    expect(find.text('排班已确认 · 1 天休息'), findsOneWidget);
    await tester.tap(find.text('恢复为排班未知'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(find.textContaining('排班未知。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
