import 'package:ai_companion_localfirst/features/chat/manual_ds_reply_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cancel and dismiss preserve the current reply; confirmation acts once', (tester) async {
    final reply = Object();
    final confirmed = <Object>[];
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
      child: child!), home: Scaffold(body: Center(child: ManualDsReplyButton(
        replyIdentity: reply, enabled: true, selected: false,
        onConfirmed: (id) async { confirmed.add(id); })))));
    await tester.tap(find.text('使用DS回复'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认回复'), findsOneWidget);
    expect(confirmed, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(confirmed, isEmpty);
    await tester.tap(find.text('使用DS回复'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(confirmed, isEmpty);
    await tester.tap(find.text('使用DS回复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认回复'));
    await tester.pumpAndSettle();
    expect(confirmed, [reply]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final change in ['next_reply', 'finished', 'already_selected', 'removed']) {
    testWidgets('an open confirmation cannot affect $change', (tester) async {
      Object? identity = Object();
      var enabled = true, selected = false, visible = true;
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return visible ? ManualDsReplyButton(replyIdentity: identity,
            enabled: enabled, selected: selected,
            onConfirmed: (_) async { calls++; }) : const SizedBox();
        }))));
      await tester.tap(find.text('使用DS回复'));
      await tester.pumpAndSettle();
      update(() {
        if (change == 'next_reply') identity = Object();
        if (change == 'finished') enabled = false;
        if (change == 'already_selected') selected = true;
        if (change == 'removed') visible = false;
      });
      await tester.pump();
      await tester.tap(find.text('确认回复'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });
  }

  testWidgets('a disabled control keeps its shortened selected label', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ManualDsReplyButton(
      replyIdentity: Object(), enabled: false, selected: true,
      onConfirmed: (_) async { fail('Disabled takeover must not run'); }))));
    expect(find.text('已切换 DS'), findsOneWidget);
    await tester.tap(find.text('已切换 DS'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
