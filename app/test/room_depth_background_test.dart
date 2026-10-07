import 'package:ai_companion_localfirst/widgets/room_depth_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('saved strength tolerates corrupt settings', () {
    expect(RoomDepthBackground.parseStrength(null), .55);
    expect(RoomDepthBackground.parseStrength('NaN'), .55);
    expect(RoomDepthBackground.parseStrength('Infinity'), .55);
    expect(RoomDepthBackground.parseStrength('-2'), .2);
    expect(RoomDepthBackground.parseStrength('5'), 1);
    expect(RoomDepthBackground.parseStrength('.65'), .65);
  });
  testWidgets('sensor follows switch, tab, app lifecycle and disposal', (tester) async {
    const channel = MethodChannel('ai_companion/room_tilt');
    final methods = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async { methods.add(call.method); return null; });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Widget page({bool enabled = true, bool active = true}) => MaterialApp(home:
      SizedBox(width: 300, height: 500, child: RoomDepthBackground(
        asset: 'assets/lingchat/background/day.webp', enabled: enabled, active: active)));
    await tester.pumpWidget(page(enabled: false));
    expect(methods, isEmpty);
    await tester.pumpWidget(page());
    await tester.pump();
    expect(methods, ['listen']);
    await tester.pumpWidget(page(active: false));
    await tester.pump();
    expect(methods, ['listen', 'cancel']);
    await tester.pumpWidget(page());
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(methods, ['listen', 'cancel', 'listen', 'cancel']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(methods.last, 'listen');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(methods.last, 'cancel');
  });
}
