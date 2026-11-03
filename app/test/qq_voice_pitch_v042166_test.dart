import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_playback_tuning.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_failure.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_voice.dart';
import 'qq_voice_v042146_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_companion/tts');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final selected in [-4.0, 0.0, 1.0, 4.0]) {
    test('QQ bakes saved slider $selected into ordinary-form file without changing model voice', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'claimVoiceExport') return 31;
        if (call.method == 'generateVoiceExport') return fixture.wav();
        if (call.method == 'tuneVoiceExport') return fixture.wav(samples: 80);
        return null;
      });
      final service = QqVoiceService();
      try {
        final output = await service.generate(const QqVoiceChoice('zh', '你好。', voice: 'gentle'),
          selectedPitchSemitones: selected, current: () async => true);
        final request = calls.singleWhere((c) => c.method == 'tuneVoiceExport').arguments as Map;
        expect(request['pitch'], TtsPlaybackTuning.pitchRatioForForm(selected, qForm: false));
        expect(request['export_id'], 31);
        expect((request['wav'] as Uint8List).length, 244);
        expect(output.length, 204); // Upload the transformed file, not the original.
        expect((calls.singleWhere((c) => c.method == 'generateVoiceExport').arguments as Map)['voice'], 'gentle');
        expect(calls.map((c) => c.method), ['claimVoiceExport', 'generateVoiceExport', 'tuneVoiceExport', 'endVoiceExport']);
        expect(calls.last.arguments, {'export_id': 31, 'cancel': false});
      } finally { service.close(); }
    });
  }

  test('default setting exports one semitone below the selected reference voice', () async {
    double? pitch;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'claimVoiceExport') return 32;
      if (call.method == 'generateVoiceExport') return fixture.wav();
      if (call.method == 'tuneVoiceExport') { pitch = (call.arguments as Map)['pitch'] as double; return fixture.wav(); }
      return null;
    });
    final service = QqVoiceService();
    try {
      await service.generate(const QqVoiceChoice('en', 'Hello.'), current: () async => true);
      expect(pitch, closeTo(0.9438743127, 0.00000001));
    } finally { service.close(); }
  });

  test('a native preemption during tuning never publishes raw audio or stops App playback', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'claimVoiceExport') return 33;
      if (call.method == 'generateVoiceExport') return fixture.wav();
      if (call.method == 'tuneVoiceExport') throw PlatformException(code: 'tts_voice_export_failed', message: 'voice_export_preempted');
      return null;
    });
    final service = QqVoiceService();
    try {
      await expectLater(service.generate(const QqVoiceChoice('ja', 'こんにちは。'), current: () async => true),
        throwsA(isA<QqOperationFailure>().having((e) => e.code, 'code', 'voice_preempted')));
      expect(calls.last.arguments, {'export_id': 33, 'cancel': true});
      expect(calls.any((c) => c.method == 'setPitch' || c.method == 'stop' || c.method == 'claimPlayback'), isFalse);
    } finally { service.close(); }
  });

  test('cancellation while tuning rejects a late successful result', () async {
    final pending = Completer<Uint8List>();
    final entered = Completer<void>();
    final calls = <MethodCall>[];
    var current = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'claimVoiceExport') return 34;
      if (call.method == 'generateVoiceExport') return fixture.wav();
      if (call.method == 'tuneVoiceExport') { entered.complete(); return pending.future; }
      return null;
    });
    final service = QqVoiceService();
    try {
      final result = service.generate(const QqVoiceChoice('en', 'Hello.'), current: () async => current);
      await entered.future;
      current = false;
      pending.complete(fixture.wav());
      await expectLater(result, throwsA(isA<QqOperationFailure>()));
      expect(calls.last.arguments, {'export_id': 34, 'cancel': true});
    } finally { service.close(); }
  });

  test('missing or malformed tuned audio is never treated as successful speech', () async {
    for (final malformed in [null, Uint8List(45)]) {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'claimVoiceExport') return 35;
        if (call.method == 'generateVoiceExport') return fixture.wav();
        if (call.method == 'tuneVoiceExport') return malformed;
        return null;
      });
      final service = QqVoiceService();
      try {
        await expectLater(service.generate(const QqVoiceChoice('zh', '你好。'), current: () async => true),
          throwsA(isA<QqOperationFailure>()));
        expect(calls.last.arguments, {'export_id': 35, 'cancel': true});
      } finally { service.close(); }
    }
  });
}
