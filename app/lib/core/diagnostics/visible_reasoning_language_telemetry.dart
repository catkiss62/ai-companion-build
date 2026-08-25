import '../database/app_database.dart';

enum VisibleReasoningLanguageStatus {
  empty,
  chineseFirst,
  mixed,
  mainlyEnglish,
}

extension VisibleReasoningLanguageStatusKey
    on VisibleReasoningLanguageStatus {
  String get key => switch (this) {
        VisibleReasoningLanguageStatus.empty => 'empty',
        VisibleReasoningLanguageStatus.chineseFirst => 'chinese_first',
        VisibleReasoningLanguageStatus.mixed => 'mixed',
        VisibleReasoningLanguageStatus.mainlyEnglish => 'mainly_english',
      };
}

/// Stores only language-shape counters. The reasoning text, matched words and
/// fragments are never persisted by this telemetry path.
class VisibleReasoningLanguageTelemetry {
  const VisibleReasoningLanguageTelemetry._();

  static final RegExp _chinese = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]');
  static final RegExp _latinWord = RegExp(r'[A-Za-z]{2,}');

  static VisibleReasoningLanguageStatus classify(String reasoning) {
    final text = reasoning.trim();
    if (text.isEmpty) return VisibleReasoningLanguageStatus.empty;
    final chineseCount = _chinese.allMatches(text).length;
    final latinWords = _latinWord.allMatches(text).length;
    final latinLetters = RegExp(r'[A-Za-z]').allMatches(text).length;
    if (chineseCount == 0 && latinWords >= 3) {
      return VisibleReasoningLanguageStatus.mainlyEnglish;
    }
    if (chineseCount > 0 &&
        latinWords >= 4 &&
        latinLetters > chineseCount * 1.5) {
      return VisibleReasoningLanguageStatus.mixed;
    }
    return VisibleReasoningLanguageStatus.chineseFirst;
  }

  static Future<void> note(AppDatabase db, String reasoning) async {
    try {
      final status = classify(reasoning);
      final total = _int(await db.getSetting('reasoning_language_total')) + 1;
      final key = 'reasoning_language_${status.key}_count';
      final count = _int(await db.getSetting(key)) + 1;
      await db.setSetting('reasoning_language_total', total.toString());
      await db.setSetting(key, count.toString());
      await db.setSetting('reasoning_language_last_status', status.key);
      await db.setSetting(
        'reasoning_language_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Diagnostics must never delay or reject a completed message.
    }
  }

  static Future<Map<String, Object?>> snapshot(AppDatabase db) async {
    int value(String? raw) => _int(raw);
    return <String, Object?>{
      'total': value(await db.getSetting('reasoning_language_total')),
      'empty': value(
        await db.getSetting('reasoning_language_empty_count'),
      ),
      'chineseFirst': value(
        await db.getSetting('reasoning_language_chinese_first_count'),
      ),
      'mixed': value(
        await db.getSetting('reasoning_language_mixed_count'),
      ),
      'mainlyEnglish': value(
        await db.getSetting('reasoning_language_mainly_english_count'),
      ),
      'lastStatus':
          await db.getSetting('reasoning_language_last_status') ?? 'none',
      'lastAt': value(await db.getSetting('reasoning_language_last_at')),
      'reasoningTextIncluded': false,
      'matchedWordsIncluded': false,
    };
  }

  static int _int(String? value) => int.tryParse(value ?? '') ?? 0;
}
