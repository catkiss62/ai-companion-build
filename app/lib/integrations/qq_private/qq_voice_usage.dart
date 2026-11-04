import 'dart:convert';

/// Confirmed QQ voice selections only. No transcript, audio, names or IDs.
abstract final class QqVoiceUsage {
  static const key = 'qq_voice_usage_v1';
  static const voices = {'daily', 'gentle', 'lively', 'cute'};
  static List<Map<String, Object?>> decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is List) return [for (final row in value.whereType<Map>().take(64))
        if (row['seq'] is int && row['at'] is int && voices.contains(row['voice']) &&
            const {'zh', 'ja', 'en'}.contains(row['language']))
          {for (final k in ['seq', 'at', 'voice', 'language']) k: row[k]}];
    } catch (_) {}
    return [];
  }
  static String record(String raw, {required int seq, required int at,
    required String voice, required String language}) {
    if (!voices.contains(voice) || !const {'zh', 'ja', 'en'}.contains(language)) return raw;
    return jsonEncode([{'seq': seq, 'at': at, 'voice': voice, 'language': language},
      ...decode(raw).where((r) => r['seq'] != seq)].take(64).toList());
  }
}
