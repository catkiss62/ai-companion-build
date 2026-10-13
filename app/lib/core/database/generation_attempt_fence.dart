import 'package:sqflite/sqflite.dart';

import 'brain_work_fence.dart';
import 'conversation_source_store.dart';

/// The original attempt, captured before asynchronous work, never a freshly
/// read replacement token. Check in the transaction that creates the effect.
class GenerationAttemptFence {
  const GenerationAttemptFence({required this.jobId, required this.runToken,
    required this.userMessageId, required this.assistantMessageId,
    required this.brainFence, this.userSource});

  final String jobId, runToken, userMessageId, assistantMessageId;
  final BrainWorkFence brainFence;
  final ConversationSourceStamp? userSource;

  Future<bool> matches(DatabaseExecutor txn) async {
    if (runToken.isEmpty || !await brainFence.matches(txn)) return false;
    return matchesJobIdentity(txn);
  }

  /// Identity only. Temporary brain freezes prevent writes, but do not prove
  /// that this attempt has ended and that its prepared files can be deleted.
  Future<bool> matchesJobIdentity(DatabaseExecutor txn) async {
    if (runToken.isEmpty) return false;
    final rows = await txn.rawQuery('''
      SELECT 1 FROM generation_jobs g JOIN messages u ON u.id = g.user_message_id
      WHERE g.id = ? AND g.status = 'running' AND g.run_token = ?
        AND g.user_message_id = ? AND g.assistant_message_id = ? AND u.role = 'user'
      LIMIT 1
    ''', [jobId, runToken, userMessageId, assistantMessageId]);
    if (rows.isEmpty) return false;
    final source = userSource;
    return source == null || (source.id == userMessageId &&
        source.role == 'user' && await source.matches(txn));
  }
}
