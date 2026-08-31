import 'package:ai_companion_localfirst/widgets/active_trial_capsule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trial capsule combines names in a fully rounded surface',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActiveTrialCapsule(
            labels: ['清冷内敛', '史莱姆'],
          ),
        ),
      ),
    );

    expect(find.text('清冷内敛 · 史莱姆'), findsOneWidget);
    final capsuleContainer = find
        .ancestor(
          of: find.text('清冷内敛 · 史莱姆'),
          matching: find.byType(Container),
        )
        .first;
    final shape = tester.widget<Container>(capsuleContainer).decoration
        as ShapeDecoration;
    expect(shape.shape, isA<StadiumBorder>());
  });

  test('active trial labels include ordinary and special trials only', () {
    expect(
      activeTrialCapsuleLabels(personalityBaseKey: 'forthright'),
      ['直爽泼辣'],
    );
    expect(
      activeTrialCapsuleLabels(
        personalityBaseKey: 'neutral',
        specialStyleKey: 'yandere',
      ),
      ['自然状态', '病娇'],
    );
    expect(activeTrialCapsuleLabels(), isEmpty);
    expect(
      activeTrialCapsuleLabels(personalityBaseKey: 'unknown'),
      isEmpty,
    );
  });

  testWidgets('empty trial capsule takes no visual space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ActiveTrialCapsule(labels: [])),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(Container), findsNothing);
  });
}
