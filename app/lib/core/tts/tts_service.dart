import 'dart:typed_data';

import '../database/app_database.dart';
import '../models/chat_language_variant.dart';
import 'native_tts_provider.dart';
import 'tts_playback_queue.dart';
import 'tts_playback_tuning.dart';
import 'tts_provider.dart';
import 'tts_queue_service.dart';
import 'tts_text_processor.dart';
import 'tts_voice_profile.dart';

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

  @override
  Future<TtsVoiceMode> resolveVoice(TtsEmotionCue? emotion) async {
    final configured = TtsVoiceMode.fromSetting(
      await db.getSetting('tts_voice_mode'),
    );
    final resolved = TtsVoiceProfilePolicy.resolve(
      configured,
      emotionKey: emotion?.key ?? '',
      confidence: emotion?.confidence ?? 0,
    );
    try {
      await db.setSetting(
        'last_tts_resolved_voice',
        '${configured.key}|${resolved.key}|${emotion?.key ?? ''}|${(emotion?.confidence ?? 0).toStringAsFixed(2)}',
      );
    } catch (_) {
      // Diagnostics are best-effort and must never block optional speech.
    }
    return resolved;
  }

  Future<TtsStatus> status() => provider.status();

  Future<TtsStatus> verifyArtifacts() => provider.verifyArtifacts();

  Future<TtsStatus> initialize({
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final result = await provider.initialize(language: language);
    if (result.initialized) await _applyPlaybackSettings();
    return result;
  }

  Future<TtsStatus> diagnose({
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final result = await provider.diagnose(language: language);
    if (result.initialized) await _applyPlaybackSettings();
    return result;
  }

  Future<TtsStatus> importChineseRoberta(String path) =>
      provider.importChineseRoberta(path);

  Future<void> _applyPlaybackSettings() async {
    final speed = TtsPlaybackTuning.speedFromSetting(
      await db.getSetting('tts_speed'),
    );
    final volume = TtsPlaybackTuning.volumeFromSetting(
      await db.getSetting('tts_volume'),
    );
    final pitchSemitones = TtsPlaybackTuning.pitchSemitonesFromSetting(
      await db.getSetting('tts_pitch_semitones'),
    );
    final pitch = TtsPlaybackTuning.pitchRatioForSemitones(
      pitchSemitones,
    );
    await provider.setSpeed(speed);
    await provider.setPitch(pitch);
    await provider.setVolume(volume);
  }

  @override
  Future<String?> prepareText(
    String visibleText, {
    bool manual = false,
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    if ((await db.getSetting('tts_enabled')) == '0') return null;
    if (!manual && (await db.getSetting('auto_tts')) == '0') return null;

    try {
      final status = await provider.status();
      if (!status.available) return null;
      if (!status.initialized) {
        final initialized = await initialize(language: language);
        if (!initialized.initialized) {
          await _recordError(
            initialized.detail.isEmpty
                ? 'Genie TTS 前端初始化失败（${language.key}）'
                : initialized.detail,
          );
          return null;
        }
      } else {
        final prepared = await provider.prepareLanguage(language);
        if (!prepared.initialized) {
          await _recordError(
            prepared.detail.isEmpty
                ? 'Genie TTS 前端切换失败（${language.key}）'
                : prepared.detail,
          );
          return null;
        }
        await _applyPlaybackSettings();
      }
      final replacements = processor.decodeReplacementJson(
        await db.getSetting('tts_replacements_json'),
      );
      final spoken = processor.process(
        visibleText,
        language: language,
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
  Future<Uint8List?> generatePrepared(
    String spokenText, {
    TtsEmotionCue? emotion,
    ChatLanguage language = ChatLanguage.chinese,
    TtsVoiceMode voice = TtsVoiceMode.daily,
  }) async {
    if (spokenText.trim().isEmpty) return null;
    try {
      final audio = await provider.generate(
        spokenText.trim(),
        emotion: emotion,
        language: language,
        voice: voice,
      );
      if (audio == null || audio.isEmpty) return null;
      await _recordError('');
      return audio;
    } catch (e) {
      await _recordError(e.toString());
      return null;
    }
  }

  @override
  Future<void> beginPlayback() => provider.beginAudioStream();

  @override
  Future<void> enqueuePlayback(Uint8List wavBytes) async {
    if (wavBytes.isEmpty) return;
    await provider.enqueueAudio(wavBytes);
  }

  @override
  Future<void> finishPlayback() => provider.finishAudioStream();

  /// One-shot convenience used by proactive speech. It deliberately routes
  /// through the same A2 scheduler as chat, never through the old serial path.
  Future<bool> speak(
    String visibleText, {
    bool manual = false,
    Future<void>? leadIn,
    TtsEmotionCue? emotion,
    String? ownerId,
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final queue = TtsPlaybackQueue(service: this);
    try {
      await queue.playText(
        visibleText,
        manual: manual,
        leadIn: leadIn,
        emotion: emotion,
        ownerId: ownerId,
        language: language,
      );
      await queue.waitUntilIdle();
      return queue.playedAny;
    } catch (e) {
      await _recordError(e.toString());
      return false;
    }
  }

  Future<bool> preview(
    String visibleText, {
    ChatLanguage language = ChatLanguage.chinese,
  }) async =>
      speak(visibleText, manual: true, language: language);

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
  Future<void> setPitch(double value) => provider.setPitch(value);
  Future<void> setVolume(double value) => provider.setVolume(value);
}
