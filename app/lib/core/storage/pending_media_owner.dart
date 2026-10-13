import 'package:sqflite/sqflite.dart';

import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../database/generation_attempt_fence.dart';

/// Temporary file ownership, not a sent attachment or a replayable media task.
/// Only the current generation attempt or the captured proactive lease owns it.
class PendingMediaOwner {
  PendingMediaOwner.generation(GenerationAttemptFence attempt)
      : attempt = attempt, leaseFence = null, messageId = attempt.assistantMessageId;
  const PendingMediaOwner.proactive({required this.messageId, required BrainWorkFence fence})
      : leaseFence = fence, attempt = null;

  final GenerationAttemptFence? attempt;
  final BrainWorkFence? leaseFence;
  final String messageId;
  BrainWorkFence get fence => attempt?.brainFence ?? leaseFence!;
  String get key => attempt == null
      ? 'proactive:$messageId:${fence.leaseToken}'
      : 'generation:${attempt!.jobId}:${attempt!.runToken}';

  Future<bool> matches(DatabaseExecutor txn) async {
    if (messageId.isEmpty) return false;
    if (attempt != null) return attempt!.matches(txn);
    if (fence.leaseKey != 'proactive_lease_until' || fence.leaseToken?.isNotEmpty != true) return false;
    return fence.matches(txn);
  }

  /// GC needs evidence that ownership ended, not merely that writes are
  /// temporarily blocked. Keep a pin during a transfer freeze, and keep an
  /// expired or unrecognizable lease until it is ended or visibly replaced.
  Future<bool> retainsOwnership(DatabaseExecutor txn) async {
    if (messageId.isEmpty) return false;
    for (final entry in {...fence.identity, ...fence.expectedSettings}.entries) {
      final rows = await txn.rawQuery(
        "SELECT COALESCE((SELECT COALESCE(value, '') = ? FROM settings "
        'WHERE key = ? LIMIT 1), ?) AS matches',
        [entry.value, entry.key, entry.value.isEmpty ? 1 : 0],
      );
      if (rows.first['matches'] != 1) return false;
    }
    if (attempt != null && !await attempt!.matchesJobIdentity(txn)) return false;
    if (fence.leaseKey != null) {
      final token = fence.leaseToken;
      if (token == null || token.isEmpty) return false;
      final raw = await BrainWorkFence.value(txn, fence.leaseKey!);
      if (raw.isEmpty || raw == '0') return false;
      if (raw.startsWith('$token|')) return true;
      // Only the recognized persisted token format proves a replacement.
      return !RegExp(r'^.+:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\|[0-9]+$').hasMatch(raw);
    }
    return attempt != null;
  }

  Map<String, Object?> toJson() => {
    'schema': 2,
    'message_id': messageId,
    'identity': fence.identity,
    'expected_settings': fence.expectedSettings,
    'lease_key': fence.leaseKey,
    'lease_token': fence.leaseToken,
    if (attempt != null) ...{'job_id': attempt!.jobId, 'run_token': attempt!.runToken,
      'user_message_id': attempt!.userMessageId,
      'user_source': attempt!.userSource?.toJson()},
  };

  static PendingMediaOwner? decode(Map<String, dynamic> value) {
    try {
      // Pending owners are local and disposable. Future attempt fields can
      // bump this version instead of silently weakening an older fence.
      if (value['schema'] != 2) return null;
      final identity = Map<String, String>.from(value['identity'] as Map);
      final expectedSettings = Map<String, String>.from(value['expected_settings'] as Map);
      if (!identity.keys.toSet().containsAll(
          ['state_lineage_id', 'state_generation', 'runtime_state_epoch_v1'])) return null;
      final fence = BrainWorkFence(identity: identity,
        leaseKey: value['lease_key'] as String?, leaseToken: value['lease_token'] as String?,
        expectedSettings: expectedSettings);
      final message = value['message_id'] as String;
      if (message.isEmpty) return null;
      if (value['job_id'] is String) {
        final source = ConversationSourceStamp.fromJson(value['user_source']);
        if (source == null || source.id != value['user_message_id'] ||
            source.role != 'user') return null;
        return PendingMediaOwner.generation(GenerationAttemptFence(
          jobId: value['job_id'] as String, runToken: value['run_token'] as String,
          userMessageId: value['user_message_id'] as String,
          assistantMessageId: message, brainFence: fence, userSource: source));
      }
      if (value['job_id'] != null || fence.leaseKey != 'proactive_lease_until' ||
          fence.leaseToken?.isNotEmpty != true) return null;
      return PendingMediaOwner.proactive(messageId: message, fence: fence);
    } catch (_) { return null; }
  }
}
