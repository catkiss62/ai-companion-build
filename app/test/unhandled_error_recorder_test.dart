import 'dart:async';
import 'dart:ui';

import 'package:ai_companion_localfirst/core/diagnostics/unhandled_error_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('hooks preserve error handling and record only redacted bounded metadata', () async {
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    final records = <Map<String, String>>[];
    var forwardedFlutter = 0;
    var forwardedPlatform = 0;
    try {
      FlutterError.onError = (_) { forwardedFlutter++; };
      PlatformDispatcher.instance.onError = (_, _) { forwardedPlatform++; return false; };
      final recorder = UnhandledErrorRecorder(runtime: 'foreground', write: (event) async {
        records.add(event);
      });
      recorder.install();
      final error = StateError('private chat text and api-key-secret');
      final stack = StackTrace.fromString('#0      ChatController.send (package:ai_companion_localfirst/chat.dart:10:2)\n'
          '#1      main (/private/device/user-name/app.dart:2:1)');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      await Future<void>.delayed(Duration.zero);
      expect(PlatformDispatcher.instance.onError!(error, stack), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(forwardedFlutter, 1);
      expect(forwardedPlatform, 1);
      expect(records, hasLength(1)); // same failure is de-duplicated across hooks
      expect(records.single['frame'], 'ChatController.send');
      expect(records.single['stackFp'], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(records.toString(), isNot(contains('private')));
      expect(records.toString(), isNot(contains('api-key-secret')));
      expect(records.toString(), isNot(contains('app.dart')));
    } finally {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
    }
  });

  test('a failing diagnostic channel never recursively throws or floods', () async {
    var writes = 0;
    final recorder = UnhandledErrorRecorder(runtime: 'background', write: (_) async {
      writes++;
      throw StateError('native bridge unavailable');
    });
    for (var i = 0; i < 20; i++) {
      await recorder.record(StateError('ignored'), StackTrace.fromString('frame_$i'), 'platform');
    }
    expect(writes, 8);
  });
}
