import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/database/brain_work_fence.dart';
import 'qq_archive_reader.dart';
import 'qq_store.dart';
import 'qq_work_queue.dart';

/// Calendar buckets are a management view, never a new conversation or a
/// retrieval cutoff. Historical months remain available until explicitly deleted.
class QqArchiveMonth {
  QqArchiveMonth(this.start, {this.messages = 0});
  final DateTime start;
  final int messages;
  DateTime get end => DateTime(start.year, start.month + 1);
  String get label => '${start.year}年${start.month}月';
  String get key => '${start.year}-${start.month.toString().padLeft(2, '0')}';
  bool recentAt(DateTime now) => !start.isBefore(DateTime(now.year, now.month - 1));
  static DateTime monthOf(int at) {
    final date = DateTime.fromMillisecondsSinceEpoch(at);
    return DateTime(date.year, date.month);
  }
}

class QqArchiveDeletion {
  const QqArchiveDeletion(this.messages, this.notes, this.rebuilds);
  final int messages, notes, rebuilds;
}

/// Owns administrative edits only. It cannot mutate App messages, private
/// memories, ownership settings, Desire or the future group-learning store.
class QqArchiveAdmin {
  QqArchiveAdmin(this.db);
  final AppDatabase db;
  static String epochKey(String cid) => 'qq_archive_epoch_v1:$cid';

  Future<List<QqArchiveMonth>> months(String cid) async {
    final rows = await (await db.database).rawQuery(
      "SELECT strftime('%Y-%m',observed_at/1000,'unixepoch','localtime') AS month,COUNT(*) AS count "
      'FROM qq_archive WHERE conversation_id=? GROUP BY month ORDER BY month DESC', [cid]);
    return [for (final row in rows) QqArchiveMonth(DateTime.parse('${row['month']}-01'), messages: row['count'] as int)];
  }

  Future<List<Map<String, Object?>>> messages(String cid, QqArchiveMonth month, {int? before}) async =>
    (await db.database).query('qq_archive', where: 'conversation_id=? AND observed_at>=? AND observed_at<? ${before == null ? '' : 'AND seq<?'}',
      whereArgs: [cid, month.start.millisecondsSinceEpoch, month.end.millisecondsSinceEpoch, if (before != null) before], orderBy: 'seq DESC', limit: 50);

  Future<List<Map<String, Object?>>> notes(String cid, QqArchiveMonth month, {int offset = 0}) async =>
    (await db.database).query('qq_notes', where: 'conversation_id=? AND range_start<? AND range_end>=?',
      whereArgs: [cid, month.end.millisecondsSinceEpoch, month.start.millisecondsSinceEpoch], orderBy: 'created_at DESC,id', limit: 30, offset: offset);

  Future<void> _advance(Transaction txn, String cid) async {
    final key = epochKey(cid);
    final old = int.tryParse(await BrainWorkFence.value(txn, key)) ?? 0;
    await txn.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', [key, '${old + 1}']);
    await txn.rawUpdate('UPDATE qq_conversations SET version=version+1 WHERE id=?', [cid]);
  }

  Future<void> editNote(Map<String, Object?> note, String content) async {
    final text = content.trim();
    if (text.isEmpty || text.length > 6000) throw const FormatException('整理记忆需为1–6000字');
    final cid = note['conversation_id'] as String;
    final store = QqStore(db);
    await store.write(await store.capture(conversationId: cid), (txn) async {
      final rows = await txn.query('qq_notes', where: 'id=? AND conversation_id=?', whereArgs: [note['id'], cid], limit: 1);
      if (rows.isEmpty || rows.single['valid'] != 1 || QqArchiveReader.noteToken(rows.single) != QqArchiveReader.noteToken(note)) throw const BrainWorkInvalidated();
      await txn.update('qq_notes', {'content': text, 'revision': (rows.single['revision'] as int) + 1,
        'edited_at': DateTime.now().millisecondsSinceEpoch}, where: 'id=?', whereArgs: [note['id']]);
      // An old pending share must never publish the pre-edit summary.
      await txn.delete('qq_shares', where: 'note_id=?', whereArgs: [note['id']]);
      await _advance(txn, cid);
    });
  }

  Future<void> deleteNote(Map<String, Object?> note) async {
    final cid = note['conversation_id'] as String;
    final store = QqStore(db);
    await store.write(await store.capture(conversationId: cid), (txn) async {
      final rows = await txn.query('qq_notes', where: 'id=? AND conversation_id=?', whereArgs: [note['id'], cid], limit: 1);
      if (rows.isEmpty || QqArchiveReader.noteToken(rows.single) != QqArchiveReader.noteToken(note)) throw const BrainWorkInvalidated();
      await txn.delete('qq_shares', where: 'note_id=?', whereArgs: [note['id']]);
      await txn.delete('qq_notes', where: 'id=?', whereArgs: [note['id']]);
      // Keep the consumed summary cursor: deletion is not permission to learn
      // the same old batch again. Original messages remain explicitly readable.
      await _advance(txn, cid);
    });
  }

  Future<QqArchiveDeletion> deleteRange(String cid, DateTime start, DateTime end, {required int expectedVersion, int? throughSeq}) async {
    if (!start.isBefore(end)) throw const FormatException('日期范围无效');
    final store = QqStore(db);
    return store.write(await store.capture(conversationId: cid), (txn) async {
      final conversations = await txn.query('qq_conversations', where: 'id=?', whereArgs: [cid], limit: 1);
      if (conversations.isEmpty || conversations.single['version'] != expectedVersion) throw const BrainWorkInvalidated();
      final victims = await txn.query('qq_archive', columns: ['seq'], where: 'conversation_id=? AND observed_at>=? AND observed_at<? ${throughSeq == null ? '' : 'AND seq<=?'}',
        whereArgs: [cid, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, if (throughSeq != null) throughSeq]);
      final deleted = victims.map((r) => r['seq'] as int).toSet();
      var removedNotes = 0, rebuilds = 0;
      final notes = await txn.query('qq_notes', where: 'conversation_id=? AND range_start<? AND range_end>=?',
        whereArgs: [cid, end.millisecondsSinceEpoch, start.millisecondsSinceEpoch]);
      for (final note in notes) {
        final sources = (jsonDecode(note['sources'] as String) as List).cast<int>();
        if (!sources.any(deleted.contains)) continue;
        await txn.delete('qq_shares', where: 'note_id=?', whereArgs: [note['id']]);
        final keep = sources.where((id) => !deleted.contains(id)).toList();
        if (keep.isEmpty) {
          await txn.delete('qq_notes', where: 'id=?', whereArgs: [note['id']]); removedNotes++;
        } else {
          final rows = await txn.query('qq_archive', where: 'conversation_id=? AND seq IN (${List.filled(keep.length, '?').join(',')})',
            whereArgs: [cid, ...keep], orderBy: 'seq');
          final times = rows.map((r) => r['observed_at'] as int).toList()..sort();
          // A cross-month summary can contain deleted facts. Withdraw its text
          // and queue only the surviving original evidence for reconstruction.
          await txn.update('qq_notes', {'content': '', 'valid': 0, 'sources': jsonEncode(keep), 'source_stamp': '[]',
            'through_seq': keep.reduce((a, b) => a > b ? a : b), 'range_start': times.first, 'range_end': times.last,
            'revision': (note['revision'] as int) + 1, 'edited_at': 0}, where: 'id=?', whereArgs: [note['id']]);
          rebuilds++;
        }
      }
      await QqWorkQueue.removeSources(txn,cid,deleted);
      // Deliveries and observations must be removed before their source rows.
      for (var offset = 0; offset < victims.length; offset += 200) {
        final ids = victims.skip(offset).take(200).map((r) => r['seq']).toList();
        final slots = List.filled(ids.length, '?').join(',');
        await txn.delete('qq_sketches',where:'archive_seq IN ($slots)',whereArgs:ids);
        await txn.delete('qq_images', where: 'archive_seq IN ($slots)', whereArgs: ids);
        await txn.delete('qq_deliveries', where: 'conversation_id=? AND through_seq IN ($slots)', whereArgs: [cid, ...ids]);
        await txn.delete('qq_archive', where: 'conversation_id=? AND seq IN ($slots)', whereArgs: [cid, ...ids]);
      }
      final max = Sqflite.firstIntValue(await txn.rawQuery('SELECT MAX(seq) FROM qq_archive WHERE conversation_id=?', [cid])) ?? 0;
      await txn.rawUpdate('UPDATE qq_conversations SET checked_seq=MIN(checked_seq,?),summary_seq=MIN(summary_seq,?),summary_checked_seq=MIN(summary_checked_seq,?) WHERE id=?', [max, max, max, cid]);
      await _advance(txn, cid);
      return QqArchiveDeletion(victims.length, removedNotes, rebuilds);
    });
  }
}
