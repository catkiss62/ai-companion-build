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

  static int comparePacks(StickerPackMeta a, StickerPackMeta b) {
    const preferredOrder = <String, int>{
      'personal-001': 0,
      'official-001': 1,
    };
    final byPreferred = (preferredOrder[a.id] ?? 1000)
        .compareTo(preferredOrder[b.id] ?? 1000);
    if (byPreferred != 0) return byPreferred;
    final byLabel = packName(a).compareTo(packName(b));
    return byLabel != 0 ? byLabel : a.id.compareTo(b.id);
  }

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
      'nsfw' => '涩涩',
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

/// Content-level expression policy for the imported private pack. The NSFW
/// switch controls generation style, not whether a known sticker exists. Only
/// the obsolete group-chat waste gag stays hidden; the dark-humor record is a
/// valid part of the companion's own expression range.
class StickerAgencyPolicy {
  const StickerAgencyPolicy._();

  static bool isVisible(StickerRecord record) => !_isGroupChatWaste(record);

  static bool isAssistantSelectable(StickerRecord record) {
    if (_isGroupChatWaste(record)) return false;
    if (record.toneScope == 'disabled') return _isDarkHumor(record);
    return record.enabled;
  }

  static String categoryKey(StickerRecord record) =>
      record.toneScope == 'nsfw' ? 'nsfw' : record.tag;

  static bool _isGroupChatWaste(StickerRecord record) =>
      record.toneScope == 'disabled' &&
      RegExp(
        r'(群友|群聊|便便|大便|粑粑|拉屎|排泄|投喂.*(?:屎|便))',
      ).hasMatch(_semanticText(record));

  static bool _isDarkHumor(StickerRecord record) =>
      record.toneScope == 'disabled' &&
      RegExp(
        r'(上吊|吊死|轻生|自杀|自尽|绳子)',
      ).hasMatch(_semanticText(record));

  static String _semanticText(StickerRecord record) =>
      '${record.caption} ${record.keywords}'.toLowerCase();
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
