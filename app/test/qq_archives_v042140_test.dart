import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/automatic_memory_permit.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_admin.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_history_context_policy.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_parts.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

class _Api extends QqApi {
  _Api() : super(appId: 'fixture', secret: 'not-a-real-secret');
  final requests = <Map<String, Object?>>[];
  String? reject;
  bool uncertain = false;
  @override Future<void> sendMessage({required bool group, required String target, required String messageId,
    required int sequence, String text = '', String fileInfo = ''}) async {
    requests.add({'seq': sequence, 'text': text, 'media': fileInfo});
    if (reject != null) { final code = reject!; reject = null; throw QqApiException(code, uncertain: uncertain); }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db; late QqStore store; late QqArchiveAdmin admin;
  const scope = 'fixture-scope';
  final cid = QqStore.conversationId(scope, 'group', 'a');
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); store = QqStore(db); admin = QqArchiveAdmin(db); });
  tearDown(() async => db.closeForTesting());
  Future<int> add(String id, DateTime at, String text, {String group = 'a'}) async => (await store.append(
    fence: await store.capture(), scope: scope, kind: 'group', target: group, platformId: id, sender: 'peer', text: text,
    observedAt: at.millisecondsSinceEpoch, receivedAt: at.millisecondsSinceEpoch))!;
  Future<Map<String, Object?>> note(List<int> ids, String text) async {
    final sql = await db.database;
    final rows = await sql.query('qq_archive', where: 'seq IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids, orderBy: 'seq');
    final stamps = <Map<String, Object?>>[];
    await QqArchiveReader(sql).projectRows(rows, maxChars: 27500, stamp: stamps);
    await store.saveNote(await store.capture(), cid, rows, stamps, await AutomaticMemoryPermit.capture(sql, 'auto_memory'), text, '待分享', 1000);
    return (await sql.query('qq_notes', where: 'through_seq=?', whereArgs: [ids.last])).single;
  }

  test('calendar boundary keeps previous month recent; old history remains retrievable', () async {
    await add('september', DateTime(2026, 9, 30, 23), '九月的珊瑚');
    final oct = await add('october', DateTime(2026, 10, 31, 23), '十月的珊瑚');
    final nov = await add('november', DateTime(2026, 11, 1), '十一月的新话题');
    final months = await admin.months(cid);
    expect(months.map((m) => m.key), ['2026-11', '2026-10', '2026-09']);
    expect(months.map((m) => m.recentAt(DateTime(2026, 11, 1))), [true, true, false]);
    final sql = await db.database;
    expect(await QqArchiveReader(sql).groupContext(cid, through: nov), contains('九月的珊瑚'));
    await db.setSetting('auto_memory', '1');
    await sql.update('qq_conversations', {'summary_checked_seq': oct - 1}, where: 'id=?', whereArgs: [cid]);
    final claim = (await store.claimSummary(await store.capture(), cid, idle: true))!;
    expect(claim.rows.map((r) => r['seq']), [oct]);
    expect(claim.input, isNot(contains('十一月的新话题')));
  });

  test('raw and notes paginate without silently hiding older months', () async {
    for (var i = 0; i < 53; i++) { await add('m$i', DateTime(2026, 10, 2, 0, i), '原文$i'); }
    final month = (await admin.months(cid)).single;
    final first = await admin.messages(cid, month);
    final rest = await admin.messages(cid, month, before: first.last['seq'] as int);
    expect(first.length, 50); expect(rest.length, 3);
    expect({...first, ...rest}.length, 53);
  });

  test('month deletion withdraws cross-month text and rebuilds only retained originals', () async {
    final old = await add('old', DateTime(2026, 10, 31, 23), '应删除的十月事实');
    final keep = await add('keep', DateTime(2026, 11, 1), '必须保留的十一月事实');
    final original = await note([old, keep], '跨月摘要包含十月和十一月事实');
    final sql = await db.database;
    final c = (await sql.query('qq_conversations', where: 'id=?', whereArgs: [cid])).single;
    final result = await admin.deleteRange(cid, DateTime(2026, 10), DateTime(2026, 11), expectedVersion: c['version'] as int);
    expect(result.messages, 1); expect(result.rebuilds, 1);
    final withdrawn = (await sql.query('qq_notes')).single;
    expect(withdrawn['valid'], 0); expect(withdrawn['content'], '');
    expect(jsonDecode(withdrawn['sources'] as String), [keep]); expect(await sql.query('qq_shares'), isEmpty);
    final reader = QqArchiveReader(sql);
    expect(await reader.matches([{'table': 'qq_notes', 'id': original['id'], 'token': QqArchiveReader.noteToken(original)}]), false);
    final fence = await store.capture(conversationId: cid);
    final repair = (await store.claimSummary(fence, cid, idle: true))!;
    expect(repair.rows.map((r) => r['seq']), [keep]); expect(repair.input, isNot(contains('应删除的十月事实')));
    expect(await store.saveNote(fence, cid, repair.rows, repair.stamp, repair.permit, '保留下来的十一月事实', '不应补发', 2000,
      repairId: repair.repairId, repairRevision: repair.repairRevision, conversationVersion: repair.conversationVersion), true);
    expect((await sql.query('qq_notes')).single['valid'], 1); expect(await sql.query('qq_shares'), isEmpty);
    final backup = await db.exportAll();
    QqArchiveSchema.validate((backup['tables'] as Map).cast<String, dynamic>(), version: AppDatabase.schemaVersion);
  });

  test('edit-back changes token; stale workers cannot resurrect deleted notes', () async {
    final seq = await add('one', DateTime(2026, 10, 2), '真实来源');
    final old = await note([seq], '原笔记');
    final sql = await db.database;
    final oldFence = await store.capture(conversationId: cid);
    await admin.editNote(old, '修订笔记');
    var row = (await sql.query('qq_notes')).single;
    expect(row['edited_at'], greaterThan(0));
    await admin.editNote(row, '原笔记'); row = (await sql.query('qq_notes')).single;
    expect(QqArchiveReader.noteToken(old), isNot(QqArchiveReader.noteToken(row)));
    expect(await store.current(oldFence), false);
    await admin.deleteNote(row);
    expect(await sql.query('qq_notes'), isEmpty); expect(await sql.query('qq_archive'), isNotEmpty);
    await expectLater(store.write(oldFence, (txn) async => txn.insert('qq_notes', old)), throwsA(isA<BrainWorkInvalidated>()));
  });

  test('date deletion preserves other groups, App messages and post-preview arrivals', () async {
    final through = await add('selected', DateTime(2026, 10, 2), '要清理');
    await add('other-group', DateTime(2026, 10, 2), '其他群的资料', group: 'b');
    await db.insertMessage(ChatMessage(id: 'private', role: 'user', content: 'App私人原文', createdAt: DateTime.now()));
    final sql = await db.database;
    final c = (await sql.query('qq_conversations', where: 'id=?', whereArgs: [cid])).single;
    await add('new-after-preview', DateTime(2026, 10, 2, 1), '确认后新到的消息');
    await admin.deleteRange(cid, DateTime(2026, 10), DateTime(2026, 11), expectedVersion: c['version'] as int, throughSeq: through);
    expect((await sql.query('qq_archive')).map((r) => r['content']), containsAll(['其他群的资料', '确认后新到的消息']));
    expect((await db.messageById('private'))!.content, 'App私人原文');
  });

  test('schema62 source notes upgrade before restore; invalid sources remain rejected', () async {
    final seq = await add('source', DateTime(2026, 10, 2), '旧存档'); await note([seq], '旧摘要');
    final raw = await db.exportAll(); final tables = (raw['tables'] as Map).cast<String, dynamic>();
    final existing=(tables['qq_notes'] as List).single as Map;
    final originalToken=QqArchiveReader.noteToken(existing.cast<String,Object?>());
    for (final n in tables['qq_notes'] as List) { for (final field in ['range_start', 'range_end', 'revision', 'edited_at']) { (n as Map).remove(field); } }
    QqArchiveSchema.validate(tables, version: 62);
    expect(QqArchiveReader.noteToken(((tables['qq_notes'] as List).single as Map).cast<String,Object?>()),originalToken);
    expect((tables['qq_notes'] as List).single['range_start'], DateTime(2026, 10, 2).millisecondsSinceEpoch);
    (tables['qq_notes'] as List).single['sources'] = '[999999]';
    expect(() => QqArchiveSchema.validate(tables, version: 63), throwsFormatException);
  });

  test('completed QQ lookup does not become an invented follow-up; real future requests survive', () async {
    const title = 'QQ群聊天记录已能查看', detail = '已看到了旧群聊；后续要不要在群里做什么仍未明确。';
    expect(QqHistoryContextPolicy.allowThread(title: title, detail: detail, userText: '记录做好了，你看一看？', qqReference: true), false);
    expect(QqHistoryContextPolicy.allowThread(title: title, detail: '明天测试群功能', userText: '明天提醒我再测一次', qqReference: true), true);
    await db.insertMessage(ChatMessage(id: 'u', role: 'user', content: '记录做好了，你看一看？', createdAt: DateTime.now()));
    await db.upsertUnfinishedThread(title: title, detail: detail, importance: .6, sourceMessageId: 'u', topicKey: 'qq.lookup');
    expect(await QqHistoryContextPolicy.unsupportedTopics(db), contains('qq.lookup'));
    expect(QqHistoryContextPolicy.proactiveBoundary, contains('可以自然回想旧事'));
  });

  test('writer chooses complete messages; sentences and paragraphs are never forcibly split', () {
    expect(QqReplyParts.parse('第一句。第二句\n第三句'), ['第一句。第二句\n第三句']);
    expect(QqReplyParts.parse('来了\n<qq_next_message/>\n刚想说这个\n<qq_next_message/>\n笑死'), ['来了','刚想说这个','笑死']);
    expect(QqReplyParts.parse('a<qq_next_message/>b<qq_next_message/>c<qq_next_message/>d'), ['a','b','c\nd']);
    expect(QqReplyParts.parse(''), isEmpty);
  });

  test('three messages pause only between sends; final text and sticker stay together', () async {
    final api=_Api(), waits=<Duration>[];
    final receipts=<String>[];
    await QqReplyDelivery(api,pause:(wait)async {
      expect(api.requests.length,waits.length+1);waits.add(wait);
    }).send(group:true,target:'group',messageId:'new',text:'来了\n补一句\n哈哈',messages:['来了','补一句','哈哈'],fileInfo:'image',
      current:()async=>true,beforeSend:()async{},sent:(seq,text,image)async=>receipts.add(text));
    expect(api.requests.map((r)=>r['text']), ['来了','补一句','哈哈']);
    expect(api.requests.last['media'],'image');expect(receipts,hasLength(3));expect(waits,hasLength(2));
    expect(waits.every((d)=>d.inMilliseconds>=1000 && d.inMilliseconds<=2000),true);api.close();
  });

  test('disconnect during typing delay stops later messages without repeating the first', () async {
    final api=_Api();var valid=true;
    await expectLater(QqReplyDelivery(api,pause:(_)async {valid=false;}).send(group:true,target:'group',messageId:'new',
      text:'第一条\n第二条',messages:['第一条','第二条'],fileInfo:'',current:()async=>valid,beforeSend:()async{},sent:(_,__,___)async{}),throwsStateError);
    expect(api.requests,hasLength(1));expect(api.requests.single['text'],'第一条');api.close();
  });

  for (final scenario in ['combined', 'image-only', 'rejected', 'uncertain', 'invalidated']) {
    test('production media delivery $scenario preserves actual receipts without duplicate sends', () async {
      final api = _Api(); final receipts = <Map<String, Object?>>[];
      if (scenario == 'rejected') api.reject = 'api_22006';
      if (scenario == 'uncertain') { api.reject = 'network'; api.uncertain = true; }
      final send = QqReplyDelivery(api,pause:(_)async{}).send(group: true, target: 'group', messageId: 'source',
        text: scenario == 'image-only' ? '' : '随手画个表情', fileInfo: 'image-token', current: () async => scenario != 'invalidated',
        beforeSend: () async {}, sent: (seq, text, image) async { receipts.add({'seq': seq, 'text': text, 'image': image}); });
      if (scenario == 'uncertain' || scenario == 'invalidated') {
        await expectLater(send, throwsA(anything)); expect(receipts, isEmpty);
        expect(api.requests.length, scenario == 'uncertain' ? 1 : 0);
      } else {
        await send;
        expect(api.requests.length, scenario == 'rejected' ? 3 : 1);
        expect(receipts.length, scenario == 'rejected' ? 2 : 1);
        if (scenario == 'combined') { expect(api.requests.single['text'], '随手画个表情'); expect(api.requests.single['media'], 'image-token'); }
        if (scenario == 'image-only') expect(api.requests.single['text'], '');
      }
      api.close();
    });
  }
}
