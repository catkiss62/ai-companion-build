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
    source: EmotionSource.fallback,
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

class EmotionSource {
  const EmotionSource._();

  static const llm = 'llm';
  static const llmRecovered = 'llm_recovered';
  static const fallbackMissing = 'heuristic_missing_tag';
  static const fallbackEmpty = 'heuristic_empty_tag';
  static const fallbackInvalid = 'heuristic_invalid_tag';
  static const fallbackMalformed = 'heuristic_malformed_tag';
  static const fallbackLegacy = 'heuristic';
  static const fallback = 'fallback';

  static String diagnosticStatus(String source) => switch (source) {
        llm => 'valid_tag',
        llmRecovered => 'recovered_tag',
        fallbackMissing => 'missing_tag',
        fallbackEmpty => 'empty_tag',
        fallbackInvalid => 'invalid_tag',
        fallbackMalformed => 'malformed_tag',
        fallbackLegacy => 'legacy_heuristic',
        fallback => 'neutral_fallback',
        _ => 'unknown_source',
      };
}

class EmotionCatalog {
  const EmotionCatalog._();

  static const labelsByKey = <String, String>{
    'excited': '兴奋',
    'disgust': '厌恶',
    'crying': '伤心',
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

  static const aliasKeysByLabel = <String, String>{
    '哭泣': 'crying',
    '羞耻': 'embarrassed',
    '尴尬': 'embarrassed',
    '无语': 'helpless',
    '情动': 'affection',
    '慌乱': 'flustered',
    '开心': 'happy',
    '激动': 'excited',
  };

  static final keysByLabel = <String, String>{
    for (final entry in labelsByKey.entries) entry.value: entry.key,
    ...aliasKeysByLabel,
  };

  static bool isCanonicalLabel(String value) =>
      keysByLabel.containsKey(normalizeTag(value));

  static String normalizeTag(String value) => value
      .trim()
      .replaceAll(RegExp(r'^[\[【（(<{]+|[\]】）)>}]+$'), '')
      .replaceAll(RegExp(r'^(情绪|emotion)\s*[:：=]\s*', caseSensitive: false), '')
      .trim();

  static String keyForLabel(String label) =>
      keysByLabel[normalizeTag(label)] ?? '';

  static String labelForKey(String key) => labelsByKey[key] ?? '';

  static String minimaxEmotionForKey(String key) => minimaxByKey[key] ?? 'neutral';
}

enum EmotionEnvelopeStatus {
  canonical,
  recovered,
  missing,
  empty,
  invalid,
  malformed,
}

class EmotionEnvelopeData {
  const EmotionEnvelopeData({
    required this.rawTag,
    required this.visibleText,
    required this.found,
    required this.status,
  });

  final String rawTag;
  final String visibleText;
  final bool found;
  final EmotionEnvelopeStatus status;
}

class EmotionEnvelope {
  const EmotionEnvelope._();

  static final RegExp _complete = RegExp(
    r'<\s*emotion\s*>\s*([^<\r\n]{0,80}?)\s*<\s*/\s*emotion\s*>',
    caseSensitive: false,
  );
  static final RegExp _selfClosing = RegExp(
    r'<\s*emotion\s*/\s*>',
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
  static final RegExp _recoverableXmlFirstLine = RegExp(
    r'^\s*<\s*emotion\s*>\s*([^<\r\n]{1,80}?)\s*(?:\r?\n|$)',
    caseSensitive: false,
  );
  static final RegExp _recoverableNamedFirstLine = RegExp(
    r'^\s*(?:[\[【(（]\s*)?(?:emotion|情绪)\s*[:：=]\s*([^\]】)）\r\n]{1,80}?)(?:\s*[\]】)）])?\s*(?:\r?\n|$)',
    caseSensitive: false,
  );
  static final RegExp _malformedFirstLine = RegExp(
    r'^\s*<\s*emotion\b[^\r\n]*(?:\r?\n|$)',
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
        return EmotionEnvelopeData(
          rawTag: rawTag,
          visibleText: _stripReservedMarkup(raw).trim(),
          found: true,
          status: EmotionEnvelopeStatus.canonical,
        );
      }
    }
    if (matches.isNotEmpty) {
      return EmotionEnvelopeData(
        rawTag: rawTag,
        visibleText: _stripReservedMarkup(raw).trim(),
        found: true,
        status: rawTag.isEmpty
            ? EmotionEnvelopeStatus.empty
            : EmotionEnvelopeStatus.invalid,
      );
    }

    for (final pattern in [
      _recoverableXmlFirstLine,
      _recoverableNamedFirstLine,
    ]) {
      final match = pattern.firstMatch(raw);
      if (match == null) continue;
      final candidate = EmotionCatalog.normalizeTag(match.group(1) ?? '');
      return EmotionEnvelopeData(
        rawTag: candidate,
        visibleText: _stripReservedMarkup(raw).trim(),
        found: true,
        status: candidate.isEmpty
            ? EmotionEnvelopeStatus.empty
            : EmotionCatalog.isCanonicalLabel(candidate)
                ? EmotionEnvelopeStatus.recovered
                : EmotionEnvelopeStatus.invalid,
      );
    }

    final hasEmptyEnvelope =
        _selfClosing.hasMatch(raw) || _closing.hasMatch(raw);
    final hasMalformedEnvelope =
        _opening.hasMatch(raw) || _malformedFirstLine.hasMatch(raw);
    return EmotionEnvelopeData(
      rawTag: '',
      visibleText: _stripReservedMarkup(raw).trim(),
      found: hasEmptyEnvelope || hasMalformedEnvelope,
      status: hasMalformedEnvelope
          ? EmotionEnvelopeStatus.malformed
          : hasEmptyEnvelope
              ? EmotionEnvelopeStatus.empty
              : EmotionEnvelopeStatus.missing,
    );
  }

  /// The envelope is machine-only. Complete, duplicated, misplaced and
  /// incomplete tags are never released to chat bubbles, history or TTS.
  static String streamingVisible(String raw) => _stripReservedMarkup(raw);

  static String _stripReservedMarkup(String raw) {
    var value = raw.replaceAll(_complete, '');
    value = value.replaceFirst(_recoverableXmlFirstLine, '');
    value = value.replaceFirst(_recoverableNamedFirstLine, '');
    value = value.replaceFirst(_malformedFirstLine, '');
    value = value.replaceAll(_selfClosing, '');
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
