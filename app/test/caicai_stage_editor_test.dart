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
      expect(calls.last, {'method':'finishEdit','arguments':save});
      expect(CaicaiLive2DService.editor.value,isNull);
    });
  }
}
