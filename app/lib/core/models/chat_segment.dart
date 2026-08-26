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

  /// Spoken dialogue is a presentation-native part of the authoritative body:
  /// corner quotes are canonical, with Chinese/ASCII double quotes retained
  /// only for historical compatibility. No action inference is involved.
  static List<String> quotedDialogueParts(String text) => RegExp(
        r'「([^」\n]*(?:」|$))|“([^”\n]*(?:”|$))|"([^"\n]*(?:"|$))',
      )
          .allMatches(text)
          .map((match) =>
              (match.group(1) ?? match.group(2) ?? match.group(3) ?? '')
                  .replaceFirst(RegExp(r'[」”"]$'), '')
                  .trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

  static List<ChatSegment> parseAssistantText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const <ChatSegment>[];

    final result = <ChatSegment>[];
    final lines = normalized.split('\n');
    final quotedLine = RegExp(
      r'^(?:「([\s\S]*)」|“([\s\S]*)”|"([\s\S]*)")$',
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

      // Compatibility for v0.37.1's short-lived unparenthesized action format.
      // Ordinary prose remains dialogue.
      var nextContentIndex = index + 1;
      while (nextContentIndex < lines.length &&
          lines[nextContentIndex].trim().isEmpty) {
        nextContentIndex++;
      }
      final nextContentIsDialogue = nextContentIndex < lines.length &&
          quotedLine.hasMatch(lines[nextContentIndex].trim());
      final looksLikeLegacyAction =
          RegExp(r'^(轻轻|悄悄|抬|垂|眨|偏|歪|抱|靠|凑|缩|晃|摇|点|皱|抿|笑|叹|耳鳍|尾巴)').hasMatch(line) &&
          (normalized.contains('「') ||
              normalized.contains('“') ||
              normalized.contains('"')) &&
          normalized.contains('\n') &&
          line.length <= 80;
      result.add(ChatSegment(
        kind: nextContentIsDialogue || looksLikeLegacyAction
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
