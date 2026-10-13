import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../agent/turn_execution_contract.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';

/// A bounded-frequency retry belongs to a result, not to a heartbeat. No body
/// or result text is stored here, and this record is never delivery evidence.
class CedarDeliveryAttemptStore {
  CedarDeliveryAttemptStore(this.db, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  static String signature(List<CedarDeliveryClaim> claims) => turnPayloadHash(
      claims.map((claim) => claim.resultHash).toList()..sort());
  static String key(List<CedarDeliveryClaim> claims) =>
      'cedar_delivery_attempt_v1:${signature(claims)}';
  static String successorId(String thoughtId, List<CedarDeliveryClaim> claims) =>
      'cedar-share:$thoughtId:delivery:${signature(claims)}';

  Future<CedarDeliveryAttempt?> read(List<CedarDeliveryClaim> claims) async {
    if (claims.isEmpty || claims.any((claim) => !claim.valid)) return null;
    try {
      final value = jsonDecode(await db.getSetting(key(claims)) ?? 'null');
      if (value is! Map || value['schema'] != 1) return null;
      return CedarDeliveryAttempt(
        sourceId: value['source_id'] as String? ?? '',
        sourceHash: value['source_hash'] as String? ?? '',
        sourceRevision: value['source_revision'] as int? ?? 0,
        declined: value['declined'] == true,
        rejectedSources: (value['rejected_sources'] as List? ?? const []).whereType<Map>().toList(),
        failures: value['failures'] as int,
        retryAt: DateTime.fromMillisecondsSinceEpoch(value['retry_at'] as int),
      );
    } catch (_) { return null; }
  }

  Future<bool> recordFailure({
    required List<CedarDeliveryClaim> claims,
    required bool declined,
    required BrainWorkFence fence,
    ConversationSourceStamp? source,
  }) async {
    if (claims.isEmpty || claims.any((claim) => !claim.valid)) return false;
    final sql = await db.database;
    return sql.transaction((txn) async {
      if (!await fence.matches(txn) ||
          (source != null && !await source.matches(txn))) return false;
      final setting = key(claims);
      var failures = 0;
      var rejected = <Map>[];
      try {
        final previous = jsonDecode(await BrainWorkFence.value(txn, setting));
        if (previous is Map) {
          failures = previous['failures'] as int? ?? 0;
          rejected = (previous['rejected_sources'] as List? ?? const []).whereType<Map>().toList();
        }
      } catch (_) {}
      if (declined && source != null) {
        rejected.removeWhere((item) => item['id'] == source.id);
        rejected.add({'id': source.id, 'hash': source.contentHash, 'revision': source.revision});
      }
      failures = (failures + 1).clamp(1, 3).toInt();
      final minutes = const [1, 5, 30][failures - 1];
      await txn.insert('settings', {'key': setting, 'value': jsonEncode({
        'schema': 1, 'source_id': source?.id ?? '',
        'source_hash': source?.contentHash ?? '',
        'source_revision': source?.revision ?? 0,
        'declined': declined, 'failures': failures,
        'rejected_sources': rejected.take(2).toList(),
        'retry_at': clock().add(Duration(minutes: minutes)).millisecondsSinceEpoch,
      })}, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }
}

class CedarDeliveryAttempt {
  const CedarDeliveryAttempt({required this.sourceId, required this.sourceHash,
    required this.sourceRevision, required this.declined, required this.failures,
    this.rejectedSources = const [],
    required this.retryAt});
  final String sourceId, sourceHash;
  final int sourceRevision, failures;
  final bool declined;
  final List<Map> rejectedSources;
  final DateTime retryAt;
  bool matches(ConversationSourceStamp source) => sourceId == source.id &&
      sourceHash == source.contentHash && sourceRevision == source.revision;
  bool declinedFor(ConversationSourceStamp source) => rejectedSources.any((item) =>
      item['id'] == source.id && item['hash'] == source.contentHash &&
      item['revision'] == source.revision);
  bool deferred(DateTime now) => now.isBefore(retryAt);
}
