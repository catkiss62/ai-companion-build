import '../database/app_database.dart';
import '../models/memory_item.dart';

class MemoryBrowseCursor {
  const MemoryBrowseCursor({
    required this.importance,
    required this.updatedAt,
    required this.id,
  });

  final double importance;
  final int updatedAt;
  final String id;
}

class MemoryBrowsePage {
  const MemoryBrowsePage({required this.items, this.nextCursor});

  final List<MemoryItem> items;
  final MemoryBrowseCursor? nextCursor;
}

/// Reads stored memories for human browsing. It deliberately does not use the
/// AI retrieval path, recall accounting, topic repair, or memory maintenance.
class MemoryBrowseRepository {
  MemoryBrowseRepository(this.db);

  final AppDatabase db;
  static const int _pageSize = 256;

  /// Keeps the list's importance/recent-update order, with a stable ID tie-break
  /// so equal-ranked memories remain reachable beyond the first page.
  Future<MemoryBrowsePage> page({
    String? kind,
    String status = 'active',
    String query = '',
    MemoryBrowseCursor? after,
    int limit = 100,
  }) async {
    final database = await db.database;
    final clauses = <String>['status = ?'];
    final args = <Object?>[status];
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      clauses.add('kind = ?');
      args.add(kind);
    }
    final term = query.trim();
    if (term.isNotEmpty) {
      final escaped = term
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      clauses.add("(content LIKE ? ESCAPE '\\' OR tags LIKE ? ESCAPE '\\' "
          "OR subject_key LIKE ? ESCAPE '\\')");
      args.addAll(List<Object?>.filled(3, '%$escaped%'));
    }
    if (after != null) {
      clauses.add('(importance < ? OR (importance = ? AND '
          '(updated_at < ? OR (updated_at = ? AND id > ?))))');
      args.addAll([
        after.importance,
        after.importance,
        after.updatedAt,
        after.updatedAt,
        after.id,
      ]);
    }
    final pageSize = limit.clamp(1, _pageSize).toInt();
    final rows = await database.query(
      'memory_items',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'importance DESC, updated_at DESC, id ASC',
      limit: pageSize + 1,
    );
    final items = List<MemoryItem>.unmodifiable(
      rows.take(pageSize).map(MemoryItem.fromDb),
    );
    final last = items.isEmpty ? null : items.last;
    return MemoryBrowsePage(
      items: items,
      nextCursor: rows.length > pageSize && last != null
          ? MemoryBrowseCursor(
              importance: last.importance,
              updatedAt: last.updatedAt.millisecondsSinceEpoch,
              id: last.id,
            )
          : null,
    );
  }

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
