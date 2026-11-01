import 'package:ai_companion_localfirst/features/chat/deepseek_calibration_controls.dart';
import 'package:ai_companion_localfirst/widgets/caicai_live2d_stage.dart';
import 'package:ai_companion_localfirst/widgets/caicai_stage_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel=MethodChannel('ai_companion/caicai_live2d');
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel,null);
    CaicaiLive2DService.acceptProfile({'profile':'caicai','profile_generation':0});
    CaicaiLive2DService.editor.value=null;
  });
  testWidgets('DeepSeek exposes its own two pats, local idle previews and freeze commands', (tester) async {
    final calls=<List<Object?>>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:DeepseekCalibrationControls(
      status:const {},busy:false,run:(task)=>task(),preview:(method,[value]) async {calls.add([method,value]);},
    )))));
    for(final label in ['自主待机','狗尾草待机预览','完全静止','摸头','摸头彩蛋预览']) {
      await tester.ensureVisible(find.text(label));await tester.tap(find.text(label));await tester.pump();
    }
    expect(calls,[['previewDeepseekIdle',false],['previewDeepseekIdle',true],['static',true],
      ['deepseekHeadPat',null],['deepseekHeadPatRare',null]]);
    expect(calls.any((c)=>c.first=='headPat' || c.first=='headPatRare'),false);
  });
  testWidgets('busy DeepSeek controls do not submit interaction or idle work', (tester) async {
    var calls=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:DeepseekCalibrationControls(
      status:const {},busy:true,run:(task)=>task(),preview:(method,[value]) async {calls++;},
    )))));
    await tester.tap(find.text('摸头'));await tester.tap(find.text('自主待机'));await tester.pump();
    expect(calls,0);
  });
  for(final save in [true,false]) {
    testWidgets('DeepSeek head-box editing keeps profile ownership and save=$save', (tester) async {
      final calls=<Map>[];
      CaicaiLive2DService.acceptProfile({'profile':'deepseek-avatar','profile_generation':77});
      CaicaiLive2DService.editor.value={'mode':'head'};
      messenger.setMockMethodCallHandler(channel,(call) async {calls.add(call.arguments as Map);return true;});
      await tester.pumpWidget(const MaterialApp(home:Scaffold(body:CaicaiStageEditor(mode:'head',initial:{
        'scale':1.0,'headRect':[.2,.1,.7,.35],
      }))));
      await tester.dragFrom(const Offset(220,160),const Offset(40,20));await tester.pump();
      expect(calls.any((c)=>c['method']=='previewHeadBox'),true);
      for(final c in calls) {
        expect(c['profile'],'deepseek-avatar');expect(c['profile_generation'],77);
      }
      await tester.tap(find.text(save?'确认':'取消'));await tester.pumpAndSettle();
      expect(calls.last['method'],'finishEdit');expect(calls.last['arguments'],save);
      expect(CaicaiLive2DService.editor.value,isNull);
    });
  }
}
