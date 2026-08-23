import 'dart:convert';

class EmotionScore {
  const EmotionScore({
    required this.key,
    required this.label,
    required this.confidence,
  });

  final String key;
  final String label;
  final double confidence;

  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'label': label,
        'confidence': confidence,
      };

  factory EmotionScore.fromJson(Map<String, Object?> json) => EmotionScore(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

class CompanionEmotion {
  const CompanionEmotion({
    required this.rawTag,
    required this.key,
    required this.label,
    required this.confidence,
    required this.top3,
    required this.source,
  });

  final String rawTag;
  final String key;
  final String label;
  final double confidence;
  final List<EmotionScore> top3;
  final String source;

  static const calm = CompanionEmotion(
    rawTag: '',
    key: 'calm',
    label: '平静',
    confidence: 0,
    top3: <EmotionScore>[],
    source: 'fallback',
  );

  String get top3Json => jsonEncode(
        top3.map((item) => item.toJson()).toList(growable: false),
      );

  static List<EmotionScore> decodeTop3(String raw) {
    if (raw.trim().isEmpty) return const <EmotionScore>[];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const <EmotionScore>[];
      return value
          .whereType<Map>()
          .map((item) => EmotionScore.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .where((item) => item.key.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <EmotionScore>[];
    }
  }
}

class EmotionCatalog {
  const EmotionCatalog._();

  static const labelsByKey = <String, String>{
    'excited': '兴奋',
    'disgust': '厌恶',
    'crying': '哭泣',
    'afraid': '害怕',
    'shy': '害羞',
    'calm': '平静',
    'affection': '心动',
    'surprised': '惊讶',
    'flustered': '慌张',
    'worried': '担心',
    'helpless': '无奈',
    'angry': '生气',
    'confused': '疑惑',
    'nervous': '紧张',
    'confident': '自信',
    'serious': '认真',
    'playful': '调皮',
    'embarrassed': '难为情',
    'happy': '高兴',
  };

  // MiniMax Speech exposes seven provider emotions. Keep the richer local
  // labels intact and map only at the provider boundary.
  static const minimaxByKey = <String, String>{
    'excited': 'happy',
    'disgust': 'disgusted',
    'crying': 'sad',
    'afraid': 'fearful',
    'shy': 'neutral',
    'calm': 'neutral',
    'affection': 'happy',
    'surprised': 'surprised',
    'flustered': 'fearful',
    'worried': 'sad',
    'helpless': 'sad',
    'angry': 'angry',
    'confused': 'neutral',
    'nervous': 'fearful',
    'confident': 'neutral',
    'serious': 'neutral',
    'playful': 'happy',
    'embarrassed': 'neutral',
    'happy': 'happy',
  };

  static final keysByLabel = <String, String>{
    for (final entry in labelsByKey.entries) entry.value: entry.key,
  };

  static bool isCanonicalLabel(String value) =>
      keysByLabel.containsKey(normalizeTag(value));

  static String normalizeTag(String value) => value
      .trim()
      .replaceAll(RegExp(r'^[\[【（(<{]+|[\]】）)>}]+$'), '')
      .replaceAll(RegExp(r'^(情绪|emotion)\s*[:：]\s*', caseSensitive: false), '')
      .trim();

  static String keyForLabel(String label) =>
      keysByLabel[normalizeTag(label)] ?? '';

  static String labelForKey(String key) => labelsByKey[key] ?? '';

  static String minimaxEmotionForKey(String key) => minimaxByKey[key] ?? 'neutral';
}

class EmotionEnvelopeData {
  const EmotionEnvelopeData({
    required this.rawTag,
    required this.visibleText,
    required this.found,
  });

  final String rawTag;
  final String visibleText;
  final bool found;
}

class EmotionEnvelope {
  const EmotionEnvelope._();

  static final RegExp _complete = RegExp(
    r'<\s*emotion\s*>\s*([^<\r\n]{1,40}?)\s*<\s*/\s*emotion\s*>',
    caseSensitive: false,
  );
  static final RegExp _closing = RegExp(
    r'<\s*/\s*emotion\s*>',
    caseSensitive: false,
  );
  static final RegExp _opening = RegExp(
    r'<\s*emotion\b',
    caseSensitive: false,
  );

  static EmotionEnvelopeData parse(String raw) {
    final matches = _complete.allMatches(raw).toList(growable: false);
    var rawTag = '';
    for (final match in matches) {
      final candidate = EmotionCatalog.normalizeTag(match.group(1) ?? '');
      if (rawTag.isEmpty) rawTag = candidate;
      if (EmotionCatalog.isCanonicalLabel(candidate)) {
        rawTag = candidate;
        break;
      }
    }
    return EmotionEnvelopeData(
      rawTag: rawTag,
      visibleText: _stripReservedMarkup(raw).trim(),
      found: matches.isNotEmpty,
    );
  }

  /// The envelope is machine-only. Complete, duplicated, misplaced and
  /// incomplete tags are never released to chat bubbles, history or TTS.
  static String streamingVisible(String raw) => _stripReservedMarkup(raw);

  static String _stripReservedMarkup(String raw) {
    var value = raw.replaceAll(_complete, '');
    value = value.replaceAll(_closing, '');

    // A provider can be interrupted halfway through an opening envelope. From
    // the reserved opening token onward there is no safe user-visible text.
    final opening = _opening.firstMatch(value);
    if (opening != null) {
      value = value.substring(0, opening.start);
    }

    // Hide a partial tag at the streaming tail, such as "<emo" or
    // "</emotion". This only reserves the exact emotion tag prefix.
    final marker = value.lastIndexOf('<');
    if (marker >= 0) {
      final compact = value
          .substring(marker)
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      if ('<emotion>'.startsWith(compact) ||
          '</emotion>'.startsWith(compact) ||
          compact.startsWith('<emotion')) {
        value = value.substring(0, marker);
      }
    }
    return value;
  }
}
