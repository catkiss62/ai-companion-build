import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/tts/emotion_sound_service.dart';
import 'package:ai_companion_localfirst/core/tts/proactive_speech_delivery.dart';
import 'package:ai_companion_localfirst/core/tts/tts_playback_queue.dart';
import 'package:ai_companion_localfirst/core/tts/tts_service.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/tts');
  const emotion = MethodChannel('ai_companion/emotion_sound');
  const system = MethodChannel('ai_companion/system');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppDatabase db;
  final calls = <MethodCall>[], cues = <String>[];
  var lease = 0;
  Completer<void>? generationEntered, generationRelease;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSettingsAtomically({'tts_enabled':'1','auto_tts':'1',
      'tts_reading_scope':'full_text','proactive_tts_policy':'when_overlay_opened',
      'emotion_sound_enabled':'1'});
    calls.clear(); cues.clear(); lease = 0;
    generationEntered = null; generationRelease = null;
    messenger.setMockMethodCallHandler(system, (call) async =>
      call.method == 'runtimeProcessEpoch' ? 'synthetic-389' : null);
    messenger.setMockMethodCallHandler(emotion, (call) async {
      cues.add(call.method); return call.method == 'claimCue' ? 1 : null;
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final a = call.arguments is Map ? call.arguments as Map : const {};
      if (call.method == 'claimPlayback') return ++lease;
      if (call.method == 'stop') return null;
      if (a['lease'] != null && a['lease'] != lease) throw PlatformException(code:'stale');
      if (const {'initialize','prepareLanguage','configureAutoAffinity','status'}.contains(call.method)) {
        return {'available':true,'initialized':true,'autoAffinityEnabled':a['enabled']==true};
      }
      if (call.method == 'generate') {
        if (generationEntered != null && !generationEntered!.isCompleted) {
          generationEntered!.complete(); await generationRelease!.future;
        }
        return Uint8List.fromList([1,2,3]);
      }
      if (const {'beginAudioStream','enqueueAudio','finishAudioStream'}.contains(call.method)) return true;
      return null;
    });
  });
  tearDown(() async {
    if (generationRelease != null && !generationRelease!.isCompleted) generationRelease!.complete();
    await db.closeForTesting();
    for (final c in [channel,emotion,system]) messenger.setMockMethodCallHandler(c,null);
  });
  ChatMessage message(String id, int at, {String role='assistant',bool proactive=false}) => ChatMessage(
    id:id,role:role,content:'合成$id。',createdAt:DateTime.fromMillisecondsSinceEpoch(at),
    isProactive:proactive,emotionKey:'happy');
  Future<void> advance() async {
    await db.insertMessage(message('user',2000,role:'user'));
    await db.insertMessage(message('B',3000));
  }
  ChatController controller({EmotionSoundService? sound}) => ChatController(db:db,
    emotionSoundService:sound??EmotionSoundService(db:db,assetLoader:(_) async=>ByteData(4)),
    externalRecoveryOrchestrator:true);
  List<MethodCall> generated() => calls.where((c)=>c.method=='generate').toList();
  List<MethodCall> enqueued() => calls.where((c)=>c.method=='enqueueAudio').toList();

  test('real chat-open entry never searches past later user or ordinary answer for proactive A',() async {
    final chat=controller(); addTearDown(chat.dispose);
    await db.insertMessage(message('A',1000,proactive:true));
    await db.insertMessage(message('user',2000,role:'user'));
    chat.messages=await db.recentMessages(); await chat.onChatOpened();
    await db.insertMessage(message('B',3000));
    chat.messages=await db.recentMessages(); await chat.onOverlayOpened();
    // A stale App surface also fails the shared SQLite head check.
    chat.messages=[message('A',1000,proactive:true)]; await chat.onChatOpened();
    expect(calls.where((c)=>c.method=='claimPlayback'),isEmpty);
    expect(cues, isNot(contains('play')));
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey),isNot('A'));
  });
  test('current proactive opening still speaks once, including its cue',() async {
    final chat=controller(); addTearDown(chat.dispose);
    await db.insertMessage(message('A',1000,proactive:true));
    chat.messages=await db.recentMessages();
    await chat.onChatOpened(); await chat.onOverlayOpened();
    expect(generated(),hasLength(1)); expect(enqueued(),hasLength(1));
    expect(cues.where((c)=>c=='play'),hasLength(1));
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey),'A');
  });
  test('new ordinary turn while proactive audio synthesizes discards its late PCM',() async {
    await db.setSetting('emotion_sound_enabled','0');
    final chat=controller(); addTearDown(chat.dispose);
    await db.insertMessage(message('A',1000,proactive:true));chat.messages=await db.recentMessages();
    generationEntered=Completer<void>();generationRelease=Completer<void>();
    final playing=chat.onChatOpened();await generationEntered!.future.timeout(const Duration(seconds:5));
    await advance();chat.messages=await db.recentMessages();
    final newer=TtsPlaybackQueue(service:TtsService(db:db));addTearDown(newer.stop);
    await newer.playText('合成B。',ownerId:'B');await newer.waitUntilIdle();
    generationRelease!.complete();await playing.timeout(const Duration(seconds:5));
    expect(enqueued(),hasLength(1));
    expect((enqueued().single.arguments as Map)['lease'],lease);
    expect(chat.ttsPlayback.state.running,false);
    await chat.onOverlayOpened();expect(enqueued(),hasLength(1));
  });
  test('delayed proactive emotion asset and its waiting TTS cannot follow B',() async {
    final entered=Completer<void>(),asset=Completer<ByteData>();
    final chat=controller(sound:EmotionSoundService(db:db,assetLoader:(_) {
      if(!entered.isCompleted)entered.complete();return asset.future;
    }));addTearDown(chat.dispose);
    await db.insertMessage(message('A',1000,proactive:true));chat.messages=await db.recentMessages();
    final playing=chat.onChatOpened();await entered.future.timeout(const Duration(seconds:5));
    await advance();chat.messages=await db.recentMessages();
    asset.complete(ByteData(4));await playing.timeout(const Duration(seconds:5));
    expect(cues,isNot(contains('play')));expect(enqueued(),isEmpty);
    expect(chat.ttsPlayback.state.running,false);
  });
  test('background delivery rechecks head before claiming audio after delayed preparation',() async {
    final a=message('A',1000,proactive:true);await db.insertMessage(a);
    final delivery=ProactiveSpeechDelivery(db),entered=Completer<void>(),release=Completer<void>();
    final playing=delivery.deliver(a,play:() async {
      entered.complete();await release.future;
      return TtsService(db:db).speak(a.content,ownerId:a.id,manual:true,
        canContinue:()=>delivery.canContinue(a));
    });
    await entered.future;await advance();release.complete();await playing.timeout(const Duration(seconds:5));
    expect(calls.where((c)=>c.method=='claimPlayback'),isEmpty);expect(enqueued(),isEmpty);
  });
  test('explicit manual reading can still play a historical message',() async {
    final a=message('A',1000,proactive:true);await db.insertMessage(a);await advance();
    expect(await TtsService(db:db).speak(a.content,ownerId:a.id,manual:true),true);
    expect(enqueued(),hasLength(1));
  });
  test('claimed preparation is invalid after restore epoch changes even if message stays identical',() async {
    final a=message('A',1000,proactive:true);await db.insertMessage(a);
    final delivery=ProactiveSpeechDelivery(db);
    await delivery.deliver(a,play:() async {
      expect(await delivery.canContinue(a),true);
      await db.setSetting('runtime_state_epoch_v1','synthetic-replaced-save');
      expect(await delivery.canContinue(a),false);return false;
    });
  });
}
