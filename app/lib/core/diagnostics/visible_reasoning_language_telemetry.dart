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
        latinWords >= 8 &&
        latinLetters > chineseCount * 3) {
      return VisibleReasoningLanguageStatus.mixed;
    }
    return VisibleReasoningLanguageStatus.chineseFirst;
  }

  /// UI-only offer gate for an optional manual translation. Code blocks,
  /// inline code and URLs do not count as English prose because they should be
  /// preserved rather than translated.
  static bool shouldOfferTranslation(String reasoning) {
    final prose = reasoning
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'`[^`\n]*`'), ' ')
        .replaceAll(RegExp(r'https?://\S+'), ' ');
    final status = classify(prose);
    return status == VisibleReasoningLanguageStatus.mixed ||
        status == VisibleReasoningLanguageStatus.mainlyEnglish;
  }

  static Future<void> note(
    AppDatabase db,
    String reasoning, {
    bool providerDeltaSeen = false,
    bool forwardedToSurface = false,
  }) async {
    try {
      final status = classify(reasoning);
      final total = _int(await db.getSetting('reasoning_language_total')) + 1;
      final key = 'reasoning_language_${status.key}_count';
      final count = _int(await db.getSetting(key)) + 1;
      await db.setSetting('reasoning_language_total', total.toString());
      await db.setSetting(key, count.toString());
      await db.setSetting('reasoning_language_last_status', status.key);
      await _incrementFlag(
        db,
        prefix: 'reasoning_provider_delta',
        value: providerDeltaSeen,
      );
      await _incrementFlag(
        db,
        prefix: 'reasoning_final_present',
        value: reasoning.trim().isNotEmpty,
      );
      await _incrementFlag(
        db,
        prefix: 'reasoning_surface_forwarded',
        value: forwardedToSurface,
      );
      await db.setSetting(
        'reasoning_language_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Diagnostics must never delay or reject a completed message.
    }
  }

  /// Records only that the Flutter chat state received a non-empty reasoning
  /// delta and requested a repaint. It never stores the delta itself.
  static Future<void> noteUiPresentation(AppDatabase db) async {
    try {
      final count = _int(
            await db.getSetting('reasoning_ui_presentation_count'),
          ) +
          1;
      await db.setSetting('reasoning_ui_presentation_count', count.toString());
      await db.setSetting(
        'reasoning_ui_presentation_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Diagnostics must never delay or reject a visible reasoning update.
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
      'providerDeltaSeen': value(
        await db.getSetting('reasoning_provider_delta_true_count'),
      ),
      'providerDeltaMissing': value(
        await db.getSetting('reasoning_provider_delta_false_count'),
      ),
      'finalReasoningPresent': value(
        await db.getSetting('reasoning_final_present_true_count'),
      ),
      'finalReasoningMissing': value(
        await db.getSetting('reasoning_final_present_false_count'),
      ),
      'reasoningDeltaForwardedToSurface': value(
        await db.getSetting('reasoning_surface_forwarded_true_count'),
      ),
      'reasoningDeltaNotForwardedToSurface': value(
        await db.getSetting('reasoning_surface_forwarded_false_count'),
      ),
      'uiPresentationTriggered': value(
        await db.getSetting('reasoning_ui_presentation_count'),
      ),
      'uiPresentationLastAt': value(
        await db.getSetting('reasoning_ui_presentation_last_at'),
      ),
      'reasoningTextIncluded': false,
      'matchedWordsIncluded': false,
    };
  }

  static int _int(String? value) => int.tryParse(value ?? '') ?? 0;

  static Future<void> _incrementFlag(
    AppDatabase db, {
    required String prefix,
    required bool value,
  }) async {
    final suffix = value ? 'true' : 'false';
    final key = '${prefix}_${suffix}_count';
    final count = _int(await db.getSetting(key)) + 1;
    await db.setSetting(key, count.toString());
  }
}
