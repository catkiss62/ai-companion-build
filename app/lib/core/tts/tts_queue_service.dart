import 'dart:typed_data';

import 'tts_provider.dart';
import '../models/chat_language_variant.dart';
import 'tts_voice_profile.dart';

/// Narrow interface used by the A2 speech scheduler so queue/cancel behavior
/// can be tested without Android/MethodChannel or a real database.
abstract interface class TtsQueueService {
  Future<TtsVoiceMode> resolveVoice(TtsEmotionCue? emotion);

  /// Apply the same visible-text-only preprocessing used by normal speech and
  /// ensure the local engine/settings are ready for this session.
  Future<String?> prepareText(
    String visibleText, {
    bool manual = false,
    ChatLanguage language = ChatLanguage.chinese,
  });

  /// Generate one sentence to validated WAV bytes. Generation and playback are kept
  /// separate so later sentences can be prepared while the current one plays.
  Future<Uint8List?> generatePrepared(
    String spokenText, {
    TtsEmotionCue? emotion,
    ChatLanguage language = ChatLanguage.chinese,
    TtsVoiceMode voice = TtsVoiceMode.daily,
  });

  /// Play one already-generated WAV and complete only after AudioTrack drains.
  Future<void> playPrepared(Uint8List wavBytes);

  Future<void> stop();
}
