import 'dart:typed_data';
import 'playback_intent.dart';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../presentation/chat_visuals.dart';

abstract interface class EmotionSoundPlayer {
  Future<void> play(String wavBase64);
  Future<void> stop();
}

abstract interface class EmotionSoundVolumePlayer {
  void setVolume(double volume);
}

class NativeEmotionSoundPlayer
    implements EmotionSoundPlayer, EmotionSoundVolumePlayer {
  NativeEmotionSoundPlayer._({this.cueLease, this.playbackLease});
  final int? cueLease, playbackLease;
  Future<NativeEmotionSoundPlayer> claimCue({int? parentLease}) async {
    final lease = await _channel.invokeMethod<num>('claimCue', {'playbackLease': parentLease});
    if (lease == null) throw PlatformException(code: 'emotion_claim_failed');
    return NativeEmotionSoundPlayer._(cueLease: lease.toInt(), playbackLease: parentLease);
  }
  static final NativeEmotionSoundPlayer instance = NativeEmotionSoundPlayer._();

  static const MethodChannel _channel =
      MethodChannel('ai_companion/emotion_sound');

  double _volume = 0.15;

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0).toDouble();
  }

  @override
  Future<void> play(String wavBase64) =>
      _channel.invokeMethod<void>('play', {
        'audioData': wavBase64,
        if (cueLease != null) 'cueLease': cueLease,
        if (playbackLease != null) 'playbackLease': playbackLease,
        'volume': _volume,
      });

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop', {if (cueLease != null) 'cueLease': cueLease});
}

/// Plays one short LingChat expression cue on a channel independent from TTS.
///
/// [play] completes when the cue finishes (or fails safely), so the TTS queue
/// can synthesize in parallel while fencing only its first audible sentence.
class EmotionSoundService {
  EmotionSoundService({
    AppDatabase? db,
    EmotionSoundPlayer? player,
    this.assetLoader,
  })  : db = db ?? AppDatabase.instance,
        player = player ?? NativeEmotionSoundPlayer.instance;

  final Future<ByteData> Function(String)? assetLoader;
  final AppDatabase db;
  final EmotionSoundPlayer player;
  int _generation = 0;
  EmotionSoundPlayer? _activePlayer;

  static double normalizedVolume(String? stored) =>
      (double.tryParse(stored ?? '') ?? 0.15).clamp(0.0, 1.0).toDouble();

  Future<bool> play(ChatEmotionVisual emotion, {PlaybackIntent? intent}) async {
    final generation = ++_generation;
    bool valid() => generation == _generation && (intent?.valid ?? true);
    EmotionSoundPlayer owned = player;
    try {
      if (player is NativeEmotionSoundPlayer) {
        final parent = intent == null ? null : await intent.lease;
        if (!valid()) return false;
        owned = await (player as NativeEmotionSoundPlayer).claimCue(parentLease: parent);
        if (!valid()) { await owned.stop(); return false; }
      }
      _activePlayer = owned;
    } catch (_) { return false; }
    final asset = emotion.soundAsset;
    if (asset == null ||
        (await db.getSetting('emotion_sound_enabled')) != '1') {
      return false;
    }
    if (!valid()) return false;
    try {
      final data = await (assetLoader ?? rootBundle.load)(asset);
      if (!valid()) return false;
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final volume =
          normalizedVolume(await db.getSetting('emotion_sound_volume'));
      if (!valid()) return false;
      final configurable = owned is EmotionSoundVolumePlayer
          ? owned as EmotionSoundVolumePlayer
          : null;
      configurable?.setVolume(volume);
      if (!valid()) return false;
      await owned.play(base64Encode(bytes));
      return valid();
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _generation++;
    final owned = _activePlayer;
    _activePlayer = null;
    try {
      if (owned != null) await owned.stop();
      else if (player is! NativeEmotionSoundPlayer) await player.stop();
    } catch (_) {
      // Expression audio is optional and must never block chat cancellation.
    }
  }
}
