import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/memory/local_semantic_index.dart';
import '../../core/models/memory_item.dart';

/// Only indexes the older notes supplied by this group's archive reader.
class QqSemanticRecall {
  QqSemanticRecall({LocalSemanticIndex Function(String)? indexFactory})
    : _indexFactory = indexFactory ?? _groupIndex;

  final LocalSemanticIndex Function(String) _indexFactory;
  final _indexes = <String, LocalSemanticIndex>{};
  static const _queryBudget = Duration(milliseconds: 450);

  static LocalSemanticIndex _groupIndex(String conversation) {
    final key = sha256.convert(utf8.encode(conversation));
    return LocalSemanticIndex(
      cacheFile: () async {
        final directory = await getApplicationCacheDirectory();
        return File(
          '${directory.path}/qq-$key-${LocalSemanticIndex.modelIdentity}.json',
        );
      },
    );
  }

  Future<List<Map<String, Object?>>> rank(
    String conversation,
    String query,
    List<Map<String, Object?>> notes,
  ) async {
    if (notes.isEmpty || query.trim().runes.length < 2) return const [];
    final index = _indexes.putIfAbsent(
      conversation,
      () => _indexFactory(conversation),
    );
    final items = notes.map((note) {
      final created = DateTime.fromMillisecondsSinceEpoch(
        note['created_at'] as int,
      );
      return MemoryItem(
        id: note['id'] as String,
        kind: 'event',
        content: note['content'] as String,
        importance: 0.5,
        createdAt: created,
        updatedAt: created,
      );
    }).toList();
    final scores = await index
        .search(query, items, queryBudget: _queryBudget)
        .timeout(_queryBudget, onTimeout: () => const <String, double>{});
    if (scores.isEmpty) return const [];
    final related = notes
        .where((note) => (scores[note['id']] ?? -1) >= .55)
        .toList();
    related.sort((a, b) => scores[b['id']]!.compareTo(scores[a['id']]!));
    return related;
  }
}
