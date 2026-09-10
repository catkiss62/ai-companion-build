class MediaBlob {
  const MediaBlob({
    required this.id,
    required this.originalPath,
    required this.thumbnailPath,
    required this.originalSha256,
    required this.thumbnailSha256,
    required this.mimeType,
    required this.byteSize,
    required this.thumbnailByteSize,
    required this.width,
    required this.height,
    required this.messageRefCount,
    required this.albumRefCount,
    required this.createdAt,
  });

  final String id;
  final String originalPath;
  final String thumbnailPath;
  final String originalSha256;
  final String thumbnailSha256;
  final String mimeType;
  final int byteSize;
  final int thumbnailByteSize;
  final int width;
  final int height;
  final int messageRefCount;
  final int albumRefCount;
  final DateTime createdAt;

  int get totalRefCount => messageRefCount + albumRefCount;

  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'original_path': originalPath,
        'thumbnail_path': thumbnailPath,
        'original_sha256': originalSha256,
        'thumbnail_sha256': thumbnailSha256,
        'mime_type': mimeType,
        'byte_size': byteSize,
        'thumbnail_byte_size': thumbnailByteSize,
        'width': width,
        'height': height,
        'message_ref_count': messageRefCount,
        'album_ref_count': albumRefCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MediaBlob.fromDb(Map<String, Object?> row) => MediaBlob(
        id: row['id'] as String? ?? '',
        originalPath: row['original_path'] as String? ?? '',
        thumbnailPath: row['thumbnail_path'] as String? ?? '',
        originalSha256: row['original_sha256'] as String? ?? '',
        thumbnailSha256: row['thumbnail_sha256'] as String? ?? '',
        mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
        byteSize: (row['byte_size'] as num?)?.toInt() ?? 0,
        thumbnailByteSize:
            (row['thumbnail_byte_size'] as num?)?.toInt() ?? 0,
        width: (row['width'] as num?)?.toInt() ?? 0,
        height: (row['height'] as num?)?.toInt() ?? 0,
        messageRefCount:
            (row['message_ref_count'] as num?)?.toInt() ?? 0,
        albumRefCount: (row['album_ref_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
}

class MediaCacheEntry {
  const MediaCacheEntry({
    required this.blob,
    required this.messageCount,
    required this.firstUsedAt,
    required this.lastUsedAt,
    required this.sources,
  });

  final MediaBlob blob;
  final int messageCount;
  final DateTime firstUsedAt;
  final DateTime lastUsedAt;
  final List<String> sources;

  int get reclaimableBytes => blob.byteSize + blob.thumbnailByteSize;
}
