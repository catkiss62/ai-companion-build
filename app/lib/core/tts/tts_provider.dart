import '../emotion/emotion_contract.dart';

class TtsEmotionCue {
  const TtsEmotionCue({
    required this.key,
    required this.label,
    required this.confidence,
    required this.source,
  });

  final String key;
  final String label;
  final double confidence;
  final String source;

  String get minimaxEmotion => EmotionCatalog.minimaxEmotionForKey(key);

  Map<String, Object?> toChannelMap() => <String, Object?>{
        'emotion_key': key,
        'emotion_label': label,
        'emotion_confidence': confidence,
        'emotion_source': source,
        'minimax_emotion': minimaxEmotion,
      };
}

class TtsStatus {
  const TtsStatus({
    required this.available,
    required this.initialized,
    required this.engine,
    this.detail = '',
    this.integrity = 'unchecked',
    this.artifactCount = 0,
    this.goldenReference = '',
    this.diagnosticOk = false,
    this.diagnosticStage = '',
    this.diagnosticTrace = const [],
    this.wavBytes = 0,
  });

  final bool available;
  final bool initialized;
  final String engine;
  final String detail;
  final String integrity;
  final int artifactCount;
  final String goldenReference;
  final bool diagnosticOk;
  final String diagnosticStage;
  final List<String> diagnosticTrace;
  final int wavBytes;

  bool get integrityVerified => integrity == 'verified';
  bool get integrityFailed => integrity == 'failed';

  factory TtsStatus.fromMap(Map<Object?, Object?> map) => TtsStatus(
        available: map['available'] == true,
        initialized: map['initialized'] == true,
        engine: map['engine'] as String? ?? 'unknown',
        detail: map['detail'] as String? ?? '',
        integrity: map['integrity'] as String? ?? 'unchecked',
        artifactCount: (map['artifactCount'] as num?)?.toInt() ?? 0,
        goldenReference: map['goldenReference'] as String? ?? '',
        diagnosticOk: map['diagnosticOk'] == true,
        diagnosticStage: map['diagnosticStage'] as String? ?? '',
        diagnosticTrace: (map['diagnosticTrace'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        wavBytes: (map['wavBytes'] as num?)?.toInt() ?? 0,
      );
}

abstract class TtsProvider {
  Future<TtsStatus> status();
  Future<TtsStatus> verifyArtifacts();
  Future<TtsStatus> initialize();
  Future<TtsStatus> diagnose();

  /// Legacy one-shot compatibility path. Normal companion speech uses
  /// generate()+playAudio() so inference can run ahead of playback like A2.
  Future<void> speak(String text);
  Future<String?> generate(String text, {TtsEmotionCue? emotion});
  Future<void> playAudio(String wavBase64);

  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
