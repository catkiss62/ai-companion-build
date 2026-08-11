import 'dart:convert';

class TtsTextProcessor {
  const TtsTextProcessor();

  String process(
    String text, {
    Map<String, String> replacements = const {},
  }) {
    var result = text;

    // User replacements are speech-only and never touch the visible chat body.
    for (final entry in replacements.entries) {
      if (entry.key.isEmpty) continue;
      result = result.replaceAll(entry.key, entry.value);
    }

    // Fixed Meju pronunciation compatibility. The original A2 processText()
    // explicitly maps Yuki/yuki/YuKi to 有希; use a case-insensitive word match
    // so the companion remains robust to model capitalization variants.
    result = result.replaceAll(RegExp(r'\bYuki\b', caseSensitive: false), '有希');

    // Meju A2 removes these blocks before sentence generation.
    result = result
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'【[^】]*】'), '');

    // Companion-specific markdown hygiene stays speech-only. It does not alter
    // A2 sentence boundaries and prevents code/format markers being read aloud.
    result = result
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'[*_#>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return result;
  }

  Map<String, String> decodeReplacementJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key.toString().trim().isNotEmpty)
            entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }
}
