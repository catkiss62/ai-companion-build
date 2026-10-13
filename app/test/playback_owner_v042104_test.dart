import 'dart:async';
import 'dart:typed_data';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/tts/native_tts_provider.dart';
import 'package:ai_companion_localfirst/core/tts/tts_service.dart';
import 'package:ai_companion_localfirst/core/tts/tts_playback_queue.dart';
import 'package:ai_companion_localfirst/core/tts/emotion_sound_service.dart';
import 'package:ai_companion_localfirst/core/presentation/chat_visuals.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  var current = 0;
  final calls = <MethodCall>[];
  const channel = MethodChannel('ai_companion/tts');
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting('tts_enabled', '1');
    current = 0; calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments is Map ? call.arguments as Map : const {};
      if (call.method == 'claimPlayback') return ++current;
      if (call.method == 'stop') return null;
      if (args['lease'] != null && args['lease'] != current) throw PlatformException(code: 'stale');
      if (const {'status','initialize','prepareLanguage','configureAutoAffinity'}.contains(call.method)) {
        return {'available': true, 'initialized': true, 'engine': 'test', 'autoAffinityEnabled': args['enabled'] == true};
      }
      if (call.method == 'generate') return Uint8List.fromList([1,2,3]);
      if (const {'beginAudioStream','enqueueAudio','finishAudioStream'}.contains(call.method)) return true;
      return null;
    });
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  test('cancelled preparation cannot create speech after a newer intent', () async {
    final queue = TtsPlaybackQueue(service: TtsService(db: db, provider: NativeTtsProvider.instance));
    final old = queue.createIntent(ownerId: 'old', formForPlayback: true);
    await old.service;
    await queue.stop();
    final newer = queue.createIntent(ownerId: 'new', formForPlayback: false);
    await queue.playText('这是一句新的回复。', manual: true, ownerId: 'new', intent: newer);
    await queue.waitUntilIdle().timeout(const Duration(seconds: 5));
    await queue.playText('迟到的翻译。', intent: old);
    final generated = calls.where((c) => c.method == 'generate');
    expect(generated, isNotEmpty);
    expect(generated.every((c) => (c.arguments as Map)['lease'] == current), isTrue);
    expect(calls.where((c) => c.method == 'stop').every((c) => (c.arguments as Map).containsKey('lease')), isTrue);
    expect(queue.playedAny, isTrue);
    await queue.stop();
  });
  test('new reply form stays fixed across all preparation units', () async {
    final queue = TtsPlaybackQueue(service: TtsService(db: db, provider: NativeTtsProvider.instance));
    await queue.playText('第一句。第二句。', manual: true, formForPlayback: true);
    await queue.waitUntilIdle().timeout(const Duration(seconds: 5));
    expect(calls.where((c) => c.method == 'setPitch'), isNotEmpty);
    expect(calls.where((c) => c.method == 'setPitch').every((c) => (c.arguments as Map)['pitch'] == 1.0), isTrue);
    await queue.stop();
  });
  test('stop while emotion asset loads prevents a delayed play command', () async {
    final gate = Completer<ByteData>();
    final entered = Completer<void>();
    const emotionChannel = MethodChannel('ai_companion/emotion_sound');
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(emotionChannel, (call) async {
      methods.add(call.method);
      return call.method == 'claimCue' ? 1 : null;
    });
    await db.setSetting('emotion_sound_enabled', '1');
    final sound = EmotionSoundService(db: db, assetLoader: (_) { entered.complete(); return gate.future; });
    final playing = sound.play(ChatVisualResolver.resolveEmotionKey('happy'));
    try {
      await entered.future.timeout(const Duration(seconds: 5));
      await sound.stop(); gate.complete(ByteData(4));
      expect(await playing.timeout(const Duration(seconds: 5)), isFalse);
      expect(methods, isNot(contains('play')));
    } finally {
      if (!gate.isCompleted) gate.complete(ByteData(4));
      await playing;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(emotionChannel, null);
    }
  });
}
