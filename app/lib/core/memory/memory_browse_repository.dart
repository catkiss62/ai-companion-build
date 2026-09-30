import '../database/app_database.dart';
import '../models/memory_item.dart';

/// Reads stored memories for human browsing. It deliberately does not use the
/// AI retrieval path, recall accounting, topic repair, or memory maintenance.
class MemoryBrowseRepository {
  MemoryBrowseRepository(this.db);

  final AppDatabase db;
  static const int _pageSize = 256;

  /// Reads every active memory from one consistent database snapshot. Paging
  /// keeps each cursor bounded without the list screen's 300-record limit.
  Future<List<MemoryItem>> allActive() async {
    final database = await db.database;
    return database.transaction((txn) async {
      final items = <MemoryItem>[];
      int? afterCreatedAt;
      String? afterId;
      while (true) {
        final rows = await txn.query(
          'memory_items',
          where: afterCreatedAt == null
              ? 'status = ?'
              : 'status = ? AND (created_at > ? OR '
                    '(created_at = ? AND id > ?))',
          whereArgs: afterCreatedAt == null
              ? const <Object?>['active']
              : <Object?>['active', afterCreatedAt, afterCreatedAt, afterId],
          orderBy: 'created_at ASC, id ASC',
          limit: _pageSize,
        );
        items.addAll(rows.map(MemoryItem.fromDb));
        if (rows.length < _pageSize) break;
        afterCreatedAt = rows.last['created_at'] as int;
        afterId = rows.last['id'] as String;
      }
      return List<MemoryItem>.unmodifiable(items);
    }, exclusive: false);
  }

  /// Shows only an existing, exact nonempty topic association. It does not
  /// infer an association from category, prose, or a subject key.
  Future<List<MemoryItem>> sameTopic(MemoryItem item, {int limit = 6}) async {
    final topic = item.topicKey;
    if (topic.trim().isEmpty || limit <= 0) return const <MemoryItem>[];
    final database = await db.database;
    final rows = await database.query(
      'memory_items',
      where: 'status = ? AND topic_key = ? AND id != ?',
      whereArgs: <Object?>['active', topic, item.id],
      orderBy: 'importance DESC, updated_at DESC, id ASC',
      limit: limit.clamp(1, 100).toInt(),
    );
    return List<MemoryItem>.unmodifiable(rows.map(MemoryItem.fromDb));
  }
}
