class CompanionAlbumItem {
  const CompanionAlbumItem({
    required this.id,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceUrl,
    required this.sourceDomain,
    required this.title,
    required this.summary,
    required this.reason,
    required this.category,
    required this.nsfw,
    required this.thumbnailPath,
    required this.contentSha256,
    required this.visualFingerprint,
    required this.visionModel,
    required this.width,
    required this.height,
    required this.lifecycle,
    required this.feedback,
    required this.comment,
    required this.createdAt,
    required this.savedAt,
    required this.deleteAfter,
    required this.unread,
  });

  static const String candidate = 'candidate';
  static const String recognized = 'recognized';
  static const String saved = 'saved';
  static const String rejected = 'rejected';
  static const String expired = 'expired';
  static const String softDeleted = 'soft_deleted';
  static const String deleted = 'deleted';

  final String id;
  final String sourceKind;
  final String sourceId;
  final String sourceUrl;
  final String sourceDomain;
  final String title;
  final String summary;
  final String reason;
  final String category;
  final bool nsfw;
  final String thumbnailPath;
  final String contentSha256;
  final String visualFingerprint;
  final String visionModel;
  final int width;
  final int height;
  final String lifecycle;
  final String feedback;
  final String comment;
  final DateTime createdAt;
  final DateTime? savedAt;
  final DateTime? deleteAfter;
  final bool unread;

  bool get isVisible => lifecycle == saved || lifecycle == softDeleted;
  bool get isPendingDelete => lifecycle == softDeleted;

  factory CompanionAlbumItem.fromDb(Map<String, Object?> row) {
    DateTime? date(String key) {
      final value = (row[key] as num?)?.toInt();
      return value == null || value <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(value);
    }

    return CompanionAlbumItem(
      id: row['id'] as String? ?? '',
      sourceKind: row['source_kind'] as String? ?? '',
      sourceId: row['source_id'] as String? ?? '',
      sourceUrl: row['source_url'] as String? ?? '',
      sourceDomain: row['source_domain'] as String? ?? '',
      title: row['title'] as String? ?? '',
      summary: row['vision_summary'] as String? ?? '',
      reason: row['ai_reason'] as String? ?? '',
      category: row['category'] as String? ?? 'other',
      nsfw: row['nsfw'] == 1,
      thumbnailPath: row['thumbnail_path'] as String? ?? '',
      contentSha256: row['content_sha256'] as String? ?? '',
      visualFingerprint: row['visual_fingerprint'] as String? ?? '',
      visionModel: row['vision_model'] as String? ?? '',
      width: (row['width'] as num?)?.toInt() ?? 0,
      height: (row['height'] as num?)?.toInt() ?? 0,
      lifecycle: row['lifecycle_state'] as String? ?? candidate,
      feedback: row['user_feedback'] as String? ?? 'neutral',
      comment: row['user_comment'] as String? ?? '',
      createdAt: date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      savedAt: date('saved_at'),
      deleteAfter: date('delete_after'),
      unread: row['unread'] == 1,
    );
  }
}

class CompanionBrowserVisit {
  const CompanionBrowserVisit({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.domain,
    required this.provider,
    required this.discoveredAt,
    required this.actionRunId,
  });

  final String id;
  final String title;
  final String summary;
  final String url;
  final String domain;
  final String provider;
  final DateTime discoveredAt;
  final String actionRunId;

  factory CompanionBrowserVisit.fromDb(Map<String, Object?> row) =>
      CompanionBrowserVisit(
        id: row['id'] as String? ?? '',
        title: row['title'] as String? ?? '',
        summary: row['summary'] as String? ?? '',
        url: row['url'] as String? ?? '',
        domain: row['source_domain'] as String? ?? '',
        provider: row['provider'] as String? ?? '',
        discoveredAt: DateTime.fromMillisecondsSinceEpoch(
          (row['discovered_at'] as num?)?.toInt() ?? 0,
        ),
        actionRunId: row['action_run_id'] as String? ?? '',
      );
}
