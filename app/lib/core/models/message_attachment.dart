class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.messageId,
    required this.kind,
    required this.originalPath,
    required this.thumbnailPath,
    required this.mimeType,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.source,
    required this.createdAt,
    this.visionStatus = visionPendingStatus,
    this.visionSummary = '',
    this.visionModel = '',
    this.visionError = '',
    this.visionAttempts = 0,
    this.visionUpdatedAt,
  });

  static const String imageKind = 'image';
  static const String visionPendingStatus = 'pending';
  static const String visionAnalyzingStatus = 'analyzing';
  static const String visionCompletedStatus = 'completed';
  static const String visionFailedStatus = 'failed';

  final String id;
  final String messageId;
  final String kind;
  final String originalPath;
  final String thumbnailPath;
  final String mimeType;
  final int byteSize;
  final int width;
  final int height;
  final String source;
  final DateTime createdAt;
  final String visionStatus;
  final String visionSummary;
  final String visionModel;
  final String visionError;
  final int visionAttempts;
  final DateTime? visionUpdatedAt;

  bool get isImage => kind == imageKind;
  bool get visionPending =>
      visionStatus == visionPendingStatus ||
      visionStatus == visionAnalyzingStatus;
  bool get visionCompleted =>
      visionStatus == visionCompletedStatus && visionSummary.trim().isNotEmpty;
  bool get visionFailed => visionStatus == visionFailedStatus;

  MessageAttachment copyWith({
    String? visionStatus,
    String? visionSummary,
    String? visionModel,
    String? visionError,
    int? visionAttempts,
    DateTime? visionUpdatedAt,
  }) {
    return MessageAttachment(
      id: id,
      messageId: messageId,
      kind: kind,
      originalPath: originalPath,
      thumbnailPath: thumbnailPath,
      mimeType: mimeType,
      byteSize: byteSize,
      width: width,
      height: height,
      source: source,
      createdAt: createdAt,
      visionStatus: visionStatus ?? this.visionStatus,
      visionSummary: visionSummary ?? this.visionSummary,
      visionModel: visionModel ?? this.visionModel,
      visionError: visionError ?? this.visionError,
      visionAttempts: visionAttempts ?? this.visionAttempts,
      visionUpdatedAt: visionUpdatedAt ?? this.visionUpdatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'message_id': messageId,
        'kind': kind,
        'original_path': originalPath,
        'thumbnail_path': thumbnailPath,
        'mime_type': mimeType,
        'byte_size': byteSize,
        'width': width,
        'height': height,
        'source': source,
        'created_at': createdAt.millisecondsSinceEpoch,
        'vision_status': visionStatus,
        'vision_summary': visionSummary,
        'vision_model': visionModel,
        'vision_error': visionError,
        'vision_attempts': visionAttempts,
        'vision_updated_at': visionUpdatedAt?.millisecondsSinceEpoch,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'message_id': messageId,
        'kind': kind,
        'original_path': originalPath,
        'thumbnail_path': thumbnailPath,
        'mime_type': mimeType,
        'byte_size': byteSize,
        'width': width,
        'height': height,
        'source': source,
        'created_at': createdAt.toIso8601String(),
        'vision_status': visionStatus,
        'vision_summary': visionSummary,
        'vision_model': visionModel,
        'vision_error': visionError,
        'vision_attempts': visionAttempts,
        'vision_updated_at': visionUpdatedAt?.toIso8601String(),
      };

  factory MessageAttachment.fromDb(Map<String, Object?> row) {
    final visionUpdatedAt = (row['vision_updated_at'] as num?)?.toInt();
    return MessageAttachment(
      id: row['id'] as String,
      messageId: row['message_id'] as String,
      kind: row['kind'] as String? ?? imageKind,
      originalPath: row['original_path'] as String? ?? '',
      thumbnailPath: row['thumbnail_path'] as String? ?? '',
      mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
      byteSize: (row['byte_size'] as num?)?.toInt() ?? 0,
      width: (row['width'] as num?)?.toInt() ?? 0,
      height: (row['height'] as num?)?.toInt() ?? 0,
      source: row['source'] as String? ?? 'unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      visionStatus:
          row['vision_status'] as String? ?? visionPendingStatus,
      visionSummary: row['vision_summary'] as String? ?? '',
      visionModel: row['vision_model'] as String? ?? '',
      visionError: row['vision_error'] as String? ?? '',
      visionAttempts: (row['vision_attempts'] as num?)?.toInt() ?? 0,
      visionUpdatedAt: visionUpdatedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(visionUpdatedAt),
    );
  }
}
