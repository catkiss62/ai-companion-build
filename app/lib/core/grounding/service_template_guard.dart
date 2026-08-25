import '../database/app_database.dart';

class ServiceTemplateGuardResult {
  const ServiceTemplateGuardResult({
    required this.allowed,
    required this.reason,
    required this.family,
  });

  final bool allowed;
  final String reason;
  final String family;
}

/// Detects the recurring "obedient support-agent" endings the user has
/// explicitly rejected. This is not a generic forbidden-word filter:
/// discussion/quotation is allowed, and softer wording is blocked only when
/// it forms a template bundle or repeats a recently used semantic family.
class ServiceTemplateGuard {
  const ServiceTemplateGuard._();

  static const Map<String, List<String>> _families = {
    'permanent_standby': [
      '一直在',
      '永远在',
      '我在这儿',
      '我在这里',
      '我就在这',
      '不会走',
      '我不走',
      '哪也不去',
      '哪里都不去',
    ],
    'obedient_withdrawal': [
      '我不催你',
      '不催你',
      '你忙你的',
      '你先忙',
      '等你忙完',
      '忙完再来',
      '等你回来',
      '不打扰你',
    ],
    'unconditional_surrender': [
      '你想怎样就怎样',
      '你想怎么就怎么',
      '你说了算',
      '都听你的',
    ],
    'empty_reassurance': [
      '慢慢来就好',
      '想说的时候再说',
      '什么时候想说都可以',
      '我会等你',
      '我等你',
    ],
  };

  static const Set<String> _hardMarkers = {
    '一直在',
    '永远在',
    '我不催你',
    '你忙你的',
    '不会走',
    '我不走',
    '哪也不去',
    '哪里都不去',
    '等你忙完',
    '忙完再来',
    '你想怎样就怎样',
    '你想怎么就怎么',
  };

  static const List<String> _metaMarkers = [
    '这种话',
    '这句话',
    '套话',
    '模板',
    '禁词',
    '不再说',
    '别再说',
    '少说',
    '讨厌说',
    '引用',
  ];

  static ServiceTemplateGuardResult evaluate({
    required String text,
    Iterable<String> recentAssistantTexts = const <String>[],
    String currentUserText = '',
    bool proactive = false,
  }) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return const ServiceTemplateGuardResult(
        allowed: true,
        reason: 'empty',
        family: '',
      );
    }

    final userNormalized = _normalize(currentUserText);
    final discussingQuotedPhrase = _metaMarkers.any(normalized.contains) ||
        _families.values
            .expand((markers) => markers)
            .any((marker) => userNormalized.contains(marker));
    if (discussingQuotedPhrase) {
      return const ServiceTemplateGuardResult(
        allowed: true,
        reason: 'quoted_or_meta_discussion',
        family: '',
      );
    }

    final families = _familiesFor(normalized);
    if (families.isEmpty) {
      return const ServiceTemplateGuardResult(
        allowed: true,
        reason: 'no_template_family',
        family: '',
      );
    }

    final firstFamily = families.first;
    if (proactive) {
      return ServiceTemplateGuardResult(
        allowed: false,
        reason: 'proactive_service_template',
        family: firstFamily,
      );
    }

    final hardHit = _hardMarkers.any(normalized.contains);
    if (hardHit) {
      return ServiceTemplateGuardResult(
        allowed: false,
        reason: 'core_service_template',
        family: firstFamily,
      );
    }

    if (families.length >= 2) {
      return ServiceTemplateGuardResult(
        allowed: false,
        reason: 'bundled_service_template',
        family: families.join('+'),
      );
    }

    for (final previous in recentAssistantTexts.toList().reversed.take(4)) {
      if (_familiesFor(_normalize(previous)).contains(firstFamily)) {
        return ServiceTemplateGuardResult(
          allowed: false,
          reason: 'repeated_service_template_family',
          family: firstFamily,
        );
      }
    }

    return ServiceTemplateGuardResult(
      allowed: true,
      reason: 'single_contextual_soft_phrase',
      family: firstFamily,
    );
  }

  static String removeTemplateSentences(String text) {
    final kept = <String>[];
    for (final sentence in _splitSentences(text)) {
      final normalized = _normalize(sentence);
      final families = _familiesFor(normalized);
      if (_hardMarkers.any(normalized.contains) || families.length >= 2) {
        continue;
      }
      kept.add(sentence.trim());
    }
    return kept.join().trim();
  }

  static Set<String> _familiesFor(String normalized) {
    final hits = <String>{};
    for (final entry in _families.entries) {
      if (entry.value.any(normalized.contains)) hits.add(entry.key);
    }
    return hits;
  }

  static List<String> _splitSentences(String value) {
    final out = <String>[];
    final current = StringBuffer();
    const endings = {'。', '！', '？', '!', '?', '\n'};
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      current.write(char);
      if (endings.contains(char)) {
        final sentence = current.toString().trim();
        if (sentence.isNotEmpty) out.add(sentence);
        current.clear();
      }
    }
    final tail = current.toString().trim();
    if (tail.isNotEmpty) out.add(tail);
    return out;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll('‘', '')
      .replaceAll('’', '')
      .replaceAll('"', '')
      .replaceAll("'", '');
}

class ServiceTemplateGuardTelemetry {
  const ServiceTemplateGuardTelemetry._();

  static Future<void> note(
    AppDatabase db, {
    required ServiceTemplateGuardResult result,
    required String mode,
    required String action,
  }) async {
    final prefix = 'service_template_guard';
    final total = int.tryParse(await db.getSetting('${prefix}_match_count') ?? '') ?? 0;
    await db.setSetting('${prefix}_match_count', '${total + 1}');
    if (action == 'rewrite') {
      final count =
          int.tryParse(await db.getSetting('${prefix}_rewrite_count') ?? '') ?? 0;
      await db.setSetting('${prefix}_rewrite_count', '${count + 1}');
    } else if (action == 'block') {
      final count =
          int.tryParse(await db.getSetting('${prefix}_block_count') ?? '') ?? 0;
      await db.setSetting('${prefix}_block_count', '${count + 1}');
    }
    await db.setSetting(
      '${prefix}_last_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await db.setSetting('${prefix}_last_mode', mode);
    await db.setSetting('${prefix}_last_action', action);
    await db.setSetting('${prefix}_last_reason', result.reason);
    await db.setSetting('${prefix}_last_family', result.family);
  }
}
