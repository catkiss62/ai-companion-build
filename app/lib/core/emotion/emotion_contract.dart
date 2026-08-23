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
    r'^\s*<emotion>\s*([^<\r\n]{1,20})\s*</emotion>\s*(?:\r?\n)?',
    caseSensitive: false,
  );

  static EmotionEnvelopeData parse(String raw) {
    final match = _complete.firstMatch(raw);
    if (match == null) {
      return EmotionEnvelopeData(
        rawTag: '',
        visibleText: raw.trim(),
        found: false,
      );
    }
    return EmotionEnvelopeData(
      rawTag: EmotionCatalog.normalizeTag(match.group(1) ?? ''),
      visibleText: raw.substring(match.end).trim(),
      found: true,
    );
  }

  /// Hides an incomplete leading envelope during streaming. If the provider
  /// ignores the contract, ordinary text is released as soon as it can no
  /// longer be the beginning of the tag.
  static String streamingVisible(String raw) {
    final match = _complete.firstMatch(raw);
    if (match != null) return raw.substring(match.end);
    final leftTrimmed = raw.trimLeft();
    if (leftTrimmed.isEmpty) return '';
    const opening = '<emotion>';
    final probe = leftTrimmed.toLowerCase();
    if (opening.startsWith(probe) || probe.startsWith(opening)) return '';
    return raw;
  }
}
