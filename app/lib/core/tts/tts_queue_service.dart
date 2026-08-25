import 'tts_provider.dart';

/// Narrow interface used by the A2 speech scheduler so queue/cancel behavior
/// can be tested without Android/MethodChannel or a real database.
abstract interface class TtsQueueService {
  /// Apply the same visible-text-only preprocessing used by normal speech and
  /// ensure the local engine/settings are ready for this session.
  Future<String?> prepareText(String visibleText, {bool manual = false});

  /// Generate one sentence to WAV Base64. Generation and playback are kept
  /// separate so later sentences can be prepared while the current one plays.
  Future<String?> generatePrepared(
    String spokenText, {
    TtsEmotionCue? emotion,
  });

  /// Play one already-generated WAV and complete only after AudioTrack drains.
  Future<void> playPrepared(String wavBase64);

  Future<void> stop();
}
