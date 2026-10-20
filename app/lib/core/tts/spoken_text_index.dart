import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Shared with SpeechPlaybackTimeline on Android. Punctuation and formatting
/// do not consume speech positions. This never changes text sent to TTS.
class SpokenTextIndex {
  static String normalize(String value) => value
      .replaceAll(RegExp(r'[^a-zA-Z0-9\u3400-\u9FFF\u3040-\u30FF]'), '')
      .toLowerCase();
  static String fingerprint(String value) => sha256.convert(utf8.encode(normalize(value))).toString();
}
