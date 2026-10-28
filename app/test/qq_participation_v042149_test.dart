import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/qq/qq_message_material.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_display_names.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db; late QqStore store;
  const scope = 'synthetic-149', target = 'group-fixture';
  final cid = QqStore.conversationId(scope, 'group', target);
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); store = QqStore(db); });
  tearDown(() async => db.closeForTesting());
  Future<int> append(String id, String text, int time, {String role = 'user', String reply = ''}) async =>
    (await store.append(fence: await store.capture(conversationId: cid), scope: scope, kind: 'group', target: target,
      platformId: id, sender: role == 'assistant' ? 'self' : 'speaker-a', text: text, observedAt: time, receivedAt: time,
      role: role, replyTo: reply, contextMeta: const QqMessageMaterial().encode()))!;

  test('focus preserves external addressee and actual input time beside a later delivered assistant reply', () async {
    await append('old-own', '先前她说的话', 100, role: 'assistant');
    final input = await append('input', '<@speaker-b> 那你打算怎么选？', 120);
    final later = await append('later-own', '生成期间才发出的回答', 150, role: 'assistant');
    await append('future-input', '不能混入本批的新发言', 160);
    final sql = await db.database, reader = QqArchiveReader(await db.database);
    final row = (await sql.query('qq_archive', where: 'seq=?', whereArgs: [input])).single;
    final focus = (await reader.participationFocus([row])).single;
    expect(focus['observed_at'], 120); expect(focus['received_at'], 120);
    expect(focus['trusted_direct_mention'], false);
    expect(focus['outer_mention_speaker_keys'], [QqDisplayNames.memberKey(cid, 'speaker-b').substring(0, 12)]);
    expect(focus['mention_scope'], contains('not_identity_authority'));
    final context = (await reader.participationContext(cid, through: input, stamp: [])).split('\n')
      .map((line) => jsonDecode(line) as Map).toList();
    final delivered = context.firstWhere((r) => r['seqs'] is List && (r['seqs'] as List).contains(later));
    expect(delivered['already_sent_after_pending_input'], true);
    expect(delivered['first_observed_at'], 150);
    expect(jsonEncode(context), isNot(contains('不能混入本批的新发言')));
  });
  test('same-group confirmed assistant quote carries source evidence and deletion invalidates it', () async {
    final own = await append('own-receipt', '更早她的问题', 100, role: 'assistant');
    final input = await append('input-quote', '我是在接你更早的问题', 120, reply: 'own-receipt');
    final sql = await db.database, reader = QqArchiveReader(await db.database);
    final row = (await sql.query('qq_archive', where: 'seq=?', whereArgs: [input])).single;
    final stamp = <Map<String, Object?>>[];
    final focus = (await reader.participationFocus([row], stamp: stamp)).single;
    expect((focus['quoted_assistant'] as Map)['seq'], own);
    expect((focus['quoted_assistant'] as Map)['observed_at'], 100);
    expect(await reader.matches(stamp), true);
    await sql.delete('qq_archive', where: 'seq=?', whereArgs: [own]);
    expect(await reader.matches(stamp), false);
    expect((await reader.participationFocus([row])).single.containsKey('quoted_assistant'), false);
  });
  test('raw reply identifiers never invent an assistant quote from a different group', () async {
    await store.append(fence: await store.capture(), scope: scope, kind: 'group', target: 'another-group',
      platformId: 'other-receipt', sender: 'self', text: '别群的回答', role: 'assistant', observedAt: 100, receivedAt: 100);
    final input = await append('input-cross', '合成引用', 120, reply: 'other-receipt');
    final reader = QqArchiveReader(await db.database);
    final row = (await (await db.database).query('qq_archive', where: 'seq=?', whereArgs: [input])).single;
    expect((await reader.participationFocus([row])).single.containsKey('quoted_assistant'), false);
  });
}
