import '../models/chat_language_variant.dart';

class TtsAcousticSegmenter {
  const TtsAcousticSegmenter._();

  static List<String> split(String text, ChatLanguage language) {
    final normalized = text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (normalized.isEmpty) return const <String>[];
    final target = language == ChatLanguage.english ? 88 : 42;
    final maximum = language == ChatLanguage.english ? 110 : 54;
    final result = <String>[];
    var remaining = normalized;
    while (remaining.length > maximum) {
      final cut = _findCut(remaining, target: target, maximum: maximum);
      final chunk = remaining.substring(0, cut).trim();
      if (chunk.isNotEmpty) result.add(chunk);
      remaining = remaining.substring(cut).trimLeft();
    }
    if (remaining.isNotEmpty) result.add(remaining);
    return result;
  }

  static int _findCut(
    String text, {
    required int target,
    required int maximum,
  }) {
    final safeMaximum = _safeCut(text, maximum);
    final lower = (target * 0.62).round();
    for (final punctuation in const <String>['。！？.!?;', '；', '，,、：: ']) {
      var best = -1;
      for (var index = lower; index < safeMaximum; index++) {
        if (punctuation.contains(text[index])) best = index + 1;
      }
      if (best > 0) return _safeCut(text, best);
    }
    return safeMaximum;
  }

  static int _safeCut(String text, int requested) {
    var cut = requested.clamp(1, text.length - 1).toInt();
    if (cut < text.length &&
        _isLowSurrogate(text.codeUnitAt(cut)) &&
        _isHighSurrogate(text.codeUnitAt(cut - 1))) {
      cut--;
    }
    return cut;
  }

  static bool _isHighSurrogate(int value) => value >= 0xD800 && value <= 0xDBFF;
  static bool _isLowSurrogate(int value) => value >= 0xDC00 && value <= 0xDFFF;
}
