/// Machine-only expression metadata, selected by the same final writer.
class StickerReplyChoice {
  const StickerReplyChoice(this.mode, this.id);
  final String mode;
  final String id;
  bool get stickerOnly => mode == 'only';
  static const none = StickerReplyChoice('none', '');
  static final _tag = RegExp(r'<sticker_choice>\s*(none|with_text:s[1-8]|only:s[1-8])\s*</sticker_choice>');

  static StickerReplyChoice parse(String raw) {
    final matches = _tag.allMatches(raw).toList();
    if (matches.length != 1) return none;
    final value = matches.single.group(1)!;
    if (value == 'none') return none;
    final parts = value.split(':');
    return StickerReplyChoice(parts[0], parts[1]);
  }

  static String visible(String raw) {
    var value = raw.replaceAll(RegExp(r'<\s*sticker_choice\b[^>]*>[\s\S]*?<\s*/\s*sticker_choice\s*>', caseSensitive: false), '');
    // Truncated metadata is never released to bubbles, history or TTS.
    value = value.replaceAll(RegExp(r'<\s*sticker_choice\b[\s\S]*$', caseSensitive: false), '');
    value = value.replaceAll(RegExp(r'<\s*/\s*sticker_choice\s*>', caseSensitive: false), '');
    final partial = RegExp(r'<(?:s(?:t(?:i(?:c(?:k(?:e(?:r(?:_(?:c(?:h(?:o(?:i(?:c(?:e)?)?)?)?)?)?)?)?)?)?)?)?)?)?$');
    return value.replaceAll(partial, '');
  }
}
