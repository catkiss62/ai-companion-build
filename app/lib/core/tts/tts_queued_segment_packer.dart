import '../models/chat_language_variant.dart';

class TtsPackedPrefix {
  const TtsPackedPrefix(this.text, this.sourceUnits);

  final String text;
  final int sourceUnits;
}

/// Exact policy port of Genie v0.7.1 DialogueSegmentPacker.
///
/// The first streaming unit bypasses this packer. After it has started
/// synthesis, only complete units already waiting in the queue are combined;
/// there is no timer and no wait for another network delta.
class TtsQueuedSegmentPacker {
  const TtsQueuedSegmentPacker._();

  static TtsPackedPrefix packPrefix(
    List<String> available,
    ChatLanguage language,
  ) {
    if (available.isEmpty) throw ArgumentError('no queued TTS units');
    final target = language == ChatLanguage.english ? 88 : 42;
    final maximum = language == ChatLanguage.english ? 110 : 54;
    final buffer = StringBuffer(available.first.trim());
    var length = available.first.trim().length;
    var used = 1;
    while (used < available.length && length < target) {
      final next = available[used].trim();
      if (next.isEmpty) {
        used++;
        continue;
      }
      final separator = language == ChatLanguage.english && length > 0 ? ' ' : '';
      if (length + separator.length + next.length > maximum) break;
      buffer.write(separator);
      buffer.write(next);
      length += separator.length + next.length;
      used++;
    }
    return TtsPackedPrefix(buffer.toString(), used);
  }
}
