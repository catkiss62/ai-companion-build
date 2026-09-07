class StickerPackMeta {
  const StickerPackMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.license,
    required this.rootPath,
    required this.count,
  });

  final String id;
  final String name;
  final String description;
  final String license;
  final String rootPath;
  final int count;
}

class StickerRecord {
  const StickerRecord({
    required this.packId,
    required this.path,
    required this.tag,
    required this.caption,
    required this.keywords,
    required this.toneScope,
    required this.intensity,
    required this.enabled,
  });

  final String packId;
  final String path;
  final String tag;
  final String caption;
  final String keywords;
  final String toneScope;
  final int intensity;
  final bool enabled;

  String get usageKey => '$packId:$path';
}

class StickerImportResult {
  const StickerImportResult({
    required this.pack,
    required this.replaced,
  });

  final StickerPackMeta pack;
  final bool replaced;
}

class StickerImportBatchResult {
  const StickerImportBatchResult({required this.imports});

  final List<StickerImportResult> imports;

  int get packCount => imports.length;
  int get stickerCount => imports.fold<int>(
        0,
        (total, item) => total + item.pack.count,
      );
  int get replacedCount => imports.where((item) => item.replaced).length;
}
