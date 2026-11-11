/// Outer-text targets only. Names and textual identity claims are not IDs.
abstract final class QqMentionTargets {
  static final _id = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_-]{0,127}$');
  static final _legacy = RegExp(r'<@!?([A-Za-z0-9_][A-Za-z0-9_-]{0,127})>');
  static final _xml = RegExp(r'''<qqbot-at-user\s+id\s*=\s*["']([A-Za-z0-9_][A-Za-z0-9_-]{0,127})["']\s*/>''');

  static bool valid(Object? value) => value is String && _id.hasMatch(value) &&
      !const {'all', 'everyone', 'here'}.contains(value.toLowerCase());

  static Set<String> ids(Map entry) => {
    for (final field in ['member_openid', 'id', 'user_openid'])
      if (valid(entry[field])) entry[field] as String,
  };

  static Set<String> inText(String text) {
    final bounded = text.length <= 15000 ? text : text.substring(0, 15000);
    return {
      for (final pattern in [_legacy, _xml])
        for (final match in pattern.allMatches(bounded).take(64))
          if (valid(match[1])) match[1]!,
    };
  }

  /// Removes visible mention syntax from the command text only.
  static String withoutLeadingMentions(String text) {
    var command = text.trimLeft();
    while (true) {
      final match = _legacy.matchAsPrefix(command) ?? _xml.matchAsPrefix(command);
      if (match == null || !valid(match[1])) return command;
      command = command.substring(match.end).trimLeft();
    }
  }

  static bool individual(Map entry) => entry['scope'] == null || entry['scope'] == 'single';
}
