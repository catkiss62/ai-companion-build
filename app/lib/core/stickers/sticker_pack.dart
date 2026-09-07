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

/// UI-only labels for imported sticker metadata. Stable pack ids and the
/// on-disk ZIP/index stay untouched so re-import and replacement still work.
class StickerDisplayLabels {
  const StickerDisplayLabels._();

  static String packName(StickerPackMeta pack) => switch (pack.id) {
        'personal-001' => '表情包A',
        'official-001' => '表情包B',
        _ => pack.name,
      };

  static String tagName(String tag) {
    final normalized = tag.trim().toLowerCase();
    return switch (normalized) {
      'angry' => '生气',
      'happy' => '开心',
      'sad' => '难过',
      'shy' => '害羞',
      'confused' => '困惑',
      'daily' => '日常',
      'surprised' => '惊讶',
      'sleep' => '睡觉',
      'meow' => '喵喵',
      'morning' => '早上好',
      'work' => '上班',
      'like' => '喜欢',
      'see' => '看看',
      'reply' => '回复',
      'sigh' => '叹气',
      'baka' => '笨蛋',
      'fool' => '傻瓜',
      'givemoney' => '给钱',
      'color' => '彩色',
      'cpu' => 'CPU',
      _ => tag.trim().isEmpty ? '其他' : tag.trim(),
    };
  }
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
