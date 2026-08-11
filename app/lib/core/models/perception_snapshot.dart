import 'dart:convert';

class PerceptionSnapshot {
  const PerceptionSnapshot({
    required this.id,
    required this.summary,
    required this.occurredAt,
    this.deviceId,
    this.deviceLabel,
    this.currentPackage,
    this.busyScore = 0,
    this.notificationCount = 0,
    this.metadata = const {},
  });

  final String id;
  final String summary;
  final DateTime occurredAt;
  final String? deviceId;
  final String? deviceLabel;
  final String? currentPackage;
  final double busyScore;
  final int notificationCount;
  final Map<String, Object?> metadata;

  factory PerceptionSnapshot.fromDb(Map<String, Object?> row) {
    Map<String, Object?> metadata = const {};
    final raw = row['metadata_json'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) metadata = Map<String, Object?>.from(decoded);
    }
    return PerceptionSnapshot(
      id: row['id'] as String,
      summary: row['summary'] as String? ?? '',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
      deviceId: row['device_id'] as String?,
      deviceLabel: row['device_label'] as String?,
      currentPackage: row['current_package'] as String?,
      busyScore: (row['busy_score'] as num?)?.toDouble() ?? 0,
      notificationCount: (row['notification_count'] as num?)?.toInt() ?? 0,
      metadata: metadata,
    );
  }
}
