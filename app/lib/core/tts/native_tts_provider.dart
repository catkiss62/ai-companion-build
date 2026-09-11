import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'tts_provider.dart';
import '../models/chat_language_variant.dart';
import 'tts_voice_profile.dart';

/// Flutter-facing adapter for the local Genie-TTS core with the Jiuhu voice.
/// The Android side owns the shared acoustic runtime and one selected frontend.
class NativeTtsProvider implements TtsProvider {
  NativeTtsProvider._();
  static final NativeTtsProvider instance = NativeTtsProvider._();

  static const MethodChannel _channel = MethodChannel('ai_companion/tts');

  @override
  Future<TtsStatus> status() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('status');
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> verifyArtifacts() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('verifyArtifacts');
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> initialize({
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'initialize',
      {'language': language.key},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> prepareLanguage(ChatLanguage language) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'prepareLanguage',
      {'language': language.key},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> diagnose({
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'diagnose',
      {'language': language.key},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> importChineseRoberta(String path) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'importChineseRoberta',
      {'path': path},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<void> speak(String text) =>
      _channel.invokeMethod<void>('speak', {'text': text});

  @override
  Future<Uint8List?> generate(
    String text, {
    TtsEmotionCue? emotion,
    ChatLanguage language = ChatLanguage.chinese,
    TtsVoiceMode voice = TtsVoiceMode.daily,
  }) =>
      _channel.invokeMethod<Uint8List>('generate', <String, Object?>{
        'text': text,
        'language': language.key,
        'voice': voice.key,
        if (emotion != null) ...emotion.toChannelMap(),
      });

  @override
  Future<void> beginAudioStream() =>
      _channel.invokeMethod<void>('beginAudioStream');

  @override
  Future<void> enqueueAudio(Uint8List wavBytes) =>
      _channel.invokeMethod<void>('enqueueAudio', {'audioData': wavBytes});

  @override
  Future<void> finishAudioStream() =>
      _channel.invokeMethod<void>('finishAudioStream');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _channel.invokeMethod<void>('resume');

  @override
  Future<void> setSpeed(double speed) =>
      _channel.invokeMethod<void>('setSpeed', {'speed': speed});

  @override
  Future<void> setPitch(double pitch) =>
      _channel.invokeMethod<void>('setPitch', {'pitch': pitch});

  @override
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('setVolume', {'volume': volume});

  @override
  Future<void> dispose() async {
    // Android bridge owns the native runtime for the FlutterEngine lifetime.
  }
}
