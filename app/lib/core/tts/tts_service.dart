import '../database/app_database.dart';
import 'native_tts_provider.dart';
import 'tts_playback_queue.dart';
import 'tts_provider.dart';
import 'tts_queue_service.dart';
import 'tts_text_processor.dart';

class TtsService implements TtsQueueService {
  TtsService({
    AppDatabase? db,
    TtsProvider? provider,
    TtsTextProcessor? processor,
  })  : db = db ?? AppDatabase.instance,
        provider = provider ?? NativeTtsProvider.instance,
        processor = processor ?? const TtsTextProcessor();

  final AppDatabase db;
  final TtsProvider provider;
  final TtsTextProcessor processor;

  Future<TtsStatus> status() => provider.status();

  Future<TtsStatus> verifyArtifacts() => provider.verifyArtifacts();

  Future<TtsStatus> initialize() async {
    final result = await provider.initialize();
    if (result.initialized) await _applyPlaybackSettings();
    return result;
  }

  Future<TtsStatus> diagnose() async {
    final result = await provider.diagnose();
    if (result.initialized) await _applyPlaybackSettings();
    return result;
  }

  Future<void> _applyPlaybackSettings() async {
    final speed = double.tryParse(await db.getSetting('tts_speed') ?? '') ?? 1.0;
    final volume = double.tryParse(await db.getSetting('tts_volume') ?? '') ?? 1.0;
    await provider.setSpeed(speed);
    await provider.setVolume(volume);
  }

  @override
  Future<String?> prepareText(String visibleText, {bool manual = false}) async {
    if ((await db.getSetting('tts_enabled')) == '0') return null;
    if (!manual && (await db.getSetting('auto_tts')) == '0') return null;

    try {
      final status = await provider.status();
      if (!status.available) return null;
      if (!status.initialized) {
        final initialized = await initialize();
        if (!initialized.initialized) return null;
      } else {
        await _applyPlaybackSettings();
      }
      final replacements = processor.decodeReplacementJson(
        await db.getSetting('tts_replacements_json'),
      );
      final spoken = processor.process(
        visibleText,
        replacements: replacements,
        scope: TtsReadingScope.fromSetting(
          await db.getSetting('tts_reading_scope'),
        ),
      );
      return spoken.isEmpty ? null : spoken;
    } catch (e) {
      await _recordError(e.toString());
      return null;
    }
  }

  @override
  Future<String?> generatePrepared(String spokenText) async {
    if (spokenText.trim().isEmpty) return null;
    try {
      final audio = await provider.generate(spokenText.trim());
      if (audio == null || audio.trim().isEmpty) return null;
      await _recordError('');
      return audio;
    } catch (e) {
      await _recordError(e.toString());
      return null;
    }
  }

  @override
  Future<void> playPrepared(String wavBase64) async {
    if (wavBase64.trim().isEmpty) return;
    await provider.playAudio(wavBase64);
  }

  /// One-shot convenience used by proactive speech. It deliberately routes
  /// through the same A2 scheduler as chat, never through the old serial path.
  Future<bool> speak(String visibleText, {bool manual = false}) async {
    final queue = TtsPlaybackQueue(service: this);
    try {
      await queue.playText(visibleText, manual: manual);
      await queue.waitUntilIdle();
      return true;
    } catch (e) {
      await _recordError(e.toString());
      return false;
    }
  }

  Future<bool> preview(String visibleText) async => speak(visibleText, manual: true);

  Future<void> _recordError(String value) async {
    final text = value.length <= 320 ? value : value.substring(0, 320);
    try {
      await db.setSetting('last_tts_error', text);
    } catch (_) {
      // Voice diagnostics are best-effort. A SQLite/settings error here must
      // never turn optional speech into a chat/proactive failure.
    }
  }

  @override
  Future<void> stop() => provider.stop();
  Future<void> pause() => provider.pause();
  Future<void> resume() => provider.resume();
  Future<void> setSpeed(double value) => provider.setSpeed(value);
  Future<void> setVolume(double value) => provider.setVolume(value);
}
