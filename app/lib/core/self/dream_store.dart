import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../models/world_book_turn_context.dart';
import 'dream_contract.dart';

class DreamStore {
  DreamStore(this.db);
  final AppDatabase db;
  // Reuse the existing user switch; an update must not turn it back on.
  static const enabledKey = 'ai_self_reflection_enabled';
  static const stateKey = 'nightly_dream_state_v1';
  static const attemptKey = 'nightly_dream_attempt_v1';
  static const diagnosticKey = 'nightly_dream_diagnostic_v1';
  static const leaseKey = 'nightly_dream_lease_until';
  static const busyLeases = ['chat_turn_lease', 'cedar_toy_action_lease_until',
    'post_turn_memory_lease', 'conversation_summary_lease_until'];

  Future<Map<String, dynamic>> load() async => DreamContract.decode(await db.getSetting(stateKey));

  static String clip(String value, [int max = 1800]) =>
      value.length <= max ? value : value.substring(0, max);

  static DreamSource? chatSource(Map<String, Object?> row, {bool fresh = false}) {
    final role = row['role'];
    final provenance = WorldBookTurnContext.decode(row['worldbook_context_json'] as String? ?? '');
    final text = clip(row['content'] as String? ?? '');
    if ((role != 'user' && role != 'assistant') || text.trim().isEmpty || provenance.hasRoleplay) return null;
    return DreamSource(id: 'chat:${row['id']}', kind: role == 'user' ? 'user_text' : 'assistant_text',
      text: text, at: DreamContract.number(row['created_at']), fresh: fresh,
      conditioned: provenance.behaviorSources.isNotEmpty || provenance.knowledgeSources.isNotEmpty);
  }

  static DreamSource? webSource(Map<String, Object?> row, {bool fresh = false}) {
    if (row['read_state'] != 'verified' || row['semantic_state'] != 'valid' ||
        {'discarded', 'declined', 'user_deleted'}.contains(row['lifecycle_state'])) return null;
    return DreamSource(id: 'web:${row['id']}', kind: 'read_material',
      text: clip('${row['title']}\n${row['summary']}'),
      at: DreamContract.number(row['read_at']), fresh: fresh);
  }

  /// User rows can lack provenance even when their committed answer is a
  /// roleplay turn. Check the paired reply beyond the current batch boundary.
  static Future<Set<String>> roleplayUsers(DatabaseExecutor handle, Iterable<Map<String, Object?>> rows) async {
    final ids = rows.where((r) => r['role'] == 'user').map((r) => r['id']).toList();
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final paired = await handle.rawQuery('''SELECT m.id,
      (SELECT n.worldbook_context_json FROM messages n
       WHERE (n.created_at > m.created_at OR (n.created_at = m.created_at AND n.id > m.id))
       AND n.role IN ('user','assistant') AND n.is_proactive = 0
       ORDER BY n.created_at, n.id LIMIT 1) AS next_context
      FROM messages m WHERE m.id IN ($placeholders)''', ids);
    final excluded = paired.where((r) => WorldBookTurnContext.decode(
      r['next_context'] as String? ?? '').hasRoleplay).map((r) => r['id'] as String).toSet();
    final jobs = await handle.rawQuery('''SELECT j.user_message_id, a.worldbook_context_json
      FROM generation_jobs j JOIN messages a ON a.id = j.assistant_message_id
      WHERE j.user_message_id IN ($placeholders)''', ids);
    for (final r in jobs) {
      if (WorldBookTurnContext.decode(r['worldbook_context_json'] as String? ?? '').hasRoleplay) {
        excluded.add(r['user_message_id'] as String);
      }
    }
    return excluded;
  }

  /// Re-read originals, not the copied quote in a dream. Deletion, reply
  /// regeneration, or changed provenance makes that evidence unavailable.
  static Future<Map<String, DreamSource>> originals(DatabaseExecutor handle, Iterable<String> ids) async {
    final result = <String, DreamSource>{};
    for (final prefix in ['chat', 'web']) {
      final selected = ids.where((id) => id.startsWith('$prefix:'))
          .map((id) => id.substring(prefix.length + 1)).toSet().take(600).toList();
      if (selected.isEmpty) continue;
      final rows = await handle.query(prefix == 'chat' ? 'messages' : 'public_web_candidates',
        where: 'id IN (${List.filled(selected.length, '?').join(',')})', whereArgs: selected);
      final excluded = prefix == 'chat' ? await roleplayUsers(handle, rows) : <String>{};
      for (final row in rows) {
        if (excluded.contains(row['id'])) continue;
        final source = prefix == 'chat' ? chatSource(row) : webSource(row);
        if (source != null) result[source.id] = source;
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> usableInsights([Map<String, dynamic>? state]) async {
    final insights = DreamContract.records((state ?? await load())['insights']);
    final refs = insights.expand((i) => DreamContract.records(i['evidence'])).toList();
    final live = await originals(await db.database, refs.map((r) => DreamContract.string(r['id'])));
    return insights.where((i) {
      final evidence = DreamContract.records(i['evidence']);
      return evidence.isNotEmpty && evidence.every((r) =>
        live[r['id']]?.fingerprint == r['fingerprint']);
    }).toList();
  }

  Future<String> prompt({bool game = false, bool freshSourceOnly = false, bool roleplay = false}) async {
    // Keep the already-established fresh-source and fictional-scene boundary.
    if (freshSourceOnly || roleplay || await db.getSetting(enabledKey) == '0') return '';
    try { return DreamContract.prompt(await usableInsights(), game: game); }
    catch (_) { return ''; }
  }

  static Future<bool> idle(DatabaseExecutor handle, DateTime now, {bool manual = false}) async {
    if (!await BrainWorkFence.workAllowed(handle)) return false;
    for (final key in busyLeases) {
      final raw = await BrainWorkFence.value(handle, key);
      final expires = int.tryParse(raw.split('|').last) ?? 0;
      if (expires > DateTime.now().millisecondsSinceEpoch) return false;
    }
    if ((await handle.query('interaction_sessions', columns: ['id'],
        where: "status = 'active'", limit: 1)).isNotEmpty) return false;
    if ((await handle.query('generation_jobs', columns: ['id'],
        where: "status IN ('pending','running','retry_wait','awaiting_confirmation')", limit: 1)).isNotEmpty) return false;
    if (!manual) {
      final latest = await handle.query('messages', columns: ['created_at'],
        orderBy: 'created_at DESC', limit: 1);
      if (latest.isNotEmpty && now.millisecondsSinceEpoch -
          DreamContract.number(latest.first['created_at']) < const Duration(minutes: 5).inMilliseconds) return false;
    }
    return true;
  }

  static Future<String> messageStamp(DatabaseExecutor handle) async {
    final count = Sqflite.firstIntValue(await handle.rawQuery('SELECT COUNT(*) FROM messages')) ?? 0;
    final rows = await handle.query('messages', columns: ['id', 'content', 'created_at', 'worldbook_context_json'],
      orderBy: 'created_at DESC, id DESC', limit: 1);
    return sha256.convert(utf8.encode(jsonEncode([count, rows]))).toString();
  }

  Future<bool> commit({required Map<String, dynamic> next,
    required String expectedRaw, required String stamp, required List<DreamSource> sources,
    required BrainWorkFence fence, required Map<String, Object?> diagnostic,
    required DateTime now, bool manual = false}) async {
    final handle = await db.database;
    return handle.transaction((txn) async {
      if (!await fence.matches(txn) || !await idle(txn, now, manual: manual) ||
          await BrainWorkFence.value(txn, stateKey) != expectedRaw ||
          await messageStamp(txn) != stamp) return false;
      final live = await originals(txn, sources.map((s) => s.id));
      if (sources.any((s) => live[s.id]?.fingerprint != s.fingerprint)) return false;
      for (final entry in {stateKey: jsonEncode(next), diagnosticKey: jsonEncode(diagnostic),
          attemptKey: '', 'last_self_reflection_at': '${now.millisecondsSinceEpoch}',
          'last_self_reflection_error': ''}.entries) {
        await txn.insert('settings', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return true;
    });
  }

  Future<Map<String, Object?>> diagnostics() async {
    final state = await load();
    final valid = await usableInsights(state);
    final last = DreamContract.decode(await db.getSetting(diagnosticKey));
    return {'enabled': await db.getSetting(enabledKey) != '0',
      'last_completed_at': DreamContract.number(state['last_completed_at']),
      'last_weekly_at': DreamContract.number(state['last_weekly_at']),
      'insight_count': DreamContract.records(state['insights']).length,
      'usable_insight_count': valid.length, 'history_count': DreamContract.records(state['history']).length,
      'last_status': DreamContract.string(last['status']),
      'last_source_count': DreamContract.number(last['source_count']),
      'last_changed_count': DreamContract.number(last['changed_count']),
      'has_backlog': last['has_backlog'] == true,
      'meaning': '整理/提交状态，不证明实际行为已改变'};
  }
}
