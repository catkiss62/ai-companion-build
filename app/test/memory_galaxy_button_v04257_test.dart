import 'package:ai_companion_localfirst/features/home/memory_galaxy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'star field pauses off page, in background and with reduced motion',
    (tester) async {
      Widget page({bool visible = true, bool reduceMotion = false}) =>
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: Scaffold(
                body: TickerMode(
                  enabled: visible,
                  child: MemoryGalaxyButton(onPressed: () {}),
                ),
              ),
            ),
          );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(page());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('记忆星谷'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(page(visible: false));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(page());
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(page(reduceMotion: true));
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('记忆星谷'), findsOneWidget);
      await tester.pumpWidget(page());
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
