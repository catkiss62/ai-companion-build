import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Portable QQ history, with no dependency on main-message/growth consumers.
abstract final class QqArchiveSchema {
  static const tables = ['qq_conversations','qq_archive','qq_images','qq_notes','qq_deliveries','qq_shares','qq_receipts'];
  static const columns = <String,Set<String>>{
    'qq_conversations':{'id','scope','kind','target','checked_seq','summary_checked_seq','summary_seq','last_reply_at','version'},
    'qq_archive':{'seq','id','conversation_id','platform_id','sender','owner','role','content','observed_at','received_at','mentioned','reply_to','accepted_identity','accepted_policy','version'},
    'qq_images':{'id','archive_seq','ordinal','state','description','fingerprint','version'},
    'qq_notes':{'id','conversation_id','content','sources','source_stamp','through_seq','created_at','valid'},
    'qq_deliveries':{'id','conversation_id','through_seq','state','content','sticker_key','updated_at'},
    'qq_shares':{'id','note_id','state','destination','content','updated_at'},
    'qq_receipts':{'id','message_id','message_revision','source_stamp','created_at'},
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
      content TEXT NOT NULL, observed_at INTEGER NOT NULL, received_at INTEGER NOT NULL,
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
      through_seq INTEGER NOT NULL, created_at INTEGER NOT NULL, valid INTEGER NOT NULL DEFAULT 1)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_deliveries (
      id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES qq_conversations(id),
      through_seq INTEGER NOT NULL, state TEXT NOT NULL, content TEXT NOT NULL DEFAULT '',
      sticker_key TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_shares (
      id TEXT PRIMARY KEY, note_id TEXT NOT NULL REFERENCES qq_notes(id), state TEXT NOT NULL,
      destination TEXT NOT NULL DEFAULT '', content TEXT NOT NULL, updated_at INTEGER NOT NULL)''');
    await sql.execute('''CREATE TABLE IF NOT EXISTS qq_receipts (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, message_revision INTEGER NOT NULL, source_stamp TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await sql.execute('CREATE INDEX IF NOT EXISTS qq_receipts_message ON qq_receipts(message_id,message_revision)');
  }

  /// Complete structural/provenance validation BEFORE live-state replacement.
  static void validate(Map<String,dynamic> raw,{required int version}) {
    if(version<62) { for(final t in tables) { raw[t]=<Object?>[]; } return; }
    final conversations=<String,Map>{}; final seqs=<int,String>{}; final maxima=<String,int>{};
    final noteIds=<String>{};
    for(final table in tables) {
      final rows=raw[table];
      if(rows is! List || rows.length>250000) throw const FormatException('QQ分区缺失或过大');
      final ids=<String>{};
      for(final row in rows) {
        if(row is! Map || row.length!=columns[table]!.length || !row.keys.toSet().containsAll(columns[table]!) ||
            row['id'] is! String || (row['id'] as String).isEmpty || !ids.add(row['id'] as String) ||
            row.values.any((v)=>v is! String && v is! int) ||
            row.entries.any((e)=>e.value is String && (e.value as String).length>
              (table=='qq_receipts' && e.key=='source_stamp'?256000:24000))) throw const FormatException('QQ记录字段无效');
        if(table=='qq_conversations') {
          if(!const {'private','group'}.contains(row['kind']) || row['scope'] is! String || row['target'] is! String ||
              ['checked_seq','summary_checked_seq','summary_seq','last_reply_at','version'].any((k)=>row[k] is! int || (row[k] as int)<0)) throw const FormatException('QQ会话无效');
          conversations[row['id'] as String]=row;
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
            final seq=row['seq'];
            if(seq is! int || seq<=0 || seqs.containsKey(seq) || !const {'user','assistant'}.contains(row['role']) ||
                row['observed_at'] is! int || row['received_at'] is! int || row['version'] is! int ||
                !const {0,1}.contains(row['owner']) || !const {0,1}.contains(row['mentioned'])) throw const FormatException('QQ原文无效');
            seqs[seq]=cid as String;
            if(seq>(maxima[cid]??0)) maxima[cid]=seq;
          } else if(table=='qq_notes') {
            final sources=jsonDecode(row['sources'] as String);
            if(sources is! List || sources.isEmpty || sources.length>80 || sources.any((s)=>s is! int || seqs[s]!=cid) ||
                row['through_seq'] is! int || row['created_at'] is! int || !const {0,1}.contains(row['valid'])) throw const FormatException('QQ记忆证据无效');
            noteIds.add(row['id'] as String);
          } else if(row['through_seq'] is! int || seqs[row['through_seq']]!=cid) {
            throw const FormatException('QQ投递来源无效');
          }
        }
      }
    }
    for(final c in conversations.values) {
      for(final key in ['checked_seq','summary_checked_seq','summary_seq']) {
        if((c[key] as int)>(maxima[c['id']]??0)) throw const FormatException('QQ处理位置越界');
      }
    }
  }
  static Future<void> restored(DatabaseExecutor sql) async {
    await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',['qq_master_enabled_v2','0']);
    await sql.delete('settings',where:'key=?',whereArgs:['qq_master_owner_v2']);
    await sql.execute("UPDATE qq_deliveries SET state = 'restored_history' WHERE state NOT IN ('sent','send_uncertain')");
    await sql.execute("UPDATE qq_shares SET state = 'restored_history' WHERE state != 'sent'");
    await sql.execute('UPDATE qq_conversations SET checked_seq=COALESCE((SELECT MAX(seq) FROM qq_archive WHERE conversation_id=qq_conversations.id),0), summary_checked_seq=COALESCE((SELECT MAX(seq) FROM qq_archive WHERE conversation_id=qq_conversations.id),0), version=version+1');
  }
}
