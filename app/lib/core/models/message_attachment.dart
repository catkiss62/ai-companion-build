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
  });

  static const String imageKind = 'image';

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

  bool get isImage => kind == imageKind;

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
      };

  factory MessageAttachment.fromDb(Map<String, Object?> row) {
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
    );
  }
}
