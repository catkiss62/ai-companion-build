import 'package:ai_companion_localfirst/features/phone/simulated_phone_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reference unlock requires the full 100dp upward drag', (
    tester,
  ) async {
    var unlocks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReferenceUnlockControl(onUnlock: () => unlocks++),
          ),
        ),
      ),
    );

    await tester.drag(find.text('↑'), const Offset(0, -72));
    await tester.pump();
    expect(unlocks, 0);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.text('↑'), const Offset(0, -100));
    await tester.pump();
    expect(unlocks, 1);
  });

  testWidgets('lock screen has no extra home indicator or tap unlock', (
    tester,
  ) async {
    var unlocks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          now: DateTime(2026, 8, 26, 17, 28),
          snapshot: null,
          onUnlock: () => unlocks++,
        ),
      ),
    );

    expect(find.text('上滑解锁'), findsOneWidget);
    expect(find.byType(HomeIndicator), findsNothing);
    await tester.tap(find.text('↑'));
    await tester.pump();
    expect(unlocks, 0);
  });
}
