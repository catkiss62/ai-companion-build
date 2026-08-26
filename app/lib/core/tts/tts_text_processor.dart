import 'dart:convert';

import '../models/chat_segment.dart';

enum TtsReadingScope {
  dialogueOnly('dialogue_only', '仅朗读对白（「」内）'),
  fullText('full_text', '朗读全文（动作 + 对白）');

  const TtsReadingScope(this.key, this.label);
  final String key;
  final String label;

  static TtsReadingScope fromSetting(String? value) =>
      value == fullText.key ? fullText : dialogueOnly;
}

class TtsTextProcessor {
  const TtsTextProcessor();

  String process(
    String text, {
    Map<String, String> replacements = const {},
    TtsReadingScope scope = TtsReadingScope.dialogueOnly,
  }) {
    final segments = ChatSegmentCodec.parseAssistantText(text);
    final quoted = ChatSegmentCodec.quotedDialogueParts(text);
    final spokenParts = scope == TtsReadingScope.dialogueOnly && quoted.isNotEmpty
        ? quoted
        : (scope == TtsReadingScope.dialogueOnly
                ? segments.where((item) => item.kind == ChatSegmentKind.dialogue)
                : segments)
            .map((item) => item.text.trim())
            .where((item) => item.isNotEmpty);
    var result = spokenParts.join(
      scope == TtsReadingScope.dialogueOnly ? '' : '。',
    );

    // User replacements are speech-only and never touch the visible chat body.
    for (final entry in replacements.entries) {
      if (entry.key.isEmpty) continue;
      result = result.replaceAll(entry.key, entry.value);
    }

    // Fixed Meju pronunciation compatibility. The original A2 processText()
    // explicitly maps Yuki/yuki/YuKi to 有希; use a case-insensitive word match
    // so the companion remains robust to model capitalization variants.
    result = result.replaceAll(RegExp(r'\bYuki\b', caseSensitive: false), '有希');

    // Technical/markup blocks stay speech-only. Legacy action parentheses have
    // already been decoded above, so full-text mode keeps their inner words.
    result = result
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
