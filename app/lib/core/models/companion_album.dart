import 'dart:convert';

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
    this.tags = const <String>['other'],
    required this.nsfw,
    required this.thumbnailPath,
    this.originalPath = '',
    this.originalContentSha256 = '',
    this.originalMimeType = '',
    this.originalByteSize = 0,
    this.originalStatus = 'missing',
    required this.contentSha256,
    required this.visualFingerprint,
    required this.perceptualHash,
    required this.visionModel,
    required this.width,
    required this.height,
    required this.lifecycle,
    required this.feedback,
    required this.comment,
    required this.categorySource,
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
  final List<String> tags;
  final bool nsfw;
  final String thumbnailPath;
  final String originalPath;
  final String originalContentSha256;
  final String originalMimeType;
  final int originalByteSize;
  final String originalStatus;
  final String contentSha256;
  final String visualFingerprint;
  final String perceptualHash;
  final String visionModel;
  final int width;
  final int height;
  final String lifecycle;
  final String feedback;
  final String comment;
  final String categorySource;
  final DateTime createdAt;
  final DateTime? savedAt;
  final DateTime? deleteAfter;
  final bool unread;

  bool get isVisible => lifecycle == saved || lifecycle == softDeleted;
  bool get isPendingDelete => lifecycle == softDeleted;
  bool get hasOriginal => originalStatus == 'stored' && originalPath.isNotEmpty;

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
      tags: _decodeAlbumTags(
        row['user_tags_json'],
        fallback: row['category'] as String? ?? 'other',
      ),
      nsfw: row['nsfw'] == 1,
      thumbnailPath: row['thumbnail_path'] as String? ?? '',
      originalPath: row['original_path'] as String? ?? '',
      originalContentSha256:
          row['original_content_sha256'] as String? ?? '',
      originalMimeType: row['original_mime_type'] as String? ?? '',
      originalByteSize: (row['original_byte_size'] as num?)?.toInt() ?? 0,
      originalStatus: row['original_status'] as String? ?? 'missing',
      contentSha256: row['content_sha256'] as String? ?? '',
      visualFingerprint: row['visual_fingerprint'] as String? ?? '',
      perceptualHash: row['perceptual_hash'] as String? ?? '',
      visionModel: row['vision_model'] as String? ?? '',
      width: (row['width'] as num?)?.toInt() ?? 0,
      height: (row['height'] as num?)?.toInt() ?? 0,
      lifecycle: row['lifecycle_state'] as String? ?? candidate,
      feedback: row['user_feedback'] as String? ?? 'neutral',
      comment: row['user_comment'] as String? ?? '',
      categorySource: row['category_source'] as String? ?? 'ai',
      createdAt: date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      savedAt: date('saved_at'),
      deleteAfter: date('delete_after'),
      unread: row['unread'] == 1,
    );
  }

  static List<String> _decodeAlbumTags(Object? raw, {required String fallback}) {
    try {
      final decoded = jsonDecode(raw?.toString() ?? '[]');
      if (decoded is List) {
        final normalized = normalizeAlbumTags(
          decoded.map((value) => value.toString()),
        );
        if (normalized.isNotEmpty) return normalized;
      }
    } catch (_) {}
    return normalizeAlbumTags(<String>[fallback]);
  }
}

const Set<String> companionAlbumTagKeys = <String>{
  'memory',
  'self_image',
  'anime',
  'landscape',
  'sticker',
  'other',
};

List<String> normalizeAlbumTags(Iterable<String> values) {
  final tags = <String>{
    for (final value in values)
      if (companionAlbumTagKeys.contains(value.trim())) value.trim(),
  };
  if (tags.length > 1) tags.remove('other');
  if (tags.isEmpty) tags.add('other');
  return companionAlbumTagKeys.where(tags.contains).toList(growable: false);
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
    this.readState = 'legacy_unverified',
    this.semanticState = 'legacy_unverified',
    this.keyPoints = const <String>[],
    this.topicTags = const <String>[],
    this.readAt,
    this.searchQuery = '',
  });

  final String id;
  final String title;
  final String summary;
  final String url;
  final String domain;
  final String provider;
  final DateTime discoveredAt;
  final String actionRunId;
  final String readState;
  final String semanticState;
  final List<String> keyPoints;
  final List<String> topicTags;
  final DateTime? readAt;
  final String searchQuery;

  bool get isLegacyUnverified => readState == 'legacy_unverified';

  factory CompanionBrowserVisit.fromDb(Map<String, Object?> row) {
    List<String> decodeStrings(Object? raw) {
      try {
        final value = jsonDecode(raw?.toString() ?? '[]');
        return value is List
            ? value.map((item) => item.toString()).toList(growable: false)
            : const <String>[];
      } catch (_) {
        return const <String>[];
      }
    }

    final rawReadAt = (row['read_at'] as num?)?.toInt();
    return CompanionBrowserVisit(
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
        readState: row['read_state'] as String? ?? 'legacy_unverified',
        semanticState:
            row['semantic_state'] as String? ?? 'legacy_unverified',
        keyPoints: decodeStrings(row['key_points_json']),
        topicTags: decodeStrings(row['topic_tags_json']),
        readAt: rawReadAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(rawReadAt),
        searchQuery: row['search_query'] as String? ?? '',
      );
  }
}
