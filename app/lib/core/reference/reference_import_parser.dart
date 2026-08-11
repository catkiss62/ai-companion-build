import 'dart:convert';

class ReferenceDraft {
  const ReferenceDraft({
    required this.section,
    required this.title,
    required this.content,
    this.tags = const [],
    this.weight = 0.55,
  });

  final String section;
  final String title;
  final String content;
  final List<String> tags;
  final double weight;
}

/// Conservative importer for old index/persona material.
///
/// It intentionally ignores chat history, saves, reasoning and dynamic state.
/// Imported text is reference DATA. PromptBuilder explicitly prevents it from
/// replacing the AI companion's base identity unless the user asks to roleplay.
class ReferenceImportParser {
  static final RegExp _allowedKey = RegExp(
    r'(name|persona|character|profile|prompt|identity|personality|appearance|speech|style|background|setting|relationship|like|dislike|habit|preference|description|bio|trait|rule|nsfw|adult|人设|角色|姓名|名字|身份|性格|外貌|说话|语言|文风|背景|设定|关系|喜好|偏好|习惯|简介|描述|规则|成人|亲密)',
    caseSensitive: false,
  );
  static final RegExp _blockedKey = RegExp(
    r'(message|conversation|history|chat|reasoning|thought|log|save|archive|timestamp|token|cache|flag|scene_state|messages|对话|聊天|历史|思考链|日志|存档|缓存)',
    caseSensitive: false,
  );

  List<ReferenceDraft> parse({
    required String raw,
    String mode = 'auto',
  }) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    if (mode == 'json' || (mode == 'auto' && (text.startsWith('{') || text.startsWith('[')))) {
      try {
        return _parseJson(jsonDecode(text));
      } catch (_) {
        if (mode == 'json') rethrow;
      }
    }
    return _parseText(text);
  }

  List<ReferenceDraft> _parseJson(Object? root) {
    final out = <ReferenceDraft>[];
    void walk(Object? node, List<String> path, {int depth = 0}) {
      if (depth > 8 || out.length >= 180) return;
      if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key.toString().trim();
          if (key.isEmpty || _blockedKey.hasMatch(key)) continue;
          final next = [...path, key];
          final value = entry.value;
          if (value is String || value is num || value is bool) {
            final s = value.toString().trim();
            if (s.length < 2 || (!_allowedKey.hasMatch(key) && !_allowedKey.hasMatch(next.join('.')))) continue;
            _chunkInto(out, _sectionFor(key), next.join(' › '), s, [key]);
          } else if (_allowedKey.hasMatch(key) || depth < 3) {
            walk(value, next, depth: depth + 1);
          }
        }
      } else if (node is List) {
        for (var i = 0; i < node.length && i < 60; i++) {
          walk(node[i], [...path, '#${i + 1}'], depth: depth + 1);
        }
      }
    }
    walk(root, const []);
    return _dedupe(out);
  }

  List<ReferenceDraft> _parseText(String text) {
    final out = <ReferenceDraft>[];
    final blocks = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 3);
    var index = 0;
    for (final block in blocks) {
      index++;
      final first = block.split('\n').first.trim();
      final title = first.length <= 48 ? first.replaceAll(RegExp(r'^[#*\-\s]+'), '') : '参考片段 $index';
      _chunkInto(out, _sectionFor(first), title, block, const []);
    }
    return _dedupe(out);
  }

  void _chunkInto(
    List<ReferenceDraft> out,
    String section,
    String title,
    String content,
    List<String> tags,
  ) {
    const maxChars = 1200;
    var rest = content.trim();
    var part = 1;
    while (rest.isNotEmpty && out.length < 180) {
      var cut = rest.length <= maxChars ? rest.length : maxChars;
      if (cut < rest.length) {
        final candidate = rest.substring(0, cut);
        final boundary = candidate.lastIndexOf(RegExp(r'[。！？!?；;\n]'));
        if (boundary > maxChars * 0.55) cut = boundary + 1;
      }
      final piece = rest.substring(0, cut).trim();
      if (piece.length >= 2) {
        out.add(ReferenceDraft(
          section: section,
          title: part == 1 ? title : '$title · $part',
          content: piece,
          tags: tags,
          weight: _weightFor(section),
        ));
      }
      rest = rest.substring(cut).trim();
      part++;
    }
  }

  List<ReferenceDraft> _dedupe(List<ReferenceDraft> input) {
    final seen = <String>{};
    final out = <ReferenceDraft>[];
    for (final item in input) {
      final key = item.content.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(item);
    }
    return out;
  }

  String _sectionFor(String key) {
    final k = key.toLowerCase();
    if (RegExp(r'(speech|style|文风|说话|语言)').hasMatch(k)) return 'speaking_style';
    if (RegExp(r'(appearance|外貌)').hasMatch(k)) return 'appearance';
    if (RegExp(r'(background|setting|背景|设定)').hasMatch(k)) return 'background';
    if (RegExp(r'(like|dislike|habit|preference|喜好|偏好|习惯)').hasMatch(k)) return 'preferences';
    if (RegExp(r'(nsfw|adult|成人|亲密)').hasMatch(k)) return 'intimacy_reference';
    if (RegExp(r'(rule|规则)').hasMatch(k)) return 'reference_rules';
    if (RegExp(r'(persona|personality|trait|identity|人设|性格|身份)').hasMatch(k)) return 'persona_reference';
    return 'other';
  }

  double _weightFor(String section) => switch (section) {
        'speaking_style' => 0.70,
        'preferences' => 0.66,
        'persona_reference' => 0.62,
        'intimacy_reference' => 0.60,
        'background' => 0.54,
        'reference_rules' => 0.50,
        _ => 0.46,
      };
}
