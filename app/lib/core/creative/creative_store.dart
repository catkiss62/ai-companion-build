import 'dart:convert';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import 'creative_contract.dart';

class CreativeStore {
  CreativeStore(this.db);
  final AppDatabase db;
  static String key(String id) => '${CreativeContract.metaPrefix}$id';
  Future<Map<String, dynamic>> get(String id) async => CreativeContract.decode(await db.getSetting(key(id)));

  Future<List<Map<String, dynamic>>> list({bool pendingOnly = false}) async {
    final handle = await db.database;
    final keys = await handle.query('settings', columns: ['key'],
        where: pendingOnly ? 'key LIKE ? AND (value LIKE ? OR value LIKE ? OR value LIKE ?)' : 'key LIKE ?',
        whereArgs: ['${CreativeContract.metaPrefix}%', if (pendingOnly) ...['%"status":"queued"%', '%"status":"building"%', '%"status":"checking"%']]);
    final works = <Map<String, dynamic>>[];
    for (final row in keys) {
      final work = CreativeContract.decode(await db.getSetting(row['key'] as String));
      if (work.isNotEmpty && work['status'] != 'deleted' &&
          (!pendingOnly || CreativeContract.active.contains(work['status']))) works.add(work);
    }
    works.sort((a, b) => (b['updated'] as int).compareTo(a['updated'] as int));
    return works;
  }

  Future<bool> write(Map<String, dynamic> before, Map<String, dynamic> after,
      {Map<String, String> extra = const {}, BrainWorkFence? fence}) async {
    final owned = fence ?? await db.captureBrainWorkFence();
    if (owned == null) return false;
    final id = after['id'] as String;
    return db.setSettingsAtomically({key(id): jsonEncode(after), ...extra},
        expectedSettings: {key(id): before.isEmpty ? '' : jsonEncode(before)}, workFence: owned);
  }

  Future<Map<String, dynamic>> commission({required bool deepThinking,
      required String requestId, required String messageId, required String brief,
      required String requestQuote, required String latestText, String workId = ''}) async {
    if (!deepThinking || requestId.isEmpty || messageId.isEmpty ||
        requestQuote.trim().isEmpty || !latestText.contains(requestQuote) || brief.trim().isEmpty) {
      throw const FormatException('本轮未授权制作；需要在深度思考中明确委托');
    }
    final id = workId.isEmpty ? CreativeContract.hash(requestId).substring(0, 24) : workId;
    final before = await get(id);
    if (before['request_id'] == requestId) return before;
    if (workId.isNotEmpty && (before.isEmpty || before['status'] == 'deleted')) {
      throw const FormatException('找不到要修改的作品');
    }
    if (CreativeContract.active.contains(before['status'])) {
      throw const FormatException('这件作品正在制作，请先停止或等它完成');
    }
    final after = <String, dynamic>{...before,
      'schema': 1, 'id': id, 'request_id': requestId, 'message_id': messageId,
      'brief': CreativeContract.clip(brief, 8000), 'title': before['title'] ?? '新的小作品',
      'intro': before['intro'] ?? '', 'status': 'queued', 'attempts': 0,
      'updated': DateTime.now().millisecondsSinceEpoch,
      'model': await db.getSetting('creative_work_model') ?? 'deepseek-flash',
      'effort': await db.getSetting('creative_work_effort') ?? 'max',
      'note': '等待后台制作', 'draft': '', 'errors': <Object?>[],
      'versions': before['versions'] ?? <Object?>[],
    };
    if (!await write(before, after)) throw const BrainWorkInvalidated();
    return after;
  }

  Future<void> stop(String id) async {
    final before = await get(id);
    if (before.isEmpty) return;
    await write(before, {...before, 'status': 'paused', 'note': '已暂停'});
  }

  Future<void> resume(String id, {required bool deepThinking}) async {
    if (!deepThinking) throw const FormatException('开启深度思考后才能继续制作');
    final before = await get(id);
    if (!{'paused', 'failed'}.contains(before['status'])) return;
    await write(before, {...before, 'status': 'queued', 'attempts': 0,
      'updated': DateTime.now().millisecondsSinceEpoch, 'note': '等待继续制作'});
  }

  Future<void> delete(String id) async {
    final before = await get(id);
    if (before.isEmpty) return;
    final stateKey = '${CreativeContract.playPrefix}$id';
    await write(before, {'schema': 1, 'id': id, 'status': 'deleted',
      'request_id': before['request_id'], 'message_id': before['message_id'],
      'updated': DateTime.now().millisecondsSinceEpoch}, extra: {stateKey: ''});
    await collectUnusedSources();
  }

  Future<void> collectUnusedSources() async {
    // Same transaction as the reference scan, so a concurrent publish cannot
    // lose its source. Tombstones fence network completions after deletion.
    final handle = await db.database;
    await handle.transaction((txn) async {
      if (!await BrainWorkFence.workAllowed(txn)) return;
      final rows = await txn.query('settings', columns: ['key', 'value'],
        where: 'key LIKE ? OR key LIKE ?', whereArgs: [
          '${CreativeContract.metaPrefix}%', '${CreativeContract.playPrefix}%']);
      final keep = <String>{};
      for (final row in rows) {
        final data = CreativeContract.decode(row['value'] as String?);
        for (final field in ['draft', 'current', 'version']) {
          if (data[field] is String) keep.add(data[field] as String);
        }
        keep.addAll((data['versions'] as List? ?? []).whereType<String>());
      }
      final sources = await txn.query('settings', columns: ['key'], where: 'key LIKE ?',
          whereArgs: ['${CreativeContract.sourcePrefix}%']);
      for (final row in sources) {
        final key = row['key'] as String;
        if (!keep.contains(key.substring(CreativeContract.sourcePrefix.length))) {
          await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
        }
      }
    });
  }
}
