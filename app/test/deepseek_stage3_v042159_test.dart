import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  test('JEV offers independent full lean and visible head/body in the same one request', () async {
    var calls=0;Map? sent;
    final gateway=JevDecisionGateway(enabledReader:() async=>true,keyReader:() async=>'test',
      clientFactory:()=>MockClient((request) async {calls++;sent=jsonDecode(request.body) as Map;
        return http.Response('{}',503);}));
    final parameters=<String,dynamic>{for(final c in DeepseekMotionPlanner.channels.values)
      for(final v in c.values) for(final id in v.keys) id:{'min':-30,'max':30}};
    await DeepseekMotionPlanner(gateway:gateway).plan(user:'逗逗我',reply:'凑近瞧瞧你',
      emotion:'playful',spokenText:'让我看看。',parameters:parameters);
    expect(calls,1);
    final q=sent!['questions'] as Map;
    expect(q.keys,containsAll(['f0_head','f0_body','f0_lean','f3_lean','speech0_delivery']));
    expect((q['f1_lean']['criteria'] as Map).keys,contains('贴近屏幕'));
    final plan=DeepseekMotionPlanner.buildPlan({'f0_head':'右转','f1_body':'左侧身',
      'f1_lean':'贴近屏幕','f2_lean':'贴近屏幕','f3_lean':'贴近屏幕'},parameters);
    final frames=plan['frames'] as List;
    expect(frames[0]['parameters']['AngleX'],25);
    expect(frames[1]['parameters']['PositionX'],-12);
    expect(frames[1]['parameters']['LeanInput'],-30);
    expect(frames[2]['parameters']['LeanInput'],-30);
    expect(frames[3]['parameters']['LeanInput'],0);
    final speech=DeepseekMotionPlanner.speechFrames('lean',parameters);
    expect((speech.first['parameters'] as Map)['LeanInput'],-30);
    expect((speech.last['parameters'] as Map)['LeanInput'],0);
  });
  testWidgets('lean preview returns full authored target and final standing pose', (tester) async {
    Object? preview;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:DeepseekCalibrationControls(
      status:const {},busy:false,run:(task)=>task(),preview:(method,[value]) async {preview=value;},
    )))));
    await tester.tap(find.text('前倾贴近预览'));await tester.pump();
    final frames=(preview as Map)['frames'] as List;
    expect(frames.first['parameters']['LeanInput'],-30);expect(frames.last['parameters']['LeanInput'],0);
  });
  for(final saved in [null,0.0,-1.0,1.0]) {
    testWidgets('mouth style has only two choices and preserves saved arc: $saved', (tester) async {
      final calls=<MethodCall>[];
      CaicaiLive2DService.acceptProfile({'profile':'deepseek-avatar','profile_generation':77});
      messenger.setMockMethodCallHandler(channel,(call) async {calls.add(call);return true;});
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:DeepseekCalibrationControls(
        status:{'deepseek_appearance':{if(saved!=null) 'MouthPressLipOpen':saved}},busy:false,
        run:(task)=>task(),preview:(method,[value]) async {},
      )))));
      await tester.ensureVisible(find.text('嘴型风格'));await tester.pump();
      expect(find.text(saved==1.0?'弧线嘴':'猫嘴'),findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<double>));await tester.pumpAndSettle();
      expect(find.text('默认'),findsNothing);expect(find.text('弧线嘴'),findsWidgets);
      await tester.tap(find.text('弧线嘴').last);await tester.pumpAndSettle();
      final args=calls.last.arguments as Map;
      expect(args['method'],'setDeepseekAppearance');expect(args['arguments'],{'MouthPressLipOpen':1.0});
      expect(args['profile'],'deepseek-avatar');
    });
  }
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
