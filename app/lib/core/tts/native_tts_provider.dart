import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'tts_provider.dart';

/// Flutter-facing adapter for the local Meju Bert-VITS2/MNN engine.
/// The Android side hides the compatibility runtime/JNI details from Flutter.
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
  Future<TtsStatus> initialize() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('initialize');
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> diagnose() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('diagnose');
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<void> speak(String text) =>
      _channel.invokeMethod<void>('speak', {'text': text});

  @override
  Future<Uint8List?> generate(String text, {TtsEmotionCue? emotion}) =>
      _channel.invokeMethod<Uint8List>('generate', <String, Object?>{
        'text': text,
        if (emotion != null) ...emotion.toChannelMap(),
      });

  @override
  Future<void> playAudio(Uint8List wavBytes) =>
      _channel.invokeMethod<void>('playAudio', {'audioData': wavBytes});

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
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('setVolume', {'volume': volume});

  @override
  Future<void> dispose() async {
    // Android bridge owns the native runtime for the FlutterEngine lifetime.
  }
}
