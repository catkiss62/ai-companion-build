import 'dart:convert';
import 'package:ai_companion_localfirst/features/phone/simulated_phone_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/phone/phone_history_store.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_repository.dart';

Map<String, Object?> item(String kind, int index, {String day = '2026-11-01'}) => {
  'id': '$kind:$index', 'kind': kind, 'title': 'entry $index', 'body': 'body $index',
  'local_day': day, 'created_at': 1700000000000 + index, 'provenance': 'test',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() => db.closeForTesting());

  test('migration keeps full legacy history and repeated reads do not duplicate it', () async {
    await db.setSetting('simulated_phone_diary_json', jsonEncode(List.generate(185, (i) => item('diary', i))));
    await db.setSetting('simulated_phone_notes_json', jsonEncode(List.generate(305, (i) => item('note', i))));
    final sql = await db.database;
    await PhoneHistoryStore.migrate(sql); await PhoneHistoryStore.migrate(sql);
    final rows = await sql.rawQuery('SELECT COUNT(*) AS n FROM settings WHERE key >= ? AND key < ?',
      [PhoneHistoryStore.prefix, '${PhoneHistoryStore.prefix}~']);
    expect(rows.single['n'], 490);
    final first = await PhoneHistoryStore.page(sql, day: '2026-11-01', limit: 50);
    final second = await PhoneHistoryStore.page(sql, day: '2026-11-01', offset: 50, limit: 50);
    expect(first, hasLength(50)); expect(second, hasLength(50));
    expect(first.map((e) => e['id']).toSet().intersection(second.map((e) => e['id']).toSet()), isEmpty);
    expect(await PhoneHistoryStore.page(sql, day: '2026-11-02'), isEmpty);
  });

  test('malformed migration rolls back all inserts and does not set completion', () async {
    await db.setSetting('simulated_phone_diary_json', jsonEncode([item('diary', 1)]));
    await db.setSetting('simulated_phone_notes_json', '{broken');
    final sql = await db.database;
    await expectLater(PhoneHistoryStore.migrate(sql), throwsFormatException);
    expect(await db.getSetting(PhoneHistoryStore.migrationKey), isNull);
    expect(await PhoneHistoryStore.contains(sql, 'diary', 'diary:1'), false);
    expect(await db.getSetting('simulated_phone_notes_json'), '{broken');
  });

  test('history and diary media survive recent projection replacement and backup round trip', () async {
    final original = item('diary', 1);
    await db.setSetting('simulated_phone_diary_json', jsonEncode([original]));
    await db.setSetting('illustration_diary_media:diary:1', 'existing-media-reference');
    await PhoneHistoryStore.migrate(await db.database);
    await db.setSetting('simulated_phone_diary_json', '[]');
    await db.setSettingsAtomically(PhoneHistoryStore.values(item('diary', 2, day: '2026-11-02')));
    final backup = await db.exportAll();
    final restored = await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      await restored.importAll(backup);
      final sql = await restored.database;
      await PhoneHistoryStore.migrate(sql);
      expect((await PhoneHistoryStore.page(sql, day: '2026-11-01')).single['id'], 'diary:1');
      expect(await PhoneHistoryStore.contains(sql, 'diary', 'diary:2'), true);
      expect(await restored.getSetting('illustration_diary_media:diary:1'), 'existing-media-reference');
    } finally { await restored.closeForTesting(); }
  });

  test('phone apps follow the requested order and expose calendar instead of cart', () {
    final apps = buildApps(null, ({bool silent = false}) async {});
    expect(apps.map((a) => a.title).toList(),
      ['相册', '浏览器', '心情', '塔罗牌', '愿望单', '日记', '随笔', '日历']);
    expect(apps[5].page, isA<PhoneCalendarPage>());
    expect(apps[7].page, isA<PhoneCalendarPage>());
  });

  test('rejected work guard cannot leave a partial archive row', () async {
    final values = PhoneHistoryStore.values(item('note', 9));
    expect(await db.setSettingsAtomically(values, expectedSettings: {'test_guard': 'new'}), false);
    expect(await PhoneHistoryStore.contains(await db.database, 'note', 'note:9'), false);
  });

  test('cart producer is retired while its saved records remain readable', () async {
    await db.setSetting('simulated_phone_cart_json', jsonEncode([item('cart', 1)]));
    expect(SimulatedPhoneRepository.cartGenerationEnabled, false);
    expect((await SimulatedPhoneRepository(db).readOnlySnapshot()).cart.single.id, 'cart:1');
  });
}
