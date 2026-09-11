import 'dart:convert';

import '../models/chat_segment.dart';
import '../models/chat_language_variant.dart';

enum TtsReadingScope {
  dialogueOnly('dialogue_only', '仅朗读对白（「」内）'),
  fullText('full_text', '朗读全文（动作 + 对白）');

  const TtsReadingScope(this.key, this.label);
  final String key;
  final String label;

  static TtsReadingScope fromSetting(String? value) =>
      value == fullText.key ? fullText : dialogueOnly;
}

enum TtsSpeechRole { dialogue, narration }

class TtsPreparedUnit {
  const TtsPreparedUnit({required this.text, required this.role});

  final String text;
  final TtsSpeechRole role;
}

class TtsTextProcessor {
  const TtsTextProcessor();

  String process(
    String text, {
    ChatLanguage language = ChatLanguage.chinese,
    Map<String, String> replacements = const {},
    TtsReadingScope scope = TtsReadingScope.dialogueOnly,
  }) {
    // Strip inline action blocks before parsing dialogue-only speech. Parsing
    // first would split `保留（动作）正文` into two dialogue segments and the
    // segment join below would invent a sentence boundary: `保留。正文`.
    final segmentSource = scope == TtsReadingScope.dialogueOnly
        ? text.replaceAll(RegExp(r'（[^（）\n]*）|\([^()\n]*\)'), '')
        : text;
    return processUnits(
      segmentSource,
      language: language,
      replacements: replacements,
      scope: scope,
    ).map((unit) => unit.text).join('。');
  }

  List<TtsPreparedUnit> processUnits(
    String text, {
    ChatLanguage language = ChatLanguage.chinese,
    Map<String, String> replacements = const {},
    TtsReadingScope scope = TtsReadingScope.dialogueOnly,
  }) {
    final segmentSource = scope == TtsReadingScope.dialogueOnly
        ? text.replaceAll(RegExp(r'（[^（）\n]*）|\([^()\n]*\)'), '')
        : text;
    final segments = ChatSegmentCodec.parseAssistantText(segmentSource);
    final selected = scope == TtsReadingScope.dialogueOnly
        ? segments.where((item) => item.kind == ChatSegmentKind.dialogue)
        : segments;
    return selected
        .map(
          (item) => processUnit(
            item.text,
            role: item.kind == ChatSegmentKind.action
                ? TtsSpeechRole.narration
                : TtsSpeechRole.dialogue,
            language: language,
            replacements: replacements,
          ),
        )
        .where((item) => item.text.isNotEmpty)
        .toList(growable: false);
  }

  TtsPreparedUnit processUnit(
    String text, {
    required TtsSpeechRole role,
    ChatLanguage language = ChatLanguage.chinese,
    Map<String, String> replacements = const {},
  }) {
    var result = text.trim();
    if (role == TtsSpeechRole.dialogue) {
      result = result
          .replaceFirst(RegExp(r'^[「“"]+'), '')
          .replaceFirst(RegExp(r'[」”"]+$'), '');
    } else {
      result = result
          .replaceFirst(RegExp(r'^[（(]+'), '')
          .replaceFirst(RegExp(r'[）)]+$'), '');
    }

    // User replacements are speech-only and never touch the visible chat body.
    for (final entry in replacements.entries) {
      if (entry.key.isEmpty) continue;
      result = result.replaceAll(entry.key, entry.value);
    }

    // Fixed Genie pronunciation compatibility. Phrase-phone overrides in the
    // Android adapter preserve the requested neutral tones after these spoken-
    // text-only aliases are applied.
    if (language == ChatLanguage.chinese) {
      result = result
          .replaceAll(RegExp(r'\bDeepSeek\b', caseSensitive: false), '地铺C咳')
          .replaceAll(RegExp(r'\btoken\b', caseSensitive: false), '拖肯');
    }

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
    return TtsPreparedUnit(text: result, role: role);
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
