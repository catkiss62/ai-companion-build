import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../qq/qq_message_material.dart';

/// Portable QQ history, with no dependency on main-message/growth consumers.
abstract final class QqArchiveSchema {
  static const additions=['qq_ingress','qq_work_items','qq_styles','qq_sketches','qq_voices'];
  static const tables = ['qq_conversations','qq_archive','qq_images','qq_notes','qq_deliveries','qq_shares','qq_receipts',...additions];
  static const columns = <String,Set<String>>{
    'qq_conversations':{'id','scope','kind','target','checked_seq','summary_checked_seq','summary_seq','last_reply_at','version'},
    'qq_archive':{'seq','id','conversation_id','platform_id','sender','owner','role','content','context_meta','observed_at','received_at','mentioned','reply_to','accepted_identity','accepted_policy','version'},
    'qq_images':{'id','archive_seq','ordinal','state','description','fingerprint','version'},
    'qq_notes':{'id','conversation_id','content','sources','source_stamp','through_seq','created_at','valid','range_start','range_end','revision','edited_at'},
    'qq_deliveries':{'id','conversation_id','through_seq','state','content','sticker_key','updated_at'},
    'qq_shares':{'id','note_id','state','destination','content','updated_at'},
    'qq_receipts':{'id','message_id','message_revision','source_stamp','created_at'},
    'qq_ingress':{'id','expires_at'},
    'qq_work_items':{'id','conversation_id','kind','sources','identity','permit','state','attempts','next_at','run_token','created_at','updated_at'},
    'qq_styles':{'id','conversation_id','content','sources','source_stamp','revision','enabled','edited_at','created_at'},
    'qq_sketches':{'id','archive_seq','svg','description','created_at'},
    'qq_voices':{'id','archive_seq','language','created_at'},
  };
  static Future<void> create(DatabaseExecutor sql) async {
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_conversations (
      id TEXT PRIMARY KEY, scope TEXT NOT NULL, kind TEXT NOT NULL, target TEXT NOT NULL,
      checked_seq INTEGER NOT NULL DEFAULT 0, summary_checked_seq INTEGER NOT NULL DEFAULT 0,
      summary_seq INTEGER NOT NULL DEFAULT 0, last_reply_at INTEGER NOT NULL DEFAULT 0,
      version INTEGER NOT NULL DEFAULT 1)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_archive (
      seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE,
      conversation_id TEXT NOT NULL REFERENCES qq_conversations(id), platform_id TEXT NOT NULL,
      sender TEXT NOT NULL, owner INTEGER NOT NULL DEFAULT 0, role TEXT NOT NULL,
      content TEXT NOT NULL, context_meta TEXT NOT NULL DEFAULT '', observed_at INTEGER NOT NULL, received_at INTEGER NOT NULL,
      mentioned INTEGER NOT NULL DEFAULT 0, reply_to TEXT NOT NULL DEFAULT '',
      accepted_identity TEXT NOT NULL DEFAULT '', accepted_policy TEXT NOT NULL DEFAULT '', version INTEGER NOT NULL DEFAULT 1)''');
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_archive_conversation ON qq_archive(conversation_id,seq)');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_images (
      id TEXT PRIMARY KEY, archive_seq INTEGER NOT NULL REFERENCES qq_archive(seq),
      ordinal INTEGER NOT NULL, state TEXT NOT NULL DEFAULT 'unseen', description TEXT NOT NULL DEFAULT '',
      fingerprint TEXT NOT NULL DEFAULT '', version INTEGER NOT NULL DEFAULT 1)''');
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_images_source ON qq_images(archive_seq,ordinal)');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_notes (
      id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES qq_conversations(id),
      content TEXT NOT NULL, sources TEXT NOT NULL, source_stamp TEXT NOT NULL,
      through_seq INTEGER NOT NULL, created_at INTEGER NOT NULL, valid INTEGER NOT NULL DEFAULT 1,
      range_start INTEGER NOT NULL DEFAULT 0, range_end INTEGER NOT NULL DEFAULT 0,
      revision INTEGER NOT NULL DEFAULT 1, edited_at INTEGER NOT NULL DEFAULT 0)''');
    // Existing schema62 tables get these columns in upgradeMonthly first.
    if((await sql.rawQuery('PRAGMA table_info(qq_notes)')).any((r)=>r['name']=='range_start')) {
      await sql.execute('CREATE INDEX IF NOT EXISTS qq_notes_range ON qq_notes(conversation_id,range_start,range_end)');
    }
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_deliveries (
      id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES qq_conversations(id),
      through_seq INTEGER NOT NULL, state TEXT NOT NULL, content TEXT NOT NULL DEFAULT '',
      sticker_key TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_shares (
      id TEXT PRIMARY KEY, note_id TEXT NOT NULL REFERENCES qq_notes(id), state TEXT NOT NULL,
      destination TEXT NOT NULL DEFAULT '', content TEXT NOT NULL, updated_at INTEGER NOT NULL)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_receipts (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, message_revision INTEGER NOT NULL, source_stamp TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_receipts_message ON qq_receipts(message_id,message_revision)');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_ingress(id TEXT PRIMARY KEY,expires_at INTEGER NOT NULL)''');
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_ingress_expiry ON qq_ingress(expires_at)');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_work_items(
      id TEXT PRIMARY KEY,conversation_id TEXT NOT NULL REFERENCES qq_conversations(id),kind TEXT NOT NULL,
      sources TEXT NOT NULL,identity TEXT NOT NULL,permit TEXT NOT NULL,state TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,next_at INTEGER NOT NULL DEFAULT 0,run_token TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL)''');
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_work_due ON qq_work_items(conversation_id,kind,state,next_at)');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_styles(
      id TEXT PRIMARY KEY,conversation_id TEXT NOT NULL REFERENCES qq_conversations(id),content TEXT NOT NULL,
      sources TEXT NOT NULL,source_stamp TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 1,
      enabled INTEGER NOT NULL DEFAULT 1,edited_at INTEGER NOT NULL DEFAULT 0,created_at INTEGER NOT NULL)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_sketches(
      id TEXT PRIMARY KEY,archive_seq INTEGER NOT NULL REFERENCES qq_archive(seq),svg TEXT NOT NULL,
      description TEXT NOT NULL,created_at INTEGER NOT NULL)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_voices(
      id TEXT PRIMARY KEY,archive_seq INTEGER NOT NULL REFERENCES qq_archive(seq),
      language TEXT NOT NULL,created_at INTEGER NOT NULL)''');
    await sql.execute('CREATE UNIQUE INDEX IF NOT EXISTS qq_voice_source ON qq_voices(archive_seq)');
  }

  static Future<void> upgradeMaterial(DatabaseExecutor sql) async {
    final fields=await sql.rawQuery('PRAGMA table_info(qq_archive)');
    if(!fields.any((r)=>r['name']=='context_meta')) {
      await sql.execute("ALTER TABLE qq_archive ADD COLUMN context_meta TEXT NOT NULL DEFAULT ''");
    }
  }

  static Future<void> upgradeWork(DatabaseExecutor sql) async {
    await create(sql);
    // Keep original receive receipts through current-record deletion. They
    // contain only opaque IDs and expire, never chat content or credentials.
    await sql.execute("INSERT OR IGNORE INTO qq_ingress(id,expires_at) SELECT id,received_at+86400000 FROM qq_archive WHERE role='user'");
    final rows=await sql.rawQuery('SELECT c.id,COALESCE(MAX(a.seq),0) AS through FROM qq_conversations c LEFT JOIN qq_archive a ON a.conversation_id=c.id GROUP BY c.id');
    for(final row in rows) await sql.rawInsert('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)',['qq_style_cursor_v1:${row['id']}','${row['through']}']);
  }

  /// Upgrade source ranges without rewriting summary text or its evidence.
  static Future<void> upgradeMonthly(DatabaseExecutor sql) async {
    final fields=(await sql.rawQuery('PRAGMA table_info(qq_notes)')).map((r)=>r['name']).toSet();
    for(final field in ['range_start','range_end','revision','edited_at']) {
      if(!fields.contains(field)) await sql.execute('ALTER TABLE qq_notes ADD COLUMN $field INTEGER NOT NULL DEFAULT ${field=='revision'?1:0}');
    }
    final notes=await sql.query('qq_notes',columns:['id','sources'],where:'range_start=0 AND range_end=0');
    for(final note in notes) {
      final ids=(jsonDecode(note['sources'] as String) as List).cast<int>();
      if(ids.isEmpty) continue;
      final range=(await sql.rawQuery('SELECT MIN(observed_at) AS first,MAX(observed_at) AS last FROM qq_archive WHERE seq IN (${List.filled(ids.length,'?').join(',')})',ids)).single;
      await sql.update('qq_notes',{'range_start':range['first']??0,'range_end':range['last']??0},where:'id=?',whereArgs:[note['id']]);
    }
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_notes_range ON qq_notes(conversation_id,range_start,range_end)');
  }

  /// Complete structural/provenance validation BEFORE live-state replacement.
  static void validate(Map<String,dynamic> raw,{required int version}) {
    if(version<62) { for(final t in tables) { raw[t]=<Object?>[]; } return; }
    if(version<64) {for(final t in additions)raw[t]=<Object?>[];}
    if(version<66)raw['qq_voices']=<Object?>[];
    final conversations=<String,Map>{}; final seqs=<int,String>{}; final maxima=<String,int>{};
    final noteIds=<String>{}; final observed=<int,int>{};final roles=<int,String>{};final voiceSeqs=<int>{};
    for(final table in tables) {
      final rows=raw[table];
      if(rows is! List || rows.length>250000) throw const FormatException('QQ分区缺失或过大');
      final ids=<String>{};
      for(final row in rows) {
        if(table=='qq_archive' && version<65 && row is Map) row.putIfAbsent('context_meta',()=> '');
        if(table=='qq_notes' && version<63 && row is Map) {
          final sources=jsonDecode(row['sources'] as String);
          final times=sources is List?sources.map((id)=>observed[id]).whereType<int>().toList():<int>[];
          times.sort();
          row.addAll(<String,dynamic>{'range_start':times.isEmpty?0:times.first,'range_end':times.isEmpty?0:times.last,'revision':1,'edited_at':0});
        }
        if(row is! Map || row.length!=columns[table]!.length || !row.keys.toSet().containsAll(columns[table]!) ||
            row['id'] is! String || (row['id'] as String).isEmpty || !ids.add(row['id'] as String) ||
            row.values.any((v)=>v is! String && v is! int) ||
            row.entries.any((e)=>e.value is String && (e.value as String).length>
              (const {'qq_receipts','qq_styles'}.contains(table) && e.key=='source_stamp'?256000:24000))) throw const FormatException('QQ记录字段无效');
        if(table=='qq_conversations') {
          if(!const {'private','group'}.contains(row['kind']) || row['scope'] is! String || row['target'] is! String ||
              ['checked_seq','summary_checked_seq','summary_seq','last_reply_at','version'].any((k)=>row[k] is! int || (row[k] as int)<0)) throw const FormatException('QQ会话无效');
          conversations[row['id'] as String]=row;
        } else if(table=='qq_ingress') {
          if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(row['id'] as String) || row['expires_at'] is! int || (row['expires_at'] as int)<0)throw const FormatException('QQ接收回执无效');
        } else if(table=='qq_work_items' || table=='qq_styles') {
          final cid=row['conversation_id'],sources=jsonDecode(row['sources'] as String);
          if(!conversations.containsKey(cid) || sources is! List || sources.isEmpty || sources.length>80 || sources.any((id)=>id is! int || seqs[id]!=cid))throw const FormatException('QQ后台来源无效');
          if(table=='qq_work_items') {
            if(!const {'summary','style'}.contains(row['kind']) || !const {'pending','running','complete','failed','cancelled','restored_history'}.contains(row['state']) ||
              ['attempts','next_at','created_at','updated_at'].any((k)=>row[k] is! int || (row[k] as int)<0) || (row['attempts'] as int)>3 ||
              jsonDecode(row['identity'] as String) is! Map || jsonDecode(row['permit'] as String) is! Map)throw const FormatException('QQ后台进度无效');
          } else if(row['revision'] is! int || (row['revision'] as int)<1 || !const {0,1}.contains(row['enabled']) || row['edited_at'] is! int || row['created_at'] is! int || jsonDecode(row['source_stamp'] as String) is! List || (row['content'] as String).length>1600)throw const FormatException('群聊表达档案无效');
        } else if(table=='qq_voices') {
          if(row['archive_seq'] is! int || roles[row['archive_seq']]!='assistant' ||
            !voiceSeqs.add(row['archive_seq'] as int) || !const {'zh','ja','en'}.contains(row['language']) ||
            row['created_at'] is! int || (row['created_at'] as int)<0)throw const FormatException('QQ语音台词来源无效');
        } else if(table=='qq_sketches') {
          final svg=row['svg'] as String;
          if(!seqs.containsKey(row['archive_seq']) || row['created_at'] is! int || svg.length>16000 || !svg.trimLeft().startsWith('<svg') || RegExp(r'<!|<script|<foreignObject|<image|href\s*=|url\s*\(|\bon[a-z]+\s*=',caseSensitive:false).hasMatch(svg))throw const FormatException('QQ涂鸦无效');
        } else if(table=='qq_images') {
          if(row['archive_seq'] is! int || !seqs.containsKey(row['archive_seq']) || row['ordinal'] is! int ||
              (row['ordinal'] as int)<0 || (row['ordinal'] as int)>=8 || !const {'unseen','viewed','failed','skipped'}.contains(row['state']) ||
              row['version'] is! int || (row['state']=='viewed' && '${row['description']}'.isEmpty)) throw const FormatException('QQ图片来源无效');
        } else if(table=='qq_receipts') {
          if(row['message_revision'] is! int || (row['message_revision'] as int)<0 || row['created_at'] is! int || row['message_id'] is! String) throw const FormatException('QQ消费记录无效');
          final proof=jsonDecode(row['source_stamp'] as String);
          if(proof is! List || proof.length>1200 || proof.any((s)=>s is! Map || s['id'] is! String ||
            !const {'qq_archive','qq_images','qq_notes'}.contains(s['table']) ||
            (s['table']=='qq_notes'?s['token'] is! String:s['version'] is! int || (s['version'] as int)<1))) {
            throw const FormatException('QQ消费来源无效');
          }
        } else if(table=='qq_shares') {
          if(!noteIds.contains(row['note_id'])) throw const FormatException('QQ分享来源缺失');
        } else {
          final cid=row['conversation_id'];
          if(!conversations.containsKey(cid)) throw const FormatException('QQ会话来源缺失');
          if(table=='qq_archive') {
            QqMessageMaterial.decode(row['context_meta'] as String);
            final seq=row['seq'];
            if(seq is! int || seq<=0 || seqs.containsKey(seq) || !const {'user','assistant'}.contains(row['role']) ||
                row['observed_at'] is! int || row['received_at'] is! int || row['version'] is! int ||
                !const {0,1}.contains(row['owner']) || !const {0,1}.contains(row['mentioned'])) throw const FormatException('QQ原文无效');
            seqs[seq]=cid as String; observed[seq]=row['observed_at'] as int;
            roles[seq]=row['role'] as String;
            if(seq>(maxima[cid]??0)) maxima[cid]=seq;
          } else if(table=='qq_notes') {
            final sources=jsonDecode(row['sources'] as String);
            if(sources is! List || sources.isEmpty || sources.length>80 || sources.any((s)=>s is! int || seqs[s]!=cid) ||
                row['through_seq'] is! int || seqs[row['through_seq']]!=cid || row['created_at'] is! int ||
                row['revision'] is! int || (row['revision'] as int)<1 || row['edited_at'] is! int ||
                row['range_start'] is! int || row['range_end'] is! int || (row['range_end'] as int)<(row['range_start'] as int) ||
                !const {0,1}.contains(row['valid'])) throw const FormatException('QQ记忆证据无效');
            noteIds.add(row['id'] as String);
          } else if(row['through_seq'] is! int || seqs[row['through_seq']]!=cid) {
            throw const FormatException('QQ投递来源无效');
          }
        }
      }
    }
    final archiveById={for(final r in raw['qq_archive'] as List)(r as Map)['id']:r};
    final imageById={for(final r in raw['qq_images'] as List)(r as Map)['id']:r};
    for(final profile in raw['qq_styles'] as List) {
      final sources=(jsonDecode(profile['sources'] as String) as List).toSet();
      final proof=jsonDecode(profile['source_stamp'] as String) as List;
      final covered=<int>{};
      if(proof.length>720)throw const FormatException('群聊表达来源过多');
      for(final item in proof) {
        if(item is! Map || item['version'] is! int || (item['version'] as int)<1)throw const FormatException('群聊表达来源版本无效');
        if(item['table']=='qq_archive') {
          final row=archiveById[item['id']];
          if(row==null || row['conversation_id']!=profile['conversation_id'] || row['role']!='user' || !sources.contains(row['seq']))throw const FormatException('群聊表达越过群来源');
          covered.add(row['seq'] as int);
        } else if(item['table']=='qq_images') {
          final image=imageById[item['id']];if(image==null || !sources.contains(image['archive_seq']))throw const FormatException('群聊表达图片来源无效');
        } else {throw const FormatException('群聊表达只能来自本群真人发言');}
      }
      if(covered.length!=sources.length)throw const FormatException('群聊表达来源不完整');
    }
    for(final c in conversations.values) {
      for(final key in ['checked_seq','summary_checked_seq','summary_seq']) {
        if((c[key] as int)>(maxima[c['id']]??0)) throw const FormatException('QQ处理位置越界');
      }
    }
  }
  static Future<void> restored(DatabaseExecutor sql) async {
    await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',['qq_master_enabled_v2','0']);
    // A restored profile is portable data, not permission to start learning.
    await sql.rawUpdate("UPDATE settings SET value='0' WHERE key LIKE 'qq_style_enabled_v1:%'");
    await sql.delete('settings',where:'key=?',whereArgs:['qq_master_owner_v2']);
    await sql.execute("UPDATE qq_deliveries SET state = 'restored_history' WHERE state NOT IN ('sent','send_uncertain','sent_archive_pending','sent_archive_failed','partially_sent')");
    await sql.execute("UPDATE qq_shares SET state = 'restored_history' WHERE state != 'sent'");
    await sql.execute("UPDATE qq_work_items SET state='restored_history',run_token='' WHERE state!='complete'");
    await sql.execute("INSERT OR IGNORE INTO qq_ingress(id,expires_at) SELECT id,received_at+86400000 FROM qq_archive WHERE role='user'");
    await sql.execute('UPDATE qq_conversations SET checked_seq=COALESCE((SELECT MAX(seq) FROM qq_archive WHERE conversation_id=qq_conversations.id),0), summary_checked_seq=COALESCE((SELECT MAX(seq) FROM qq_archive WHERE conversation_id=qq_conversations.id),0), version=version+1');
  }
}
