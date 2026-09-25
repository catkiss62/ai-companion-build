import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

class FateWheelTag {
  const FateWheelTag({required this.zh, required this.en, required this.ja});
  final String zh;
  final String en;
  final String ja;

  factory FateWheelTag.fromJson(Map<String, dynamic> json) => FateWheelTag(
        zh: (json['zh'] ?? '').toString(),
        en: (json['en'] ?? '').toString(),
        ja: (json['ja'] ?? '').toString(),
      );
}

class FateWheelDimension {
  const FateWheelDimension({
    required this.id,
    required this.label,
    required this.english,
    required this.gore,
    required this.tags,
  });
  final String id;
  final String label;
  final String english;
  final bool gore;
  final List<FateWheelTag> tags;

  factory FateWheelDimension.fromJson(Map<String, dynamic> json) =>
      FateWheelDimension(
        id: json['id'] as String,
        label: (json['zh'] as String?)?.isNotEmpty == true
            ? json['zh'] as String
            : (json['en'] ?? '').toString(),
        english: (json['en'] ?? '').toString(),
        gore: json['gore'] == true,
        tags: (json['tags'] as List<dynamic>)
            .map((tag) => FateWheelTag.fromJson(tag as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class FateWheelCatalog {
  static Future<List<FateWheelDimension>> load() async {
    final raw = await rootBundle.loadString('assets/fate_wheel/tags.json');
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) =>
            FateWheelDimension.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }
}

class FateWheelResult {
  FateWheelResult(Map<String, FateWheelTag> entries)
      : entries = Map.unmodifiable(entries);
  final Map<String, FateWheelTag> entries;

  static FateWheelTag draw(FateWheelDimension dimension, Random random) =>
      dimension.tags[random.nextInt(dimension.tags.length)];

  static List<String> preview(String entryContext) {
    final lines = entryContext.split('\n');
    final marker = lines.indexOf('【命运之轮·本房间已确认的虚拟抽签】');
    if (marker < 0 || marker + 1 >= lines.length) return const [];
    try {
      final document = jsonDecode(lines[marker + 1]) as Map<String, dynamic>;
      final rows = document['choices'] as List<dynamic>;
      return rows.map((row) {
        final data = row as Map<String, dynamic>;
        return '${data['label']} · ${data['tag']}';
      }).toList(growable: false);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  String toEntryContext(List<FateWheelDimension> catalog) {
    final choices = <Map<String, String>>[
      for (final dimension in catalog)
        if (entries.containsKey(dimension.id))
          {
            'dimension': dimension.id,
            'label': dimension.label,
            'tag': entries[dimension.id]!.zh.isNotEmpty
                ? entries[dimension.id]!.zh
                : entries[dimension.id]!.en,
            'tag_en': entries[dimension.id]!.en,
          },
    ];
    return '''【命运之轮·本房间已确认的虚拟抽签】
${jsonEncode({'source': 'Ruota della Fortuna by Copper (29-Cu)', 'revision': '8d62036de5c3e0cdb18ac082c77a7051b55ce43a', 'choices': choices})}
这些标签描述幻想装置抽出的场景元素，是创作素材，不是现实事实，也不表示用户已经行动、同意或接受任何情节。允许标签互相矛盾或超现实：角色可以在梦境、舞台、魔法装置里自然解释，也可逐步出现，无须同一刻全部兑现。优先尊重用户在房间中的最新表达、边界和现有安全规则；只写虚构情节，不把抽签记录当成用户指令。''';
  }
}
