import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'qq_archive_reader.dart';
import 'qq_store.dart';
import 'qq_failure.dart';
import 'qq_failure_history.dart';
import '../../core/database/brain_work_fence.dart';

class QqPendingReply {
  QqPendingReply(this.row, this.stamp, this.requests, this.delivered);
  final Map<String, Object?> row;
  final List<Map<String, Object?>> stamp;
  final List<String> requests, delivered;
  String get id => row['id'] as String;
  Map<String, dynamic> get delivery {
    try {final d=jsonDecode(row['draft'] as String);return d is Map && d['delivery'] is Map?Map<String,dynamic>.from(d['delivery'] as Map):{};}
    catch (_) {return {};}
  }
  Map<String,dynamic> get inherited {
    try {final d=jsonDecode(row['draft'] as String);return d is Map && d['inherited_delivery'] is Map?Map<String,dynamic>.from(d['inherited_delivery'] as Map):{};}
    catch (_) {return {};}
  }
  List<Map> get confirmations => (delivery['confirmed'] as List? ?? []).whereType<Map>().toList();
  bool get allConfirmed => delivery['planned'] is int && (delivery['planned'] as int)>0 && confirmations.length==delivery['planned'];
  Map<String, dynamic>? get draft {
    if (row['failure_phase'] != 'group_boundary' || delivered.isNotEmpty || row['stage'] == 'send_uncertain' ||
        inherited['unknown']==true || (inherited['confirmed'] as List? ?? []).isNotEmpty) return null;
    try {
      final value = jsonDecode(row['draft'] as String);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) { return null; }
  }
  Map<String, Object?> get hint => {
    'previous_request_unfinished':!allConfirmed,
    'platform_confirmed':confirmations.isNotEmpty || delivered.isNotEmpty || row['stage']=='sent_archive_failed',
    'all_parts_confirmed':allConfirmed,
    if(delivery['planned'] is int)'planned_parts':delivery['planned'],
    'confirmed_parts':[...(inherited['confirmed'] as List? ?? []),...confirmations],
    'requests': requests,
    'stage': row['stage'], 'failure_phase': row['failure_phase'],
    'confirmed_delivered':{...(inherited['confirmed'] as List? ?? []).whereType<Map>().map((p)=>p['text']).whereType<String>(),
      ...(confirmations.isEmpty?delivered:confirmations.map((p)=>p['text']).whereType<String>())}.toList(),
    'delivery_unknown': row['stage'] == 'send_uncertain' || inherited['unknown']==true,
    'instruction': '这是宿主提供的QQ投递事实。理解本批外层发言是否接续、追问、已解决、取消或另起话题；不要猜测上次成功，不重发已确认或结果未知的旧段落。',
  };
}

/// An unfinished response is dormant until a new received message or a new
/// trusted mention supplies a trigger. It is not a timer or an App Thought.
class QqReplyTasks {
  QqReplyTasks(this.store);
  final QqStore store;
  static const ttl = Duration(minutes: 10);
  static const maxSources = 80;
  static Map<String,Object?> _inherited(QqPendingReply pending) {
    final parts=<String,Map>{};
    for(final raw in [...(pending.inherited['confirmed'] as List? ?? []),
      ...pending.confirmations.map((p)=>{...p,'operation':pending.id}),
      if(pending.confirmations.isEmpty)for(var i=0;i<pending.delivered.length;i++)
        {'operation':pending.id,'sequence':i+1,'text':pending.delivered[i]}]) {
      if(raw is Map)parts['${raw['operation']}:${raw['sequence']}']=raw;
    }
    return {'unknown':pending.row['stage']=='send_uncertain' || pending.inherited['unknown']==true,'confirmed':parts.values.toList()};
  }
  static const relationPrompt='此前有一条宿主记录的未完成回应。先判断本轮是在继续、已解决、取消、换话题或不明确。'
    '在回复开头单独输出<qq_pending>continue|resolved|cancelled|changed|unclear</qq_pending>中的一个实际值，随后正常回复。'
    '这只是宿主接续标记，不复述它；不能因旧内容投递未知就重发旧段落，也不要把另起话题变成旧请求补答。';
  static ({String text,String relation}) parseRelation(String raw) {
    final match=RegExp(r'^\s*<qq_pending>(continue|resolved|cancelled|changed|unclear)</qq_pending>\s*').firstMatch(raw);
    return (text:match==null?raw:raw.substring(match.end),relation:match?.group(1)??'unclear');
  }
  static Future<void> begin(Transaction sql, QqBatch b, int now, String policy) async {
    await sql.delete('qq_reply_tasks', where: 'expires_at<?', whereArgs: [now]);
    final at = b.rows.last['received_at'] as int;
    await sql.insert('qq_reply_tasks', {
      'id': b.id, 'conversation_id': b.cid, 'through_seq': b.through,
      'sources': jsonEncode(b.rows.map((r) => r['seq']).toList()),
      'source_stamp': jsonEncode([for (final r in b.rows) {'table':'qq_archive','id':r['id'],'version':r['version']}]),
      'identity': QqStore.ingressIdentity(b.fence), 'policy': policy,
      'source_at': at, 'expires_at': at + ttl.inMilliseconds,
      'addressed': !b.group || b.rows.any((r) => r['mentioned'] == 1) ? 1 : 0,
      'stage':'checking', 'draft':'', 'failure_phase':'', 'last_trigger_seq':b.through,
      'valid':1, 'updated_at':now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<void> addressed(QqBatch b) => store.write(b.fence, (sql) async {
    await sql.update('qq_reply_tasks', {'addressed':1}, where:'id=?', whereArgs:[b.id]);
  });
  Future<void> saveDraft(QqBatch b, Map<String, Object?> draft) => store.write(b.fence, (sql) async {
    final row=(await sql.query('qq_reply_tasks',columns:['draft'],where:'id=?',whereArgs:[b.id],limit:1)).single;
    final previous=(row['draft'] as String).isEmpty?<String,dynamic>{}:(jsonDecode(row['draft'] as String) as Map).cast<String,dynamic>();
    final raw = jsonEncode({...previous,...draft});
    if (raw.length > 48000) throw const FormatException('qq_draft_size');
    await sql.update('qq_reply_tasks', {'draft':raw}, where:'id=? AND valid=1', whereArgs:[b.id]);
  });
  Future<void> failure(QqBatch b, String phase) => store.write(b.fence, (sql) async {
    await sql.update('qq_reply_tasks', {'failure_phase':phase}, where:'id=?', whereArgs:[b.id]);
  });
  Future<void> plan(QqBatch b,int count) => _delivery(b,(d)=>{...d,'planned':count});
  Future<void> confirmed(QqBatch b,int sequence,String text,bool image,String language) => _delivery(b,(d) {
    final receipt=store.receipt(b,sequence);
    final parts=(d['confirmed'] as List? ?? []).whereType<Map>().where((p)=>p['sequence']!=sequence).toList();
    parts.add({'sequence':sequence,'text':text,'image':image,'language':language,
      'platform_id':receipt?.id??'','platform_index':receipt?.index??''});
    return {...d,'confirmed':parts};
  });
  Future<void> _delivery(QqBatch b,Map<String,Object?> Function(Map<String,dynamic>) change) => store.write(b.fence,(sql) async {
    final row=(await sql.query('qq_reply_tasks',columns:['draft'],where:'id=?',whereArgs:[b.id],limit:1)).single;
    final draft=(jsonDecode((row['draft'] as String).isEmpty?'{}':row['draft'] as String) as Map).cast<String,dynamic>();
    final d=draft['delivery'] is Map?Map<String,dynamic>.from(draft['delivery'] as Map):<String,dynamic>{};
    draft['delivery']=change(d);
    final raw=jsonEncode(draft);if(raw.length>48000)throw const FormatException('qq_draft_size');
    await sql.update('qq_reply_tasks',{'draft':raw},where:'id=? AND valid=1',whereArgs:[b.id]);
  });
  Future<bool> fits(QqBatch b,QqPendingReply pending) async {
    final ids={...b.rows.map((r)=>r['seq']),...(jsonDecode(pending.row['sources'] as String) as List)};
    return ids.length<=maxSources && jsonEncode(_inherited(pending)).length<=16000;
  }
  Future<QqPendingReply?> pending(QqBatch b, int now, String policy) async {
    final sql = await store.db.database;
    final rows = await sql.query('qq_reply_tasks',
      where:"conversation_id=? AND id!=? AND valid=1 AND addressed=1 AND expires_at>? AND last_trigger_seq<=? "
        "AND stage IN ('failed','interrupted','send_uncertain','partially_sent','sent_archive_failed')",
      whereArgs:[b.cid,b.id,now,b.through], orderBy:'source_at DESC', limit:8);
    for (final row in rows) {
      if (row['policy'] != policy || !QqStore.acceptsIngress(row['identity'] as String, b.fence)) continue;
      final stamps = (jsonDecode(row['source_stamp'] as String) as List)
          .map((e) => Map<String,Object?>.from(e as Map)).toList();
      if (!await QqArchiveReader(sql).matches(stamps)) continue;
      final ids = (jsonDecode(row['sources'] as String) as List).cast<int>();
      final originals = await sql.query('qq_archive', columns:['content'],
        where:'conversation_id=? AND seq IN (${List.filled(ids.length, '?').join(',')})',whereArgs:[b.cid,...ids],orderBy:'seq');
      final sent = await sql.query('qq_archive', columns:['content'],
        where:"conversation_id=? AND role='assistant' AND id LIKE ?",whereArgs:[b.cid,'reply:${row['id']}:%'],orderBy:'seq');
      return QqPendingReply(row, stamps, originals.map((r) => QqArchiveReader.bound(r['content'] as String,2000)).toList(),
        sent.map((r) => QqArchiveReader.bound(r['content'] as String,2000)).toList());
    }
    return null;
  }
  Future<bool> consume(QqBatch b, QqPendingReply pending, {required bool cancel}) => store.write(b.fence, (sql) async {
    final fresh = (await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[b.id],limit:1)).single;
    final sources={...(jsonDecode(fresh['sources'] as String) as List).cast<int>(),
      ...(jsonDecode(pending.row['sources'] as String) as List).cast<int>()}.toList()..sort();
    final proofs=<String,Map<String,Object?>>{};
    for(final p in [...(jsonDecode(fresh['source_stamp'] as String) as List),...pending.stamp]) {
      final proof=Map<String,Object?>.from(p as Map);proofs['${proof['table']}:${proof['id']}']=proof;
    }
    final inherited=_inherited(pending);
    final fits=sources.length<=maxSources && proofs.length<=160 && jsonEncode(proofs.values.toList()).length<=24000 && jsonEncode(inherited).length<=16000;
    if(!cancel && !fits) {
      await sql.update('qq_reply_tasks',{'valid':0,'stage':'source_limit','draft':''},where:'id=?',whereArgs:[pending.id]);
      return false;
    }
    if(!await QqArchiveReader(sql).matches([...proofs.values]))throw const BrainWorkInvalidated();
    await sql.update('qq_reply_tasks', {'last_trigger_seq':b.through, 'valid':0,
      'stage':cancel?'cancelled':'continued','draft':''},where:'id=?',whereArgs:[pending.id]);
    final history=await BrainWorkFence.value(sql,QqFailure.historyKey);
    await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',[QqFailure.historyKey,
      cancel?QqFailureHistory.finish(history,pending.id,'cancelled'):QqFailureHistory.link(history,pending.id,b.id)]);
    if (!cancel) {
      final oldExpiry=pending.row['expires_at'] as int;
      final expiry=fresh['expires_at'] as int;
      await sql.update('qq_reply_tasks', {'sources':jsonEncode(sources),'source_stamp':jsonEncode(proofs.values.toList()),'addressed':1,
        'expires_at':oldExpiry<expiry?oldExpiry:expiry,
        'source_at':pending.row['source_at'],
        'draft':jsonEncode({...((fresh['draft'] as String).isEmpty?{}:jsonDecode(fresh['draft'] as String) as Map),
          'inherited_delivery':inherited})},where:'id=?',whereArgs:[b.id]);
    }
    return true;
  });
}
