import 'dart:convert';

/// Stable reference material first, fresh observations last. This only changes
/// serialization; no facts, roles, array order, or live tool results are cached.
class PromptCacheLayout {
  static Object? _canonical(Object? value) {
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static String material(Map<String, Object?> value, List<String> stableKeys) =>
      jsonEncode({
        for (final key in stableKeys) if (value.containsKey(key)) key: _canonical(value[key]),
        for (final entry in value.entries) if (!stableKeys.contains(entry.key))
          entry.key: _canonical(entry.value),
      });
}
