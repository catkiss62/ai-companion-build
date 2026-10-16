import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../agent/turn_execution_contract.dart';
import '../database/brain_work_fence.dart';
import '../models/public_web_candidate.dart';
import '../models/thought.dart';
import 'web_page_evidence.dart';

/// Eligibility belongs to the consumer. A share's short expiry does not make
/// previously learned, still active historical knowledge disappear.
enum PublicWebSourceProfile { share, candidateContext, historicalKnowledge, wish, reflection }

class PublicWebSourceStamp {
  const PublicWebSourceStamp({required this.id, required this.materialHash,
    required this.profile, required this.expiresAt});
  final String id, materialHash;
  final PublicWebSourceProfile profile;
  final int expiresAt;

  static List<String> strings(Object? raw) {
    try {
      final values = raw is String ? jsonDecode(raw) : raw;
      return values is List ? values.map((item) => item.toString()).toList() : const [];
    } catch (_) { return const []; }
  }

  static String hashRow(Map<String, Object?> row) => turnPayloadHash({
    for (final name in const ['id', 'title', 'summary', 'page_body', 'url',
      'source_domain', 'provider', 'read_at', 'discovered_at', 'safety_state',
      'motive_kind', 'why_cared', 'content_sha256', 'interest_key',
      'interest_score', 'action_run_id']) name: row[name],
    'key_points': strings(row['key_points_json']),
    'uncertainties': strings(row['uncertainties_json']),
  });

  /// Select the legal consumer before spending work on a read. Material
  /// validation still belongs to [eligible] after the read has completed.
  static bool preparationEligible(Map<String, Object?> row,
      PublicWebSourceProfile profile,
      DateTime now, {bool knowledgeActive = false}) {
    if ((row['id'] as String? ?? '').isEmpty) return false;
    final lifecycle = row['lifecycle_state'] as String? ?? '';
    if (const {'discarded', 'declined', 'user_deleted'}.contains(lifecycle)) return false;
    final recentReading = profile == PublicWebSourceProfile.wish ||
        profile == PublicWebSourceProfile.reflection;
    if (!recentReading && profile != PublicWebSourceProfile.historicalKnowledge &&
        ((row['expires_at'] as num?)?.toInt() ?? 0) <= now.millisecondsSinceEpoch) return false;
    if (profile == PublicWebSourceProfile.share && (lifecycle != 'share_ready' ||
        ((row['share_score'] as num?)?.toDouble() ?? 0) < .68)) return false;
    if (profile == PublicWebSourceProfile.candidateContext &&
        const {'shared', 'share_staging'}.contains(lifecycle)) return false;
    if (profile == PublicWebSourceProfile.historicalKnowledge &&
        (!knowledgeActive || lifecycle == 'share_staging')) return false;
    return true;
  }

  static bool eligible(Map<String, Object?> row, PublicWebSourceProfile profile,
      DateTime now, {bool knowledgeActive = false}) {
    if (!preparationEligible(row, profile, now, knowledgeActive: knowledgeActive) ||
        row['read_state'] != 'verified') return false;
    final semantic = row['semantic_state'];
    if (profile == PublicWebSourceProfile.share || profile == PublicWebSourceProfile.reflection) {
      if (semantic != 'valid') return false;
    } else if (semantic != 'valid' && semantic != 'history_only') { return false; }
    if (profile == PublicWebSourceProfile.wish || profile == PublicWebSourceProfile.reflection) {
      final readAt = (row['read_at'] as num?)?.toInt();
      if (readAt == null || readAt > now.millisecondsSinceEpoch ||
          readAt < now.subtract(const Duration(days: 14)).millisecondsSinceEpoch) return false;
    }
    if (const {PublicWebSourceProfile.share, PublicWebSourceProfile.candidateContext,
        PublicWebSourceProfile.historicalKnowledge}.contains(profile) &&
        WebPageEvidence.rejection(row['page_body'] as String? ?? '') != null) return false;
    return true;
  }

  /// Call on the same row/transaction used to construct the model material.
  static PublicWebSourceStamp? capture(Map<String, Object?> row, {
    required PublicWebSourceProfile profile, required DateTime now,
    bool knowledgeActive = false,
  }) => eligible(row, profile, now, knowledgeActive: knowledgeActive)
      ? PublicWebSourceStamp(id: row['id'] as String, materialHash: hashRow(row),
          profile: profile, expiresAt: (row['expires_at'] as num?)?.toInt() ?? 0)
      : null;

  Future<bool> matches(DatabaseExecutor txn, {DateTime? now}) async {
    final rows = await txn.query('public_web_candidates', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return false;
    var knowledgeActive = false;
    if (profile == PublicWebSourceProfile.historicalKnowledge) {
      knowledgeActive = (await txn.query('public_web_knowledge', columns: ['candidate_id'],
        where: "candidate_id = ? AND lifecycle_state = 'active'", whereArgs: [id], limit: 1)).isNotEmpty;
    }
    final row = rows.single;
    return eligible(row, profile, now ?? DateTime.now(), knowledgeActive: knowledgeActive) &&
        (const {PublicWebSourceProfile.historicalKnowledge, PublicWebSourceProfile.wish,
          PublicWebSourceProfile.reflection}.contains(profile) ||
          ((row['expires_at'] as num?)?.toInt() ?? 0) == expiresAt) && hashRow(row) == materialHash;
  }

  static PublicWebContextItem contextItem(Map<String, Object?> row) => PublicWebContextItem(
    id: row['id'] as String, title: row['title'] as String? ?? '',
    summary: row['summary'] as String? ?? '', pageBody: row['page_body'] as String? ?? '',
    url: row['url'] as String? ?? '', sourceDomain: row['source_domain'] as String? ?? '',
    provider: row['provider'] as String? ?? '', safetyState: row['safety_state'] as String? ?? 'untrusted_public',
    discoveredAt: DateTime.fromMillisecondsSinceEpoch((row['discovered_at'] as num?)?.toInt() ?? 0),
    motiveKind: row['motive_kind'] as String? ?? '', whyCared: row['why_cared'] as String? ?? '',
    keyPoints: strings(row['key_points_json']), uncertainties: strings(row['uncertainties_json']),
    readAt: row['read_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch((row['read_at'] as num).toInt()),
  );
}

class ExpectedPublicWebShare {
  const ExpectedPublicWebShare({required this.source, required this.thoughtId});
  final PublicWebSourceStamp source;
  final String thoughtId;
  String get candidateId => source.id;
  Future<bool> matches(DatabaseExecutor txn, {DateTime? now}) async {
    if (source.profile != PublicWebSourceProfile.share || !await source.matches(txn, now: now)) return false;
    final rows = await txn.query('thoughts',
      where: 'id = ? AND source = ? AND topic_key = ?', whereArgs: [thoughtId,
        'public_web_candidate:${candidateId.toLowerCase()}',
        'public_web_candidate:${candidateId.toLowerCase()}'], limit: 1);
    return rows.isNotEmpty && CompanionThought.fromDb(rows.single).canDriveIntentAt(now ?? DateTime.now());
  }
}

class PublicWebPromptBundle {
  const PublicWebPromptBundle({this.items = const [], this.knowledgeItems = const [],
    this.sourceStamps = const [], this.expectedShare});
  final List<PublicWebContextItem> items, knowledgeItems;
  final List<PublicWebSourceStamp> sourceStamps;
  final ExpectedPublicWebShare? expectedShare;
}

/// This capability is never reconstructed from a candidate's current token.
/// A returned worker must retain its original token AND original brain fence.
class PublicWebShareStageLease {
  const PublicWebShareStageLease({required this.candidate, required this.stageToken,
    required this.stageUntil, required this.workFence, required this.originalMaterialHash});
  final PublicWebShareCandidate candidate;
  final String stageToken, originalMaterialHash;
  final DateTime stageUntil;
  final BrainWorkFence workFence;
  String get id => candidate.id;
  String get driveKey => candidate.driveKey;
  Future<bool> matches(DatabaseExecutor txn, {DateTime? now, bool allowExpired = false,
      bool checkOriginalMaterial = false}) async {
    final instant = now ?? DateTime.now();
    if (!await workFence.matches(txn) || stageToken.isEmpty ||
        (!allowExpired && !stageUntil.isAfter(instant))) return false;
    final rows = await txn.query('public_web_candidates', where:
      "id = ? AND lifecycle_state = 'share_staging' AND share_stage_token = ? AND share_stage_until = ?",
      whereArgs: [id, stageToken, stageUntil.millisecondsSinceEpoch], limit: 1);
    if (rows.isEmpty) return false;
    final row = rows.single;
    if (!allowExpired && ((row['expires_at'] as num?)?.toInt() ?? 0) <= instant.millisecondsSinceEpoch) return false;
    return !checkOriginalMaterial || PublicWebSourceStamp.hashRow(row) == originalMaterialHash;
  }
}
