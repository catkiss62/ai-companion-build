import 'dart:convert';

/// A bounded, human-level interpretation of raw Android perception data.
///
/// Raw package names, notification text and Accessibility text stay in the
/// short-lived device-event layer. Ordinary model prompts consume only these
/// compact observations, each of which carries uncertainty and an expiry.
class AwarenessObservation {
  const AwarenessObservation({
    required this.id,
    required this.kind,
    required this.summary,
    required this.confidence,
    required this.windowStart,
    required this.windowEnd,
    required this.expiresAt,
    required this.dedupeKey,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
    this.sourceFingerprint = '',
    this.metadata = const {},
  });

  final String id;
  final String kind;
  final String summary;
  final double confidence;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime expiresAt;
  final String dedupeKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deviceId;
  final String sourceFingerprint;
  final Map<String, Object?> metadata;

  bool isActiveAt(DateTime now) => expiresAt.isAfter(now);

  factory AwarenessObservation.fromDb(Map<String, Object?> row) {
    Map<String, Object?> metadata = const {};
    final raw = row['metadata_json'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) metadata = Map<String, Object?>.from(decoded);
    }
    return AwarenessObservation(
      id: row['id'] as String,
      kind: row['kind'] as String? ?? '',
      summary: row['summary'] as String? ?? '',
      confidence: ((row['confidence'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble(),
      windowStart: DateTime.fromMillisecondsSinceEpoch(row['window_start'] as int),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(row['window_end'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      dedupeKey: row['dedupe_key'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      deviceId: row['device_id'] as String?,
      sourceFingerprint: row['source_fingerprint'] as String? ?? '',
      metadata: metadata,
    );
  }
}

class AwarenessObservationDraft {
  const AwarenessObservationDraft({
    required this.kind,
    required this.summary,
    required this.confidence,
    required this.windowStart,
    required this.windowEnd,
    required this.expiresAt,
    required this.dedupeKey,
    this.sourceFingerprint = '',
    this.metadata = const {},
  });

  final String kind;
  final String summary;
  final double confidence;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime expiresAt;
  final String dedupeKey;
  final String sourceFingerprint;
  final Map<String, Object?> metadata;
}
