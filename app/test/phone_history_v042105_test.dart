import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/models/companion_album.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_reader.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting(SimulatedPhoneRepository.enabledKey, '1');
  });
  tearDown(() => db.closeForTesting());

  test('natural history questions use existing phone records with no fresh web request', () {
    for (final text in ['你看不到你的联网记录吗', '你最近搜过什么？', '你保存了哪些图？', '你最近写了什么？']) {
      final calls = AgentToolPlanner.routeLocally(text)!.calls;
      expect(calls, hasLength(1), reason: text);
      expect(calls.single.toolId, 'phone.search', reason: text);
      final names = AgentToolPlanner.nativeToolDefinitionsFor(text)
          .map((d) => (d['function'] as Map)['name']).toSet();
      expect(names, {'phone_search', 'phone_read'}, reason: text);
    }
    for (final text in ['今天抽到的塔罗牌有点怪', '我想和你聊聊日记这件事',
      '如果你搜过什么，能不能告诉我？', '不要查看你的购物车']) {
      expect(AgentToolPlanner.routeLocally(text), isNull, reason: text);
    }
  });

  Future<void> entry(String key, String id, String kind, {String state = 'active'}) async {
    await db.setSetting(key, jsonEncode([SimulatedPhoneEntry(id: id, kind: kind,
      title: '真实标题$id', body: '保存的正文$id', localDay: '2026-10-14',
      createdAt: DateTime.now(), provenance: 'self_written', state: state,
      metadata: {'reversed': true, 'card_index': 9, 'closing': '原有牌面解读'}).toJson()]));
  }

  test('read adapter retrieves writing and tarot targets without mutating or drawing', () async {
    await entry('simulated_phone_diary_json', 'diary', 'diary');
    await entry('simulated_phone_notes_json', 'note', 'note');
    final now = DateTime.now();
    await db.setSetting('simulated_phone_tarot_json', jsonEncode([
      for (final subject in ['self', 'user']) SimulatedPhoneEntry(id: subject,
        kind: 'tarot', title: subject == 'self' ? '隐者' : '星星', body: '实际保存牌意',
        localDay: '2026-10-14', createdAt: now, provenance: 'daily_tarot', state: subject,
        metadata: {'reversed': subject == 'self', 'card_index': 9, 'closing': '已有解读'}).toJson(),
    ]));
    final before = await db.getSetting('simulated_phone_tarot_json');
    final reader = SimulatedPhoneReader(db);
    expect((await reader.search('', activity: 'writing')).map((i) => i.section).toSet(), {'diary', 'note'});
    final self = (await reader.search('', section: 'tarot', subject: 'self')).single;
    final user = (await reader.read(section: 'tarot', subject: 'user'))!;
    expect(self.title, '隐者');
    expect(self.facts['reversed'], true);
    expect(user.title, '星星');
    expect(user.facts['reversed'], false);
    expect(user.facts['new_draw_performed'], false);
    expect(user.body, contains('已有解读'));
    expect(await db.getSetting('simulated_phone_tarot_json'), before);
  });

  test('fictional cart is explicit only and never a purchased capability', () async {
    await entry('simulated_phone_cart_json', 'cart', 'cart');
    final reader = SimulatedPhoneReader(db);
    expect(await reader.search(''), isEmpty);
    final cart = (await reader.search('', section: 'cart')).single;
    expect(cart.facts['fictional'], true);
    expect(cart.facts['purchased'], false);
    expect(cart.facts['real_item_or_capability'], false);
    expect((await reader.read(handle: cart.handle))!.handle, cart.handle);
  });

  test('database browser projection preserves autonomous and delegated origins', () async {
    final sql = await db.database;
    final at = DateTime.now().millisecondsSinceEpoch;
    await sql.insert('autonomous_action_runs', {'id': 'run', 'dedupe_key': 'run',
      'tool_kind': 'public_web', 'intent_action': 'search', 'drive_key': 'curiosity',
      'intent_score': .8, 'reason_source': 'curiosity', 'status': 'succeeded',
      'gate_reason': 'allowed', 'outcome_kind': 'candidate_stored',
      'requested_at': at, 'state_generation': 0, 'device_id': 'test'});
    for (final origin in ['autonomous', 'user_turn']) {
      await sql.insert('companion_browser_visits', {'id': origin, 'title': '过去的网页',
        'summary': '保存的摘要', 'url': 'https://example.com/page', 'source_domain': 'example.com',
        'provider': 'fixture', 'discovered_at': at, 'created_at': at,
        'action_run_id': 'run', 'origin': origin, 'search_query': '实际搜索词', 'read_state': 'verified'});
    }
    final rows = await SimulatedPhoneReader(db).search('', section: 'browser');
    expect(rows.map((r) => r.facts['origin']).toSet(), {'autonomous', 'user_turn'});
    for (final row in rows) {
      expect(row.facts['self_search_evidence'], true);
      expect(row.facts['new_search_performed'], false);
      expect(row.body, contains('实际搜索词'));
    }
    expect(CompanionBrowserVisit.fromDb({'id': 'legacy'}).origin, 'unknown');
  });
}
