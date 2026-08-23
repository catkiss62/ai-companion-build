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
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      final corner = RegExp(r'^「([\s\S]*)」$').firstMatch(line);
      if (corner != null) {
        final body = (corner.group(1) ?? '').trim();
        if (body.isNotEmpty) {
          result.add(ChatSegment(kind: ChatSegmentKind.dialogue, text: body));
        }
        continue;
      }

      // Compatibility for older messages: parenthesized spans were actions,
      // while the surrounding text was dialogue. New output never needs the
      // parentheses and is handled by the line-oriented branch below.
      final legacy = RegExp(r'（[^（）\n]*）|\([^()\n]*\)').allMatches(line).toList();
      if (legacy.isNotEmpty) {
        var cursor = 0;
        for (final match in legacy) {
          final before = line.substring(cursor, match.start).trim();
          if (before.isNotEmpty) {
            result.add(ChatSegment(kind: ChatSegmentKind.dialogue, text: before));
          }
          final action = line
              .substring(match.start + 1, match.end - 1)
              .trim();
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

      // Under the new contract, an unquoted standalone line is an action.
      // If a provider ignores the contract and returns one ordinary paragraph,
      // keep it usable as dialogue instead of mislabelling a long answer.
      final looksLikeAction =
          RegExp(r'^(轻轻|悄悄|抬|垂|眨|偏|歪|抱|靠|凑|缩|晃|摇|点|皱|抿|笑|叹|耳鳍|尾巴)').hasMatch(line) ||
          (normalized.contains('「') &&
              normalized.contains('\n') &&
              line.length <= 80);
      result.add(ChatSegment(
        kind: looksLikeAction ? ChatSegmentKind.action : ChatSegmentKind.dialogue,
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
          if (segments.isNotEmpty) return segments;
        }
      } catch (_) {}
    }
    return parseAssistantText(fallbackText);
  }
}
