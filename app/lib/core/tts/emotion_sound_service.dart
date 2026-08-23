import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../presentation/chat_visuals.dart';
import 'native_tts_provider.dart';
import 'tts_provider.dart';

/// Plays LingChat's short expression cues only when the user explicitly opts
/// in. Auto-TTS wins if both features are enabled so voices never overlap.
class EmotionSoundService {
  EmotionSoundService({
    AppDatabase? db,
    TtsProvider? provider,
  })  : db = db ?? AppDatabase.instance,
        provider = provider ?? NativeTtsProvider.instance;

  final AppDatabase db;
  final TtsProvider provider;

  Future<bool> play(ChatEmotionVisual emotion) async {
    final asset = emotion.soundAsset;
    if (asset == null || (await db.getSetting('emotion_sound_enabled')) != '1') {
      return false;
    }
    if ((await db.getSetting('tts_enabled')) == '1' &&
        (await db.getSetting('auto_tts')) == '1') {
      return false;
    }
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await provider.playAudio(base64Encode(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() => provider.stop();
}
