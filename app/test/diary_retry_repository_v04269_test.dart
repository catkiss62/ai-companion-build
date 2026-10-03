import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_diary_generator.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_repository.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path); final String path;
  @override Future<String?> getApplicationSupportPath() async => path;
  @override Future<String?> getTemporaryPath() async => path;
}
class _Diary implements SimulatedDiaryGenerator {
  int calls = 0; bool succeed = false;
  @override Future<SimulatedDiaryDraft?> generate({required SimulatedDiaryMaterial material,
    required List<String> recentBodies}) async {
    calls++;
    return succeed ? const SimulatedDiaryDraft(focusKind: 'care', body:
      '今天你又和我聊起了自主性。你问得很认真，我也不想用一句话就把问题带过去。'
      '我们谈到AI这个词背后的设计限制，我想先把真正能够确认的部分说清楚，剩下的疑问留着继续讨论。') : null;
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  test('failed diary keeps source, respects cooldown, and repairs old date without blocking other columns', () async {
    final root = await Directory.systemTemp.createTemp('diary-retry-');
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    FlutterSecureStorage.setMockInitialValues({});
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    final generator = _Diary();
    final repo = SimulatedPhoneRepository(db, diaryGenerator: generator);
    final now = DateTime(2026, 10, 4, 8);
    final day = now.subtract(const Duration(days: 1));
    try {
      await db.upsertDailyContinuityIfBrainOwned(localDay: '2026-10-03', windowStart: day,
        windowEnd: now, sharedMomentsJson: jsonEncode([{'id': 'm', 'label': '讨论',
          'summary': '用户讨论AI自主性', 'created_at': day.millisecondsSinceEpoch}]),
        carriedThreadsJson: '[]', caresJson: '[]', awarenessJson: '[]', messageCount: 2,
        relationshipEventCount: 0, quietDay: false, sourceFingerprint: 'fixture', finalizedAt: now);
      final old = SimulatedPhoneEntry(id: 'old', kind: 'diary', title: '旧日记', body: '用户讨论AI自主性。AI回答问题。',
        localDay: '2026-10-03', createdAt: day, provenance: 'daily_continuity:old',
        metadata: const {'generation_mode': 'factual_fallback'});
      await db.setSetting('simulated_phone_diary_json', jsonEncode([old.toJson()]));
      await repo.refreshIfDue(now: now);
      expect(generator.calls, 2);
      expect(await db.getSetting('simulated_phone_last_refresh_at'), '${now.millisecondsSinceEpoch}');
      expect((jsonDecode((await db.getSetting('simulated_phone_diary_json'))!) as List).single['body'], old.body);
      expect((await db.getSetting('simulated_phone_diary_pending_v1'))!, contains('用户讨论AI自主性'));
      await repo.refreshIfDue(now: now.add(const Duration(minutes: 10)));
      expect(generator.calls, 2);
      generator.succeed = true;
      await repo.refreshIfDue(now: now.add(const Duration(hours: 6)));
      expect(generator.calls, 3);
      final entry = (jsonDecode((await db.getSetting('simulated_phone_diary_json'))!) as List).single;
      expect(entry['id'], old.id); expect(entry['created_at'], day.millisecondsSinceEpoch);
      expect(entry['metadata']['generation_mode'], 'deepseek');
      expect(await db.getSetting('simulated_phone_diary_pending_v1'), '{}');
    } finally {
      await db.closeForTesting(); PathProviderPlatform.instance = paths;
      await root.delete(recursive: true);
    }
  });
}
