import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../presentation/chat_visuals.dart';

abstract interface class EmotionSoundPlayer {
  Future<void> play(String wavBase64);
  Future<void> stop();
}

class NativeEmotionSoundPlayer implements EmotionSoundPlayer {
  NativeEmotionSoundPlayer._();
  static final NativeEmotionSoundPlayer instance = NativeEmotionSoundPlayer._();

  static const MethodChannel _channel =
      MethodChannel('ai_companion/emotion_sound');

  @override
  Future<void> play(String wavBase64) =>
      _channel.invokeMethod<void>('play', {'audioData': wavBase64});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}

/// Plays one short LingChat expression cue on a channel independent from TTS.
///
/// [play] completes when the cue finishes (or fails safely), so the TTS queue
/// can synthesize in parallel while fencing only its first audible sentence.
class EmotionSoundService {
  EmotionSoundService({
    AppDatabase? db,
    EmotionSoundPlayer? player,
  })  : db = db ?? AppDatabase.instance,
        player = player ?? NativeEmotionSoundPlayer.instance;

  final AppDatabase db;
  final EmotionSoundPlayer player;

  Future<bool> play(ChatEmotionVisual emotion) async {
    final asset = emotion.soundAsset;
    if (asset == null ||
        (await db.getSetting('emotion_sound_enabled')) != '1') {
      return false;
    }
    try {
      final data = await rootBundle.load(asset);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await player.play(base64Encode(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await player.stop();
    } catch (_) {
      // Expression audio is optional and must never block chat cancellation.
    }
  }
}
