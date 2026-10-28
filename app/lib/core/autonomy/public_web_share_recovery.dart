import 'package:sqflite/sqflite.dart';

/// One retry on a later ordinary selection opportunity, never a paid retry
/// loop inside a share or a timer that resurrects rejected material.
abstract final class PublicWebShareRecovery {
  static const maxFailures = 2;
  static const cooldown = Duration(minutes: 10);
  static Future<void> upgrade(DatabaseExecutor db) async {
    final columns=(await db.rawQuery('PRAGMA table_info(public_web_candidates)')).map((r)=>r['name']).toSet();
    for(final e in const {'share_retry_at':"INTEGER NOT NULL DEFAULT 0",'share_retry_count':"INTEGER NOT NULL DEFAULT 0",'share_last_error':"TEXT NOT NULL DEFAULT ''"}.entries) {
      if(!columns.contains(e.key))await db.execute('ALTER TABLE public_web_candidates ADD COLUMN ${e.key} ${e.value}');
    }
  }
  static void normalizeImport(Map tables,{required int version}) {
    final rows=tables['public_web_candidates'];
    if(rows is! List)return;
    for(final row in rows.whereType<Map>()) {
      if(version<67)row.addAll({'share_retry_at':0,'share_retry_count':0,'share_last_error':''});
      if(row['share_retry_at'] is! int || row['share_retry_count'] is! int ||
        (row['share_retry_at'] as int)<0 || (row['share_retry_count'] as int)<0 ||
        (row['share_retry_count'] as int)>maxFailures || row['share_last_error'] is! String ||
        !RegExp(r'^[a-z0-9_]{0,64}$').hasMatch(row['share_last_error'] as String)) {
        throw const FormatException('网页分享恢复记录无效');
      }
    }
  }
  static Future<void> restored(DatabaseExecutor db) async {
    await db.execute("UPDATE public_web_candidates SET lifecycle_state='reviewed',share_retry_at=0 WHERE share_retry_count>0 AND lifecycle_state IN ('unread','share_staging')");
  }
}
