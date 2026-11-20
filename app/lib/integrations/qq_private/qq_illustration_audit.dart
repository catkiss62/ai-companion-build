import 'dart:convert';

/// Twenty attempts, booleans/stage codes only; never prompts, URLs or credentials.
abstract final class QqIllustrationAudit {
  static const key = 'qq_illustration_decisions_v1';
  static const stages = {'eligibility', 'choice', 'generated', 'sent'};
  static const fields = {'group', 'presence', 'enabled', 'busy', 'cancelled', 'configured', 'eligible',
    'requested', 'skipped', 'selected', 'voice', 'echo', 'sketch', 'accepted'};
  static List<Map<String, dynamic>> decode(String raw) {
    try {
      final rows = jsonDecode(raw);
      if (rows is List) return rows.whereType<Map>().where((r) => r['at'] is int && stages.contains(r['stage']))
          .take(20).map((r) => <String, dynamic>{
            'at': r['at'], 'stage': r['stage'],
            if (r['operation'] is String) 'operation': r['operation'],
            for (final key in fields) if (r[key] is bool) key: r[key],
          }).toList();
    } catch (_) {}
    return [];
  }
  static String record(String raw, String operation, String stage, int at, Map<String, bool> values) {
    if (!stages.contains(stage)) return raw;
    final rows = decode(raw);
    final old = rows.where((r) => r['operation'] == operation).firstOrNull ?? <String, dynamic>{};
    return jsonEncode([{
      ...old, 'operation': operation, 'at': at, 'stage': stage,
      for (final key in fields) if (values[key] != null) key: values[key],
    }, ...rows.where((r) => r['operation'] != operation)].take(20).toList());
  }
  static List<Map<String, dynamic>> diagnostics(String raw) => [
    for (final row in decode(raw)) {...row}..remove('operation')];
}
