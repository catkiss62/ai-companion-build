import 'package:ai_companion_localfirst/widgets/caicai_live2d_stage.dart';
import 'package:ai_companion_localfirst/widgets/caicai_stage_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final save in [false, true]) {
    testWidgets('right ear sliders preview only the whole ear and finish with save=$save', (tester) async {
      final calls = <Map>[];
      const channel = MethodChannel('ai_companion/caicai_live2d');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'control') calls.add(call.arguments as Map);
        return true;
      });
      addTearDown(() {messenger.setMockMethodCallHandler(channel,null);CaicaiLive2DService.editor.value=null;});
      await tester.pumpWidget(const MaterialApp(home:Scaffold(body:CaicaiStageEditor(
        mode:'rightEar',initial:{'earX':.1,'earY':-.2,'earRotation':12.0},
      ))));
      expect(find.text('旋转 12.0°'),findsOneWidget);
      await tester.drag(find.byType(Slider).first,const Offset(60,0));
      await tester.pump();
      expect(calls.any((c)=>c['method']=='previewRightEar'),isTrue);
      expect(calls.any((c)=>c['method']=='previewStage'),isFalse);
      await tester.tap(find.text('归零'));await tester.pump();
      expect(calls.last,{'method':'previewRightEar','arguments':{'x':0.0,'y':0.0,'rotation':0.0}});
      await tester.tap(find.text(save?'确认':'取消'));await tester.pumpAndSettle();
      expect(calls.last,{'method':'finishEdit','arguments':save});
      expect(tester.takeException(),isNull);
    });
  }
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
      expect(calls.last, {'method':'finishEdit','arguments':save});
      expect(CaicaiLive2DService.editor.value,isNull);
    });
  }
}
