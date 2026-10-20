import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/caicai_chat_motion.dart';
import 'package:ai_companion_localfirst/core/ai/caicai_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/tts/spoken_text_index.dart';

class _Planner extends CaicaiMotionPlanner {
  int calls = 0;
  String spoken = '';
  Completer<Map<String, Object?>?>? pending;
  @override
  Future<Map<String, Object?>?> plan({required String user, required String reply,
    required String emotion, required Map<String, dynamic> parameters, String spokenText = '',
    GenerationCancellationToken? cancellationToken}) async {
    calls++; spoken = spokenText;
    return pending != null ? pending!.future : result;
  }
  Map<String, Object?> get result => {
    'frames': [{'time': 0, 'duration': .5, 'parameters': {'ParamAngleY2': 10}}],
    'emotion': 'playful',
    'speech': [
      {'start': 0, 'end': 3, 'emotion': 'shy', 'delivery': 'nod'},
      {'start': 3, 'end': 6, 'emotion': '', 'delivery': 'hold'},
    ],
  };
}

class _Harness {
  final planner = _Planner();
  final commands = <(String, Map)>[];
  Map<Object?, Object?> snapshot = {};
  final settings = <String, String>{'tts_reading_scope': 'full_text'};
  late final motion = CaicaiChatMotion(planner: planner,
    pollInterval: const Duration(milliseconds: 3),
    setting: (key) async => settings[key],
    playbackSnapshot: () async => snapshot,
    command: (method, args) async {
      if (method == 'parameters') return jsonEncode({'ParamAngleY2': {'min': -30, 'max': 30}});
      if (method == 'claimMotion') return {'execution_id': 'stage', 'epoch': ++epoch};
      commands.add((method, args is Map ? args : {}));
      return true;
    });
  var epoch = 0;
  Future<void> present({int revision = 0}) => motion.present(id: 'message', user: '你好',
    reply: '前半句，后半句。', emotion: 'normal', revision: revision);
  void audio({int lease = 1, bool audible = true, double position = 1, String? fingerprint}) {
    snapshot = {'lease': lease, 'message_id': 'message', 'phase': 'playing',
      'playing': true, 'audible': audible, 'playhead': 100 + position.toInt(),
      'spoken_language': 'zh', 'spoken_fingerprint': fingerprint ?? SpokenTextIndex.fingerprint('前半句，后半句。'),
      'spoken_position': position};
    motion.playbackChanged(ownerId: 'message', running: true);
  }
  List<Map> get cues => commands.where((c) => c.$1 == 'speechCue').map((c) => c.$2).toList();
}

void main() {
  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));
  test('opening plays during synthesis and speech needs actual matching audio', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    await h.present();
    expect(h.commands.where((c) => c.$1 == 'motionPlan'), hasLength(1));
    await tick(); expect(h.cues, isEmpty);
    h.audio(); await tick();
    expect(h.cues, isNotEmpty); expect(h.cues.first['frames'], isNotEmpty);
    expect(h.cues.first['emotion'], 'shy');
    expect(h.planner.calls, 1);
  });
  test('mute releases only owned speech, resume skips already used accents', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    await h.present(); h.audio(); await tick();
    h.audio(audible: false); await tick();
    expect(h.commands.where((c) => c.$1 == 'stopSpeechMotion'), isNotEmpty);
    h.audio(position: 2); final before = h.cues.length; await tick();
    expect(h.cues.length, greaterThan(before));
    expect(h.cues[before]['frames'], isEmpty);
    expect(h.planner.calls, 1);
  });
  test('new lease replays the cue without purchasing another plan', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    await h.present(); h.audio(); await tick();
    final before = h.cues.length;
    h.audio(lease: 2); await tick();
    expect(h.cues[before]['cue'], '2:0');
    expect(h.cues[before]['frames'], isNotEmpty);
    expect(h.planner.calls, 1);
  });
  test('changed spoken text or another message cannot borrow the plan', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    await h.present(); h.audio(fingerprint: 'wrong'); await tick();
    expect(h.cues, isEmpty);
    h.audio(); h.snapshot['message_id'] = 'older'; await tick();
    expect(h.cues, isEmpty);
  });
  test('stop during planning prevents late opening and speech resurrection', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    h.planner.pending = Completer();
    final pending = h.present(); await tick();
    await h.motion.stop(); final before = h.commands.length;
    h.audio(); h.planner.pending!.complete(h.planner.result);
    await pending; await tick();
    expect(h.commands.length, before);
  });
  test('late plan attaches at audio position instead of replaying its opening', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    h.planner.pending = Completer();
    final pending = h.present(); h.audio(position: 4); await tick();
    h.planner.pending!.complete(h.planner.result); await pending; await tick();
    expect(h.commands.where((c) => c.$1 == 'motionPlan'), isEmpty);
    expect(h.cues.first['cue'], '1:1');
    expect(h.cues.first['frames'], isEmpty);
  });
  test('TTS off preserves immediate plan and omits speech planning context', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    h.settings['auto_tts'] = '0'; await h.present(); h.audio(); await tick();
    expect(h.planner.spoken, ''); expect(h.cues, isEmpty);
    expect(h.commands.where((c) => c.$1 == 'motionPlan'), hasLength(1));
  });
  test('same message source revision can receive a fresh presentation owner', () async {
    final h = _Harness(); addTearDown(h.motion.stop);
    await h.present(); await h.present(); expect(h.planner.calls, 1);
    await h.present(revision: 1); expect(h.planner.calls, 2);
    expect(h.epoch, 2);
  });
}
