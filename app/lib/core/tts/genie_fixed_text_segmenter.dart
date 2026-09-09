import '../models/chat_language_variant.dart';

/// Exact Dart port of the verified v0.6.4 ChineseTextSegmenter policy.
/// Despite its historical name, the same policy uses 88/110 for English.
class GenieFixedTextSegmenter {
  const GenieFixedTextSegmenter._();

  static List<String> split(String text, ChatLanguage language) {
    final english = language == ChatLanguage.english;
    return splitWithLimits(
      text,
      targetChars: english ? 88 : 42,
      maxChars: english ? 110 : 54,
    );
  }

  static List<String> splitWithLimits(
    String text, {
    int targetChars = 42,
    int maxChars = 54,
  }) {
    if (targetChars < 16 || targetChars > maxChars || maxChars > 140) {
      throw ArgumentError('invalid Genie fixed-segment limits');
    }
    final cleaned = text
        .trim()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (cleaned.isEmpty) return const <String>[];

    const hardStops = <String>{'。', '！', '？', '.', '!', '?', '；', ';', '\n'};
    final naturalUnits = <String>[];
    var current = '';
    for (final rune in cleaned.runes) {
      final char = String.fromCharCode(rune);
      if (char == '\n') {
        if (current.isNotEmpty && !hardStops.contains(current[current.length - 1])) {
          current += '。';
        }
      } else {
        current += char;
      }
      if (hardStops.contains(char) && current.trim().isNotEmpty) {
        naturalUnits.add(current.trim());
        current = '';
      }
    }
    if (current.trim().isNotEmpty) naturalUnits.add(current.trim());

    final pieces = <String>[
      for (final unit in naturalUnits) ..._splitOversized(unit, maxChars),
    ];
    final result = <String>[];
    var packed = '';
    for (final piece in pieces) {
      if (packed.isEmpty) {
        packed = piece;
      } else if (packed.length + piece.length <= targetChars) {
        packed += piece;
      } else {
        result.add(packed);
        packed = piece;
      }
    }
    if (packed.isNotEmpty) result.add(packed);
    if (result.any((item) => item.length > maxChars)) {
      throw StateError('Genie fixed segmentation failed');
    }
    return List<String>.unmodifiable(result);
  }

  static List<String> _splitOversized(String text, int maxChars) {
    if (text.length <= maxChars) return <String>[text];
    const softStops = <String>{'，', ',', '、', '：', ':', ' '};
    final result = <String>[];
    var remaining = text;
    while (remaining.length > maxChars) {
      var cut = -1;
      for (var index = maxChars - 1; index >= maxChars ~/ 2; index--) {
        if (softStops.contains(remaining[index])) {
          cut = index + 1;
          break;
        }
      }
      if (cut < 1) cut = maxChars;
      result.add(remaining.substring(0, cut).trim());
      remaining = remaining.substring(cut).trim();
    }
    if (remaining.isNotEmpty) result.add(remaining);
    return result;
  }
}
