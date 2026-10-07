import 'package:ai_companion_localfirst/widgets/room_depth_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('background paints between events, settles and stops off-page',
      (tester) async {
    await tester.runAsync(() async {
      const channel = MethodChannel('ai_companion/room_tilt');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      Widget page({bool active = true}) => MaterialApp(home: SizedBox(
        width: 300, height: 500,
        child: RoomDepthBackground(
          asset: 'assets/lingchat/background/day.webp', enabled: true, active: active),
      ));
      final paint = find.descendant(of: find.byType(RoomDepthBackground),
          matching: find.byType(CustomPaint));
      await tester.pumpWidget(page());
      for (var attempt = 0; attempt < 100 && paint.evaluate().isEmpty; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(paint, findsOneWidget);
      await tester.pumpAndSettle();
      var frames = 0;
      tester.widget<CustomPaint>(paint).painter!.addListener(() => frames++);
      Future<void> event(double x, double y, {bool reset = false}) async {
        await messenger.handlePlatformMessage(channel.name,
            const StandardMethodCodec().encodeSuccessEnvelope(
              {'x': x, 'y': y, 'available': true, 'reset': reset}), null);
      }
      await event(.8, .4);
      await tester.pump();
      for (var frame = 0; frame < 4; frame++) {
        final previous = frames;
        await tester.pump(const Duration(milliseconds: 16));
        expect(frames, greaterThan(previous));
      }
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      var stopped = frames;
      await tester.pump(const Duration(milliseconds: 100));
      expect(frames, stopped);
      expect(tester.binding.transientCallbackCount, 0);

      await event(-.8, .2);await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();stopped = frames;
      await tester.pump(const Duration(milliseconds: 64));
      expect(frames, stopped);
      expect(tester.binding.transientCallbackCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await event(1, 1);await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await event(0, 0, reset: true);await tester.pump();stopped = frames;
      await tester.pump(const Duration(milliseconds: 64));
      expect(frames, stopped);
      expect(tester.binding.transientCallbackCount, 0);

      await event(1, 1);await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(page(active: false));stopped = frames;
      await tester.pump(const Duration(milliseconds: 64));
      expect(frames, stopped);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(page());
      await event(1, 1);await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
