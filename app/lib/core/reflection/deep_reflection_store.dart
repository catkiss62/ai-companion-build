import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import 'deep_reflection_contract.dart';

class DeepReflectionStore {
  DeepReflectionStore(this.db);
  final AppDatabase db;
  static const stateKey = 'deep_reflection_state_v1';
  static const enabledKey = 'ai_self_reflection_enabled';
  static const resetKey = 'conversation_context_reset_at';
  static const undoKey = 'deep_reflection_reply_undo_v1';
  static const contactKey = 'deep_reflection_contact_attempt_v1';
  static const diagnosticKey = 'deep_reflection_last_execution_v1';
  static const invitationGap = Duration(days: 3);

  static Map<String, dynamic> decode(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  Future<DeepReflectionContext?> context({
    DateTime? now,
    bool invite = false,
  }) async {
    try {
      return await _context(now: now, invite: invite);
    } catch (_) {
      return null;
    } // Corrupt optional state must not block chat.
  }

  Future<DeepReflectionContext?> _context({
    DateTime? now,
    bool invite = false,
  }) async {
    if (await db.getSetting(enabledKey) == '0') return null;
    final raw = await db.getSetting(stateKey) ?? '';
    final state = decode(raw);
    final topic = state['topic'];
    final reset = await db.getSetting(resetKey) ?? '';
    if (topic is! Map<String, dynamic> ||
        topic['reset'] != reset ||
        topic['id'] is! String ||
        topic['question'] is! String)
      return null;
    final at = now ?? DateTime.now();
    final age =
        at.millisecondsSinceEpoch -
        ((topic['updated_at'] as num?)?.toInt() ?? 0);
    if (invite) {
      final last = int.tryParse(await db.getSetting(contactKey) ?? '') ?? 0;
      if (topic['phase'] != 'ready' ||
          age > const Duration(days: 7).inMilliseconds ||
          at.millisecondsSinceEpoch - last < invitationGap.inMilliseconds)
        return null;
    } else if (topic['phase'] == 'ready' ||
        age > const Duration(days: 30).inMilliseconds) {
      return null;
    }
    // After a quiet week this is a dormant reference, never a pending demand.
    final view = Map<String, dynamic>.from(topic);
    if (!invite &&
        age > const Duration(days: 7).inMilliseconds &&
        {'offered', 'discussing'}.contains(view['phase']))
      view['phase'] = 'paused';
    return DeepReflectionContext(raw: raw, reset: reset, topic: view);
  }

  Future<DeepReflectionContext?> claimInvitation(
    String id,
    DateTime now,
  ) async {
    final context = await this.context(now: now, invite: true);
    if (context == null || context.topic['id'] != id) return null;
    final fence = await db.captureBrainWorkFence(
      settingKeys: [enabledKey, resetKey],
    );
    if (fence == null ||
        fence.expectedSettings[enabledKey] == '0' ||
        fence.expectedSettings[resetKey] != context.reset)
      return null;
    final last = await db.getSetting(contactKey) ?? '';
    if (now.millisecondsSinceEpoch - (int.tryParse(last) ?? 0) <
        invitationGap.inMilliseconds)
      return null;
    final saved = await db.setSettingsAtomically(
      {contactKey: '${now.millisecondsSinceEpoch}'},
      expectedSettings: {stateKey: context.raw, contactKey: last},
      workFence: fence,
    );
    return saved ? context : null;
  }

  static Future<void> write(DatabaseExecutor tx, String key, String value) => tx
      .insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  static Future<bool> current(
    DatabaseExecutor tx,
    DeepReflectionContext c,
  ) async =>
      await BrainWorkFence.value(tx, enabledKey) != '0' &&
      await BrainWorkFence.value(tx, resetKey) == c.reset &&
      await BrainWorkFence.value(tx, stateKey) == c.raw;

  /// Called only inside the winning message transaction. Missing/bad metadata
  /// cannot block chat or invent a resolution. No side effects before commit.
  static Future<void> commit(
    DatabaseExecutor tx, {
    required DeepReflectionContext? context,
    DeepReflectionUpdate? update,
    required String replyId,
    required String visibleReply,
    required DateTime now,
    String userId = '',
    String userText = '',
    bool invitation = false,
    bool roleplay = false,
  }) async {
    if (context == null ||
        roleplay ||
        visibleReply.trim().isEmpty ||
        !await current(tx, context))
      return;
    final state = decode(context.raw);
    final topic = Map<String, dynamic>.from(state['topic'] as Map);
    if (invitation) {
      if (topic['phase'] != 'ready') return;
      topic['phase'] = 'offered';
      topic['invited_at'] = now.millisecondsSinceEpoch;
    } else {
      final u = update?.data;
      if (u == null || u['id'] != topic['id'] || topic['phase'] == 'ready')
        return;
      if (u['action'] == 'pause' || u['related'] == false) {
        if ({'paused', 'settled'}.contains(topic['phase'])) return;
        topic['phase'] = 'paused';
      } else {
        final userQuote = (u['user_quote'] as String).trim();
        final replyQuote = (u['reply_quote'] as String).trim();
        if (u['related'] != true ||
            userQuote.isEmpty ||
            !userText.contains(userQuote) ||
            replyQuote.length < 4 ||
            !visibleReply.contains(replyQuote) ||
            (u['view'] as String).trim().isEmpty ||
            (u['progress'] as String).trim().isEmpty)
          return;
        if ({'paused', 'settled'}.contains(context.topic['phase']) &&
            u['resume'] != true)
          return;
        if (u['action'] == 'discuss' &&
            (u['remaining'] as String).trim().isEmpty)
          return;
        topic.addAll({
          'phase': u['action'] == 'settle' ? 'settled' : 'discussing',
          'view': u['view'],
          'remaining': u['remaining'],
          'progress': u['progress'],
        });
      }
    }
    topic['updated_at'] = now.millisecondsSinceEpoch;
    topic['last_reply_id'] = replyId;
    topic['revision'] = ((topic['revision'] as num?)?.toInt() ?? 0) + 1;
    state['topic'] = topic;
    final after = jsonEncode(state);
    await write(tx, stateKey, after);
    await write(
      tx,
      undoKey,
      jsonEncode({
        'reply_id': replyId,
        'user_id': userId,
        'before': context.raw,
        'after': after,
      }),
    );
    await write(
      tx,
      diagnosticKey,
      jsonEncode(
        diagnostic(
          executionId: replyId,
          source: invitation ? 'proactive' : 'user_turn',
          phase: topic['phase'] as String,
          committed: 1,
        ),
      ),
    );
  }

  static Future<void> undo(
    DatabaseExecutor tx, {
    String replyId = '',
    String userId = '',
  }) async {
    final undo = decode(await BrainWorkFence.value(tx, undoKey));
    if (undo.isEmpty ||
        !((replyId.isNotEmpty && undo['reply_id'] == replyId) ||
            (userId.isNotEmpty && undo['user_id'] == userId)))
      return;
    final beforeTopic = decode(undo['before'] as String? ?? '')['topic'];
    final afterTopic = decode(undo['after'] as String? ?? '')['topic'];
    final raw = await BrainWorkFence.value(tx, stateKey);
    // Never erase a later, independent mutation or restore an old reset epoch.
    if (beforeTopic is! Map ||
        afterTopic is! Map ||
        beforeTopic['reset'] != await BrainWorkFence.value(tx, resetKey))
      return;
    if (raw == undo['after']) {
      await write(tx, stateKey, undo['before'] as String);
      await write(
        tx,
        diagnosticKey,
        jsonEncode(
          diagnostic(
            executionId: replyId,
            source: 'regenerate',
            phase: 'rolled_back',
            committed: 1,
          ),
        ),
      );
    } else {
      // A new background preparation may have archived this topic since the
      // last visible reply. Retracting that reply must also retract its archived
      // conclusion, while preserving the new question and its own revision.
      final state = decode(raw);
      final history = (state['history'] as List? ?? []).toList();
      final index = history.indexWhere(
        (t) =>
            t is Map &&
            t['id'] == afterTopic['id'] &&
            t['revision'] == afterTopic['revision'] &&
            t['last_reply_id'] == undo['reply_id'],
      );
      if (index >= 0) {
        history[index] = {...beforeTopic, 'phase': 'paused'};
        state['history'] = history;
        await write(tx, stateKey, jsonEncode(state));
      }
    }
    await write(tx, undoKey, '');
  }

  static Map<String, Object?> diagnostic({
    required String executionId,
    required String source,
    required String phase,
    int committed = 0,
    bool late = false,
  }) => {
    'feature': 'deep_reflection',
    'execution_id': executionId,
    'trigger_source': source,
    'continuation_owner': 'existing_heartbeat_or_final_writer',
    'phase': phase,
    'planning_rounds': 0,
    'tool_calls': 0,
    'committed_mutations': committed,
    'continuation_requested': false,
    'terminal': phase != 'preparing',
    'preempt': false,
    'late_write': late,
    'usage_lane': source == 'heartbeat'
        ? 'deep_reflection'
        : 'existing_final_reply',
  };
}
