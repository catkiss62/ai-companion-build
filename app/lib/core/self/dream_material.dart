import '../database/app_database.dart';
import '../memory/memory_retrieval_policy.dart';
import '../reflection/deep_reflection_store.dart';
import 'dream_contract.dart';
import 'dream_store.dart';

class DreamMaterial {
  DreamMaterial({required this.sources, required this.cursor,
    required this.background, required this.stamp, required this.hasBacklog,
    required this.bootstrap});
  final List<DreamSource> sources;
  final Map<String, Object?> cursor;
  final List<Map<String, Object?>> background;
  final String stamp;
  final bool hasBacklog, bootstrap;
  bool get hasNew => sources.any((s) => s.fresh);

  static Future<DreamMaterial> collect(AppDatabase db, Map<String, dynamic> state,
      DateTime now, {required bool weekly}) async {
    final handle = await db.database;
    final stamp = await DreamStore.messageStamp(handle);
    final cursor = state['cursor'] is Map
        ? Map<String, Object?>.from(state['cursor'] as Map) : <String, Object?>{};
    final bootstrap = cursor.isEmpty;
    final reset = (await db.conversationContextResetAt())?.millisecondsSinceEpoch ?? 0;
    final recentFloor = now.subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    var chatAt = DreamContract.number(cursor['chat_at']);
    var chatId = DreamContract.string(cursor['chat_id']);
    if (bootstrap || reset > chatAt) {
      chatAt = reset > recentFloor ? reset : recentFloor;
      chatId = '';
    }
    final rows = await handle.query('messages',
      columns: ['id', 'role', 'content', 'created_at', 'worldbook_context_json'],
      where: '(created_at > ? OR (created_at = ? AND id > ?)) AND created_at <= ?',
      whereArgs: [chatAt, chatAt, chatId, now.millisecondsSinceEpoch],
      orderBy: bootstrap ? 'created_at DESC, id DESC' : 'created_at ASC, id ASC',
      limit: bootstrap ? 120 : 240);
    final ordered = bootstrap ? rows.reversed.toList() : rows;
    final excluded = await DreamStore.roleplayUsers(handle, ordered);
    final sources = <DreamSource>[];
    var chars = 0;
    var consumed = 0;
    for (final row in ordered) {
      final source = excluded.contains(row['id']) ? null : DreamStore.chatSource(row, fresh: true);
      if (source != null && chars + source.text.length > 64000) break;
      if (source != null) { sources.add(source); chars += source.text.length; }
      chatAt = DreamContract.number(row['created_at']);
      chatId = DreamContract.string(row['id']);
      consumed++;
    }
    var webAt = DreamContract.number(cursor['web_at']);
    var webId = DreamContract.string(cursor['web_id']);
    if (bootstrap) webAt = recentFloor;
    final pages = await handle.query('public_web_candidates',
      where: "read_state = 'verified' AND semantic_state = 'valid' AND lifecycle_state NOT IN ('discarded','declined','user_deleted') AND (read_at > ? OR (read_at = ? AND id > ?)) AND read_at <= ?",
      whereArgs: [webAt, webAt, webId, now.millisecondsSinceEpoch],
      orderBy: 'read_at ASC, id ASC', limit: 12);
    for (final row in pages) {
      final source = DreamStore.webSource(row, fresh: true);
      if (source != null) sources.add(source);
      webAt = DreamContract.number(row['read_at']);
      webId = DreamContract.string(row['id']);
    }
    final knownIds = sources.map((s) => s.id).toSet();
    // Old representative evidence is fetched from originals. It never becomes
    // fresh just because tonight's model looks at it again.
    final refs = DreamContract.records(state['insights'])
        .expand((i) => DreamContract.records(i['evidence']))
        .map((r) => DreamContract.string(r['id'])).toSet();
    for (final old in (await DreamStore.originals(handle, refs)).values) {
      if (knownIds.add(old.id)) sources.add(old);
    }
    final query = sources.where((s) => s.fresh).map((s) => s.text).join('\n');
    if (weekly || query.isNotEmpty) {
      final recent = await handle.query('messages',
        columns: ['id', 'role', 'content', 'created_at', 'worldbook_context_json'],
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [reset > recentFloor ? reset : recentFloor, now.millisecondsSinceEpoch],
        orderBy: 'created_at DESC, id DESC', limit: 100);
      var relatedCount = 0;
      final excludedRecent = await DreamStore.roleplayUsers(handle, recent);
      for (final row in recent) {
        if (excludedRecent.contains(row['id'])) continue;
        final source = DreamStore.chatSource(row);
        if (source == null || knownIds.contains(source.id)) continue;
        // Never put not-yet-processed backlog in the old/context bucket.
        if (source.at > chatAt || (source.at == chatAt && source.id.substring(5).compareTo(chatId) > 0)) continue;
        if (!weekly && !MemoryRetrievalPolicy.hasDirectTextEvidence(query, source.text)) continue;
        sources.add(source); knownIds.add(source.id);
        if (++relatedCount >= (weekly ? 24 : 12)) break;
      }
    }
    final background = <Map<String, Object?>>[];
    for (final row in await handle.query('memory_items',
        columns: ['id', 'kind', 'content', 'first_observed_at', 'created_at', 'semantic_type'],
        where: "status = 'active' AND kind IN ('ai_self','shared_experience','preference')",
        orderBy: 'updated_at DESC', limit: 100)) {
      final text = row['content'] as String? ?? '';
      if (row['kind'] != 'ai_self' && !MemoryRetrievalPolicy.hasDirectTextEvidence(query, text)) continue;
      background.add({'kind': 'prior_memory_interpretation', 'memory_kind': row['kind'],
        'text': DreamStore.clip(text, 400),
        'original_record_at': row['first_observed_at'] ?? row['created_at'],
        'evidence_allowed': false});
      if (background.length >= 16) break;
    }
    final discussion = DeepReflectionStore.decode(await db.getSetting(DeepReflectionStore.stateKey) ?? '')['topic'];
    if (discussion is Map && discussion['phase'] == 'settled') {
      background.add({'kind': 'previous_discussed_view', 'text': DreamStore.clip('${discussion['view']}'),
        'evidence_allowed': false});
    }
    return DreamMaterial(sources: sources, cursor: {'chat_at': chatAt, 'chat_id': chatId,
      'web_at': webAt, 'web_id': webId}, background: background, stamp: stamp,
      bootstrap: bootstrap, hasBacklog: consumed < ordered.length ||
        (!bootstrap && rows.length == 240) || pages.length == 12);
  }
}
