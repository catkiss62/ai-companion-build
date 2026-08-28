import 'dart:convert';

enum ChatSegmentKind {
  action('action'),
  dialogue('dialogue');

  const ChatSegmentKind(this.key);
  final String key;

  static ChatSegmentKind fromKey(String? value) =>
      value == action.key ? action : dialogue;
}

class ChatSegment {
  const ChatSegment({required this.kind, required this.text});

  final ChatSegmentKind kind;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.key,
        'text': text,
      };

  factory ChatSegment.fromJson(Map<String, Object?> json) => ChatSegment(
        kind: ChatSegmentKind.fromKey(json['kind']?.toString()),
        text: json['text']?.toString() ?? '',
      );
}

class ChatSegmentCodec {
  const ChatSegmentCodec._();

  static List<ChatSegment> parseAssistantText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const <ChatSegment>[];

    final result = <ChatSegment>[];
    final lines = normalized.split('\n');
    final quotedLine = RegExp(
      r'^(?:「([\s\S]*)」|“([\s\S]*)”|"([\s\S]*)")$',
    );
    final hasExplicitDialogueLine = lines.any(
      (candidate) => quotedLine.hasMatch(candidate.trim()),
    );
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final quoted = quotedLine.firstMatch(line);
      if (quoted != null) {
        final body =
            (quoted.group(1) ?? quoted.group(2) ?? quoted.group(3) ?? '').trim();
        if (body.isNotEmpty) {
          result.add(ChatSegment(kind: ChatSegmentKind.dialogue, text: body));
        }
        continue;
      }

      // Actions use parenthesized blocks. Mixed legacy lines remain readable:
      // text outside the blocks is dialogue, while the blocks are actions.
      final actions =
          RegExp(r'（[^（）\n]*）|\([^()\n]*\)').allMatches(line).toList();
      if (actions.isNotEmpty) {
        var cursor = 0;
        for (final match in actions) {
          final before = line.substring(cursor, match.start).trim();
          if (before.isNotEmpty) {
            result.add(ChatSegment(kind: ChatSegmentKind.dialogue, text: before));
          }
          final action = line.substring(match.start + 1, match.end - 1).trim();
          if (action.isNotEmpty) {
            result.add(ChatSegment(kind: ChatSegmentKind.action, text: action));
          }
          cursor = match.end;
        }
        final after = line.substring(cursor).trim();
        if (after.isNotEmpty) {
          result.add(ChatSegment(kind: ChatSegmentKind.dialogue, text: after));
        }
        continue;
      }

      // Rule 02 gives mixed ordinary-chat replies an explicit structural
      // boundary: spoken lines are fully quoted and every other standalone
      // line is action/narration. Use that response-wide evidence instead of
      // a fragile action-verb whitelist or the line's position relative to a
      // quote. A fully unquoted informational reply keeps the legacy dialogue
      // fallback so ordinary prose is not restyled as role-play action.
      result.add(ChatSegment(
        kind: hasExplicitDialogueLine
            ? ChatSegmentKind.action
            : ChatSegmentKind.dialogue,
        text: line,
      ));
    }
    return result;
  }

  static String encode(List<ChatSegment> segments) => jsonEncode(
        segments.map((segment) => segment.toJson()).toList(growable: false),
      );

  static List<ChatSegment> decode(String? raw, {String fallbackText = ''}) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final segments = decoded
              .whereType<Map>()
              .map((item) => ChatSegment.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ))
              .where((segment) => segment.text.trim().isNotEmpty)
              .toList(growable: false);
          if (segments.isNotEmpty) {
            // v0.38.15 stored bracketless actions as dialogue when the
            // required blank line appeared before the quoted dialogue.
            // Reparse only when the source now proves that the stored
            // derived segments lost one or more action classifications.
            final reparsed = parseAssistantText(fallbackText);
            final storedActionCount = segments
                .where((segment) => segment.kind == ChatSegmentKind.action)
                .length;
            final reparsedActionCount = reparsed
                .where((segment) => segment.kind == ChatSegmentKind.action)
                .length;
            if (reparsedActionCount > storedActionCount) return reparsed;
            return segments;
          }
        }
      } catch (_) {}
    }
    return parseAssistantText(fallbackText);
  }
}
