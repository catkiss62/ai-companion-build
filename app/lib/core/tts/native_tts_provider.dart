import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'tts_provider.dart';
import '../models/chat_language_variant.dart';
import 'tts_voice_profile.dart';

/// Flutter-facing adapter for the local Genie-TTS core with the Jiuhu voice.
/// The Android side owns the shared acoustic runtime and one selected frontend.
class NativeTtsProvider implements TtsProvider {
  NativeTtsProvider._({this.playbackLease});
  final int? playbackLease;
  static final NativeTtsProvider instance = NativeTtsProvider._();

  static const MethodChannel _channel = MethodChannel('ai_companion/tts');

  Future<NativeTtsProvider> claimPlayback({String? ownerId}) async {
    final lease = await _channel.invokeMethod<num>('claimPlayback', {'message_id': ownerId ?? ''});
    if (lease == null) throw PlatformException(code: 'tts_claim_failed');
    return NativeTtsProvider._(playbackLease: lease.toInt());
  }
  Future<Map<Object?, Object?>> playbackSnapshot() async =>
      await _channel.invokeMapMethod<Object?, Object?>('playbackSnapshot') ?? const {};
  Map<String, Object?> _arguments(Object? value) => {
    if (value is Map) ...value.cast<String, Object?>(),
    if (playbackLease != null) 'lease': playbackLease,
  };
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    final raw = await _channel.invokeMethod<dynamic>(method, _arguments(arguments));
    if (const {'beginAudioStream','enqueueAudio','finishAudioStream'}.contains(method)) {
      if (playbackLease != null && raw != true) throw PlatformException(code: 'tts_playback_not_accepted', message: method);
      return null;
    }
    return raw as T?;
  }
  Future<Map<K, V>?> _invokeMap<K,V>(String method, [Object? arguments]) =>
      _channel.invokeMapMethod<K,V>(method, _arguments(arguments));

  /// A cheap packaged-resource probe that never starts the isolated engine.
  Future<TtsStatus> localStatus() async => TtsStatus.fromMap(
        await _invokeMap<Object?, Object?>('localStatus') ?? const {},
      );

  @override
  Future<TtsStatus> status() async {
    final raw = await _invokeMap<Object?, Object?>('status');
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> verifyArtifacts() async {
    final raw = await _invokeMap<Object?, Object?>('verifyArtifacts');
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> initialize({
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final raw = await _invokeMap<Object?, Object?>(
      'initialize',
      {'language': language.key},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> prepareLanguage(ChatLanguage language) async {
    final raw = await _invokeMap<Object?, Object?>(
      'prepareLanguage',
      {'language': language.key},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> configureAutoAffinity(bool enabled) async {
    final raw = await _invokeMap<Object?, Object?>(
      'configureAutoAffinity',
      {'enabled': enabled},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> diagnose({
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final raw = await _invokeMap<Object?, Object?>(
      'diagnose',
      {'language': language.key},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<TtsStatus> importChineseRoberta(String path) async {
    final raw = await _invokeMap<Object?, Object?>(
      'importChineseRoberta',
      {'path': path},
    );
    return TtsStatus.fromMap(raw ?? const {});
  }

  @override
  Future<void> speak(String text) =>
      _invoke<void>('speak', {'text': text});

  @override
  Future<Uint8List?> generate(
    String text, {
    TtsEmotionCue? emotion,
    ChatLanguage language = ChatLanguage.chinese,
    TtsVoiceMode voice = TtsVoiceMode.daily,
    int segmentIndex = -1,
  }) =>
      _invoke<Uint8List>('generate', <String, Object?>{
        'text': text,
        'language': language.key,
        'voice': voice.key,
        'segmentIndex': segmentIndex,
        if (emotion != null) ...emotion.toChannelMap(),
      });

  @override
  Future<void> beginAudioStream() =>
      _invoke<void>('beginAudioStream');

  @override
  Future<void> enqueueAudio(
    Uint8List wavBytes, {
    double speedMultiplier = 1.0,
  }) =>
      _invoke<void>('enqueueAudio', {
        'audioData': wavBytes,
        'speedMultiplier': speedMultiplier,
      });

  @override
  Future<void> finishAudioStream() =>
      _invoke<void>('finishAudioStream');

  @override
  Future<void> stop() => _invoke<void>('stop');

  @override
  Future<void> pause() => _invoke<void>('pause');

  @override
  Future<void> resume() => _invoke<void>('resume');

  @override
  Future<void> setSpeed(double speed) =>
      _invoke<void>('setSpeed', {'speed': speed});

  @override
  Future<void> setPitch(double pitch) =>
      _invoke<void>('setPitch', {'pitch': pitch});

  @override
  Future<void> setVolume(double volume) =>
      _invoke<void>('setVolume', {'volume': volume});

  @override
  Future<void> dispose() async {
    // Android bridge owns the native runtime for the FlutterEngine lifetime.
  }
}
