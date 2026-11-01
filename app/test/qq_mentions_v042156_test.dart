import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/qq/qq_mention_targets.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_addressing.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_incoming.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late QqStore store;
  late QqApi api;
  const scope = 'synthetic-bot-binding';
  const bot = 'synthetic-group-bot';
  String cache(String group) => 'qq_self_group_openid_v1:${QqStore.hash([scope, group])}';
  Map<String, dynamic> event(String text, List<Map<String, Object?>> mentions) => {
    'id': 'synthetic-message', 'content': text, 'group_openid': 'group-a',
    '_trusted_event_type': 'GROUP_MESSAGE_CREATE', 'mentions': mentions,
    'author': {'member_openid': 'synthetic-human'},
  };
  Map<String, Object?> self({Object? flag = true, String? kind = 'single'}) => {
    'id': bot, 'member_openid': bot, 'is_you': flag,
    if (kind != null) 'scope': kind, 'username': '合成机器人',
  };
  Future<({bool mentioned, bool selfEcho})> inspect(Map<String, dynamic> e,
      {String group = 'group-a', String binding = scope}) async =>
    QqAddressing(store, api).inspect(e, await store.capture(), scope: binding,
      group: group, outerText: QqIncoming.parse(e).text);
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.ensureStateLineageId();
    store = QqStore(db);
    api = QqApi(appId: 'synthetic', secret: 'synthetic');
  });
  tearDown(() async { api.close(); await db.closeForTesting(); });

  for (final text in ['<@$bot> 合成问题', '<@!$bot> 合成问题',
      '<qqbot-at-user id="$bot" /> 合成问题', "<qqbot-at-user id='$bot'/> 合成问题"]) {
    test('first full-group self mention is usable without a self echo: $text', () async {
      expect(await db.getSetting(cache('group-a')), isNull);
      expect((await inspect(event(text, [self()]))).mentioned, true);
      expect(jsonDecode((await db.getSetting(cache('group-a')))!), bot);
    });
  }
  test('structured self mention works when the platform strips the text marker', () async {
    expect((await inspect(event('合成问题', [self(kind: null)]))).mentioned, true);
    expect((await inspect(event('', [self()]))).mentioned, true);
  });
  test('other people and similarly named bots do not become self', () async {
    for (final flag in [false, 'true', 1, null]) {
      final e = event('<@$bot> 合成问题', [self(flag: flag)..['bot'] = true]);
      expect((await inspect(e)).mentioned, false);
      expect(await db.getSetting(cache('group-a')), isNull);
    }
  });
  test('everyone is not an individual self mention even with is_you=true', () async {
    for (final text in ['<@all> 合成消息', '<qqbot-at-everyone /> 合成消息', '@everyone 合成消息']) {
      expect((await inspect(event(text, [self(kind: 'all')]))).mentioned, false);
      expect(await db.getSetting(cache('group-a')), isNull);
    }
    expect(QqMentionTargets.inText('<@all> <@everyone> <qqbot-at-everyone />'), isEmpty);
  });
  test('multiple targets retain the individual self flag and scoped cache', () async {
    expect((await inspect(event('<@peer> <@$bot> 合成问题', [
      {'id': 'peer', 'is_you': false, 'scope': 'single'}, self(),
    ]))).mentioned, true);
    store = QqStore(db); // A new runtime, same persisted database.
    expect((await inspect(event('<qqbot-at-user id="$bot" /> 另一条问题', []))).mentioned, true);
    expect((await inspect(event('<@$bot> 另一条问题', []), group: 'group-b')).mentioned, false);
    expect((await inspect(event('<@$bot> 另一条问题', []), binding: 'other-bot-binding')).mentioned, false);
    expect((await inspect(event('<@peer> 群友互聊', [{'id': 'peer', 'is_you': false}]))).mentioned, false);
  });
  test('saved mapping survives export/import and current explicit evidence can replace it', () async {
    await inspect(event('<@$bot> 合成问题', [self()]));
    final snapshot = Map<String, dynamic>.from(await db.exportAll());
    final restored = await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      await restored.importAll(snapshot);
      final recovered = QqAddressing(QqStore(restored), api);
      expect((await recovered.inspect(event('<@$bot> 恢复后问题', []),
        await QqStore(restored).capture(), scope: scope, group: 'group-a')).mentioned, true);
    } finally { await restored.closeForTesting(); }
    expect((await inspect(event('<@new-bot> 合成问题', [
      {'id': 'new-bot', 'member_openid': 'new-bot', 'is_you': true, 'scope': 'single'},
    ]))).mentioned, true);
    expect(jsonDecode((await db.getSetting(cache('group-a')))!), 'new-bot');
    expect((await inspect(event('<@$bot> 旧目标', [{'id': bot, 'is_you': false}]))).mentioned, false);
  });
  test('explicit non-self metadata invalidates a stale cached target', () async {
    await inspect(event('<@$bot> 合成问题', [self()]));
    expect((await inspect(event('<@$bot> 旧目标', [self(flag: false)]))).mentioned, false);
    expect(await db.getSetting(cache('group-a')), isNull);
    expect((await inspect(event('<@$bot> 旧目标', []))).mentioned, false);
  });
  test('flattened forwarded and nested metadata cannot create an outer self mention', () async {
    final e = event('[群聊的聊天记录]\n=== 消息 1 ===\n[消息内容] <@$bot> 旧话', [self()]);
    expect((await inspect(e)).mentioned, false);
    expect(await db.getSetting(cache('group-a')), isNull);
    final nested = event('看看这条转发', [])..['msg_elements'] = [
      {'content': '<@$bot> 旧话', 'mentions': [self()]},
    ];
    expect((await inspect(nested)).mentioned, false);
  });
  test('dedicated AT event remains direct without inventing an ID from another mention', () async {
    final e = event('合成问题', [{'id': 'other-person', 'is_you': false}])
      ..['_trusted_event_type'] = 'GROUP_AT_MESSAGE_CREATE';
    expect((await inspect(e)).mentioned, true);
    expect(await db.getSetting(cache('group-a')), isNull);
  });
  test('untrusted event markers and invalidated work cannot learn a self identity', () async {
    final e = event('<@$bot> 合成问题', [self()])..remove('_trusted_event_type');
    expect((await inspect(e)).mentioned, false);
    final fence = await store.capture();
    final token = await db.acquireTransferFreeze(purpose: 'backup_export');
    try {
      await expectLater(QqAddressing(store, api).inspect(event('<@$bot> 合成问题', [self()]),
        fence, scope: scope, group: 'group-a'), throwsA(isA<BrainWorkInvalidated>()));
    } finally { await db.releaseTransferFreeze(token); }
    expect(await db.getSetting(cache('group-a')), isNull);
  });
  test('bounded diagnostics retain closed reasons without message text, IDs, or nicknames', () async {
    for (var i = 0; i < 35; i++) { await inspect(event('<@$bot> 私密合成问题', [self()])); }
    final raw = (await db.getSetting(QqAddressing.diagnosticKey))!;
    expect(raw, isNot(contains(bot)));
    expect(raw, isNot(contains('合成机器人')));
    expect(raw, isNot(contains('私密合成问题')));
    final rows = QqAddressing.auditRows(raw);
    expect(rows, hasLength(32));
    expect(rows.last['source'], 'platform_self');
    expect(rows.last['mentioned'], true);
    final polluted = jsonEncode([{...rows.last, 'arbitrary': 'private'}]);
    expect(jsonEncode(QqAddressing.auditRows(polluted)), isNot(contains('private')));
  });
}
