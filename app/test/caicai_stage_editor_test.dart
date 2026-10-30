import 'dart:async';
import 'package:ai_companion_localfirst/widgets/caicai_live2d_stage.dart';
import 'package:ai_companion_localfirst/widgets/caicai_stage_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final save in [false, true]) {
    testWidgets('stage preview finishes transaction with save=$save', (tester) async {
      final calls = <Map>[];
      const channel = MethodChannel('ai_companion/caicai_live2d');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'control') calls.add(call.arguments as Map);
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        CaicaiLive2DService.editor.value = null;
      });
      CaicaiLive2DService.editor.value = {'mode': 'stage'};
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CaicaiStageEditor(
        mode: 'stage', initial: {'scale':1.0,'x':0.0,'y':0.0},
      ))));
      await tester.dragFrom(const Offset(200,200),const Offset(80,40));
      await tester.pump();
      expect(calls.any((call) => call['method']=='previewStage'),isTrue);
      await tester.tap(find.text(save ? '确认' : '取消'));
      await tester.pumpAndSettle();
      expect(calls.last, {'method':'finishEdit','arguments':save,'profile':CaicaiLive2DService.activeProfile,'profile_generation':CaicaiLive2DService.profileGeneration});
      expect(CaicaiLive2DService.editor.value,isNull);
    });
  }
  testWidgets('late finish from old avatar does not close the new editor', (tester) async {
    const channel=MethodChannel('ai_companion/caicai_live2d');
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final pending=Completer<bool>();
    messenger.setMockMethodCallHandler(channel,(call) async {
      if((call.arguments as Map)['method']=='finishEdit') return pending.future;
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel,null);
      CaicaiLive2DService.acceptProfile({'profile':'caicai','profile_generation':0});
      CaicaiLive2DService.editor.value=null;
    });
    CaicaiLive2DService.acceptProfile({'profile':'caicai','profile_generation':10});
    CaicaiLive2DService.editor.value={'mode':'stage'};
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:CaicaiStageEditor(mode:'stage',initial:{}))));
    await tester.tap(find.text('确认'));await tester.pump();
    CaicaiLive2DService.acceptProfile({'profile':'deepseek-avatar','profile_generation':11});
    final next=<String,Object?>{'mode':'stage','state':{'scale':2.0}};
    CaicaiLive2DService.editor.value=next;
    pending.complete(true);await tester.pumpAndSettle();
    expect(identical(CaicaiLive2DService.editor.value,next),isTrue);
  });
  testWidgets('old editor cannot submit cancellation to another avatar', (tester) async {
    const channel=MethodChannel('ai_companion/caicai_live2d');
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls=<MethodCall>[];
    messenger.setMockMethodCallHandler(channel,(call) async {calls.add(call);return true;});
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel,null);
      CaicaiLive2DService.acceptProfile({'profile':'caicai','profile_generation':0});
      CaicaiLive2DService.editor.value=null;
    });
    CaicaiLive2DService.acceptProfile({'profile':'caicai','profile_generation':20});
    CaicaiLive2DService.editor.value={'mode':'stage'};
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:CaicaiStageEditor(mode:'stage',initial:{}))));
    CaicaiLive2DService.acceptProfile({'profile':'deepseek-avatar','profile_generation':21});
    final next=<String,Object?>{'mode':'stage'};CaicaiLive2DService.editor.value=next;
    await tester.tap(find.text('取消'));await tester.pumpAndSettle();
    expect(calls,isEmpty);expect(identical(CaicaiLive2DService.editor.value,next),isTrue);
  });
}
