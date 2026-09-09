import 'dart:convert';

import 'chat_segment.dart';

enum ChatLanguage {
  chinese('zh', '中'),
  japanese('ja', '日'),
  english('en', 'EN');

  const ChatLanguage(this.key, this.label);

  final String key;
  final String label;

  static ChatLanguage? tryParse(String? value) {
    for (final language in values) {
      if (language.key == value) return language;
    }
    return null;
  }
}

class ChatLanguageVariant {
  const ChatLanguageVariant({
    required this.messageId,
    required this.language,
    required this.content,
    required this.segments,
  });

  final String messageId;
  final ChatLanguage language;
  final String content;
  final List<ChatSegment> segments;

  Map<String, Object?> toDb() => <String, Object?>{
        'message_id': messageId,
        'language': language.key,
        'content': content,
        'segments_json': ChatSegmentCodec.encode(segments),
      };

  factory ChatLanguageVariant.fromDb(Map<String, Object?> row) {
    final language = ChatLanguage.tryParse(row['language'] as String?);
    if (language == null || language == ChatLanguage.chinese) {
      throw const FormatException('invalid_foreign_message_language');
    }
    final content = row['content'] as String? ?? '';
    return ChatLanguageVariant(
      messageId: row['message_id'] as String,
      language: language,
      content: content,
      segments: ChatSegmentCodec.decode(
        row['segments_json'] as String?,
        fallbackText: content,
      ),
    );
  }
}

class MultilingualReply {
  const MultilingualReply({
    required this.chineseContent,
    required this.chineseSegments,
    required this.foreignVariants,
  });

  final String chineseContent;
  final List<ChatSegment> chineseSegments;
  final Map<ChatLanguage, ChatLanguageVariant> foreignVariants;
}

/// Parses the provider-only multilingual envelope. The tags and JSON never
/// enter persisted message text, history prompts, memory, search, or TTS.
class MultilingualReplyCodec {
  const MultilingualReplyCodec._();

  static const startTag = '<multilingual_reply>';
  static const endTag = '</multilingual_reply>';

  static MultilingualReply? tryParse(
    String raw, {
    required String messageId,
  }) {
    final start = raw.indexOf(startTag);
    if (start < 0) return null;
    if (raw.substring(0, start).trim().isNotEmpty) return null;
    final end = raw.indexOf(endTag, start + startTag.length);
    if (end < 0) return null;
    final trailing = raw.substring(end + endTag.length).trim();
    if (trailing.isNotEmpty) return null;
    final payload = raw.substring(start + startTag.length, end).trim();
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final items = decoded['segments'];
      if (items is! List || items.isEmpty || items.length > 80) return null;
      final zh = <ChatSegment>[];
      final ja = <ChatSegment>[];
      final en = <ChatSegment>[];
      for (final item in items) {
        if (item is! Map) return null;
        final kindValue = item['kind']?.toString();
        if (kindValue != ChatSegmentKind.action.key &&
            kindValue != ChatSegmentKind.dialogue.key) {
          return null;
        }
        final kind = ChatSegmentKind.fromKey(kindValue);
        final zhText = _clean(item['zh']);
        final jaText = _clean(item['ja']);
        final enText = _clean(item['en']);
        if (zhText.isEmpty) return null;
        zh.add(ChatSegment(kind: kind, text: zhText));
        if (jaText.isNotEmpty) ja.add(ChatSegment(kind: kind, text: jaText));
        if (enText.isNotEmpty) en.add(ChatSegment(kind: kind, text: enText));
      }
      // A foreign version is valid only when every semantic segment exists.
      // Partial languages are discarded atomically instead of drifting out of
      // alignment with the authoritative Chinese action/dialogue structure.
      final variants = <ChatLanguage, ChatLanguageVariant>{};
      if (ja.length == zh.length) {
        variants[ChatLanguage.japanese] = ChatLanguageVariant(
          messageId: messageId,
          language: ChatLanguage.japanese,
          content: ChatSegmentCodec.displayText(ja),
          segments: List<ChatSegment>.unmodifiable(ja),
        );
      }
      if (en.length == zh.length) {
        variants[ChatLanguage.english] = ChatLanguageVariant(
          messageId: messageId,
          language: ChatLanguage.english,
          content: ChatSegmentCodec.displayText(en),
          segments: List<ChatSegment>.unmodifiable(en),
        );
      }
      return MultilingualReply(
        chineseContent: ChatSegmentCodec.displayText(zh),
        chineseSegments: List<ChatSegment>.unmodifiable(zh),
        foreignVariants: Map<ChatLanguage, ChatLanguageVariant>.unmodifiable(
          variants,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Multilingual streams stay hidden until one complete, validated Chinese
  /// projection exists. This prevents machine tags or foreign text from
  /// leaking into the bubble and streaming TTS.
  static String streamingChinese(String raw, {required String messageId}) =>
      tryParse(raw, messageId: messageId)?.chineseContent ?? '';

  static String _clean(Object? value) => value
      ?.toString()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
      .trim() ??
      '';
}
