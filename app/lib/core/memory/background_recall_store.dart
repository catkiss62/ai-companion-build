import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../models/memory_item.dart';
import 'memory_revision.dart';
import 'memory_grounding_policy.dart';
import 'memory_retrieval_policy.dart';

class BackgroundRecallSelection {
  BackgroundRecallSelection({required this.raw, required this.item,
    required this.sources, required this.fence, required this.expiresAt});
  final String raw;
  final MemoryItem item;
  final List<QualifiedConversationSource> sources;
  final BrainWorkFence fence;
  final int expiresAt;

  String prompt(DateTime now) {
    final text = MemoryGroundingPolicy.formatForPrompt(item, now: now);
    return '【暂时想起的旧经历 · 内部背景】\n'
      '这是真实旧经历，现在想起不表示事件刚发生。它可以帮助理解或联想，也可以不用；'
      '不用主动提起、续旧话题或按它重演性格。不是新的用户发言、任务或人格证据。\n'
      '${text.length > 1100 ? text.substring(0, 1100) : text}';
  }

  Future<bool> matches(DatabaseExecutor txn, DateTime now) async {
    if (now.millisecondsSinceEpoch >= expiresAt || !await fence.matches(txn) ||
        await BrainWorkFence.value(txn, BackgroundRecallStore.stateKey) != raw) return false;
    final rows = await txn.query('memory_items', where: 'id = ?',
      whereArgs: [item.id], limit: 1);
    if (rows.isEmpty) return false;
    final live = MemoryItem.fromDb(rows.single);
    if (!BackgroundRecallStore.eligible(live) ||
        !MemoryRevisionSnapshot.capture(item).matches(live)) return false;
    for (final source in sources) {
      if (!await source.matches(txn)) return false;
    }
    return sources.isNotEmpty;
  }
}

/// Passive background material. No model I/O, Thought, drive pulse, evidence
/// reinforcement or message sending. All state is reconstructible references.
class BackgroundRecallStore {
  BackgroundRecallStore(this.db);
  final AppDatabase db;
  static const stateKey = 'background_recall_context_v1';
  static const diagnosticKey = 'background_recall_diagnostic_v1';
  static const enabledKey = 'ai_self_reflection_enabled';
  static const identityKeys = ['state_lineage_id', 'state_generation', 'runtime_state_epoch_v1'];
  static const controls = [enabledKey, 'self_drive_enabled',
    'conversation_context_reset_at', 'conversation_context_reset_count'];

  static Map<String, dynamic> decode(String raw) {
    try { final data = jsonDecode(raw);
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) { return {}; }
  }
  static List<Map<String, dynamic>> records(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static String day(DateTime now) => '${now.year}-${now.month}-${now.day}';
  static bool eligible(MemoryItem m) => m.isActive && m.sourceValid &&
    m.kind == 'shared_experience' && m.semanticType == 'shared_experience' &&
    m.attentionState == 'closed' && m.factState != 'cancelled' &&
    m.retentionScore >= .18 && !m.source.contains('|special_style:');

  static Future<List<QualifiedConversationSource>> originals(
      DatabaseExecutor txn, MemoryItem item) async {
    final ids = {item.sourceUserMessageId, item.sourceAssistantMessageId}..remove('');
    if (ids.isEmpty) {
      final match = RegExp(r'^conversation_turn:([^@|]+)').firstMatch(item.source);
      if (match != null) ids.add(match.group(1)!);
    }
    final result = <QualifiedConversationSource>[];
    for (final id in ids) {
      final source = await ConversationSourceStore.qualifyMessage(txn, id);
      if (source == null || !source.mayGrow) return [];
      if (item.sourceUserMessageId.isNotEmpty && item.sourceAssistantMessageId.isNotEmpty &&
          (source.userMessageId != item.sourceUserMessageId ||
           source.assistantMessageId != item.sourceAssistantMessageId)) return [];
      result.add(source);
    }
    return result;
  }

  Future<void> prepare({DateTime? now}) async {
    final instant = now ?? DateTime.now();
    if (await db.isLocalLeaseHeld('chat_turn_lease')) return;
    final handle = await db.database;
    await handle.transaction((txn) async {
      final fence = await db.captureBrainWorkFenceInTransaction(txn, settingKeys: controls);
      if (fence == null || fence.expectedSettings[enabledKey] == '0' ||
          fence.expectedSettings['self_drive_enabled'] == '0') return;
      final raw = await BrainWorkFence.value(txn, stateKey);
      var state = decode(raw);
      if (jsonEncode(state['identity']) != jsonEncode(fence.identity) ||
          state['reset'] != fence.expectedSettings['conversation_context_reset_count'] ||
          state['reset_at'] != fence.expectedSettings['conversation_context_reset_at']) state = {};
      if (state['day'] == day(instant)) return;
      final cutoff = instant.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final history = records(state['history']).where((r) =>
        (r['at'] as num? ?? 0) > instant.subtract(const Duration(days: 28)).millisecondsSinceEpoch)
        .take(64).toList();
      final cooled = history.where((r) => (r['at'] as num? ?? 0) > cutoff)
        .map((r) => r['id']).whereType<String>().toSet();
      final where = "status = 'active' AND source_valid = 1 AND kind = 'shared_experience' "
        "AND semantic_type = 'shared_experience' AND attention_state = 'closed' "
        "AND fact_state <> 'cancelled' AND retention_score >= 0.18 AND created_at <= ? "
        "AND (source_user_message_id <> '' OR source_assistant_message_id <> '' OR source LIKE 'conversation_turn:%')"
        '${cooled.isEmpty ? '' : ' AND id NOT IN (${List.filled(cooled.length, '?').join(',')})'}';
      final args = <Object?>[cutoff, ...cooled];
      final countRows = await txn.rawQuery('SELECT COUNT(*) AS n FROM memory_items WHERE $where', args);
      final count = (countRows.single['n'] as num).toInt();
      final offset = count == 0 ? 0 : ((state['offset'] as num?)?.toInt() ?? 0) % count;
      final rows = await txn.query('memory_items', where: where, whereArgs: args,
        orderBy: 'COALESCE(last_recalled_at, 0) ASC, created_at ASC, id ASC', limit: 128, offset: offset);
      final usedThemes = <String>{};
      final picked = <Map<String, Object?>>[];
      // Recently revisited themes rank behind other available themes.
      final recentThemes = history.take(4).map((r) => r['topic']).toSet();
      final items = rows.map(MemoryItem.fromDb).where(eligible).toList()
        ..sort((a, b) => (recentThemes.contains(a.topicKey) ? 1 : 0)
          .compareTo(recentThemes.contains(b.topicKey) ? 1 : 0));
      for (final item in items) {
        final topic = item.topicKey.isEmpty ? item.subjectKey : item.topicKey;
        if (topic.isNotEmpty && usedThemes.contains(topic)) continue;
        final sources = await originals(txn, item);
        if (sources.isEmpty) continue;
        picked.add({'id': item.id, 'token': MemoryRevisionSnapshot.capture(item).token,
          'sources': sources.map((s) => s.toJson()).toList(), 'topic': topic});
        usedThemes.add(topic);
        history.insert(0, {'id': item.id, 'topic': topic, 'at': instant.millisecondsSinceEpoch});
        if (picked.length == 2) break;
      }
      if (!await fence.matches(txn)) return;
      await txn.insert('settings', {'key': stateKey, 'value': jsonEncode({
        'identity': fence.identity, 'reset': fence.expectedSettings['conversation_context_reset_count'],
        'reset_at': fence.expectedSettings['conversation_context_reset_at'],
        'day': day(instant), 'expires': instant.add(const Duration(hours: 24)).millisecondsSinceEpoch,
        'offset': offset + rows.length, 'entries': picked, 'history': history.take(64).toList(),
        'receipts': records(state['receipts']).take(64).toList(),
      })}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('settings', {'key': diagnosticKey, 'value': jsonEncode({
        'stage': 'prepared', 'at': instant.millisecondsSinceEpoch,
        'prepared_count': picked.length, 'scanned_count': rows.length,
      })}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<BackgroundRecallSelection?> select({DateTime? now}) async {
    final instant = now ?? DateTime.now();
    try {
      return await (await db.database).transaction<BackgroundRecallSelection?>((txn) async {
      final fence = await db.captureBrainWorkFenceInTransaction(txn, settingKeys: controls);
      if (fence == null || fence.expectedSettings[enabledKey] == '0' ||
          fence.expectedSettings['self_drive_enabled'] == '0') return null;
      final raw = await BrainWorkFence.value(txn, stateKey);
      final state = decode(raw);
      if (jsonEncode(state['identity']) != jsonEncode(fence.identity) ||
          state['reset'] != fence.expectedSettings['conversation_context_reset_count'] ||
          state['reset_at'] != fence.expectedSettings['conversation_context_reset_at']) return null;
      final expires = (state['expires'] as num?)?.toInt() ?? 0;
      for (final entry in records(state['entries'])) {
        final rows = await txn.query('memory_items', where: 'id = ?', whereArgs: [entry['id']], limit: 1);
        if (rows.isEmpty) continue;
        final item = MemoryItem.fromDb(rows.single);
        if (MemoryRevisionSnapshot.capture(item).token != entry['token']) continue;
        final storedSources = records(entry['sources']);
        final parsedSources = storedSources.map(QualifiedConversationSource.fromJson)
          .whereType<QualifiedConversationSource>().toList();
        if (storedSources.isEmpty || parsedSources.length != storedSources.length) continue;
        final selection = BackgroundRecallSelection(raw: raw, item: item,
          sources: parsedSources, fence: fence, expiresAt: expires);
        if (!await selection.matches(txn, instant)) continue;
        await txn.insert('settings', {'key': diagnosticKey, 'value': jsonEncode({
          'stage': 'provided_to_prompt', 'at': instant.millisecondsSinceEpoch,
          'provided_count': 1, 'consumed': false,
        })}, conflictAlgorithm: ConflictAlgorithm.replace);
        return selection;
      }
      return null;
      });
    } catch (_) { return null; } // Corrupt optional context must not block chat.
  }

  /// Caller first validates selection inside the same successful reply commit.
  /// A stopped/failed attempt never reaches this write.
  static Future<void> consume(DatabaseExecutor txn, BackgroundRecallSelection selection,
      String assistantId, String assistantText, DateTime now) async {
    final state = decode(selection.raw);
    state['entries'] = records(state['entries']).where((r) => r['id'] != selection.item.id).toList();
    state['receipts'] = [
      {'assistant_id': assistantId, 'memory_id': selection.item.id,
       'token': MemoryRevisionSnapshot.capture(selection.item).token},
      ...records(state['receipts']).where((r) => r['assistant_id'] != assistantId).take(63),
    ];
    await txn.update('settings', {'value': jsonEncode(state)},
      where: 'key = ?', whereArgs: [stateKey]);
    await txn.insert('settings', {'key': diagnosticKey, 'value': jsonEncode({
      'stage': 'committed', 'at': now.millisecondsSinceEpoch, 'consumed': true,
      // A lexical signal is not proof the model adopted a particular memory.
      'textual_overlap_signal': MemoryRetrievalPolicy.hasDirectTextEvidence(
        assistantText, selection.item.content),
    })}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
