import 'dart:async';
import 'package:ai_companion_localfirst/core/storage/portable_companion_storage.dart';
import 'package:ai_companion_localfirst/widgets/caicai_live2d_stage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel=MethodChannel('ai_companion/caicai_live2d');
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  var profile='caicai';
  var epoch=0;
  setUp(() {
    calls=[];profile='caicai';epoch=0;CaicaiLive2DService.activeProfile='caicai';
    messenger.setMockMethodCallHandler(channel,(call) async {
      calls.add(call);
      if(call.method=='selectProfile') {profile=(call.arguments as Map)['profile'] as String;epoch++;}
      if(call.method=='status' || call.method=='selectProfile' || call.method=='portableFinish')
        return {'profile':profile,'profile_generation':epoch,'available':true};
      if(call.method=='portableBegin') return {'token':'lease','live2dDirectory':'/test/models','preferences':<String,Object?>{}};
      return true;
    });
  });
  tearDown(() {messenger.setMockMethodCallHandler(channel,null);CaicaiLive2DService.activeProfile='caicai';});

  test('switch invalidates editor and sends model identity with global commands',() async {
    CaicaiLive2DService.editor.value={'mode':'stage'};
    final revision=CaicaiLive2DService.revision.value;
    await CaicaiLive2DService.selectProfile('deepseek-avatar');
    await CaicaiLive2DService.command('previewParameters',{'AngleX':5});
    expect(CaicaiLive2DService.editor.value,isNull);
    expect(CaicaiLive2DService.revision.value,revision+1);
    final args=calls.last.arguments as Map;
    expect(args['profile'],'deepseek-avatar');expect(args['profile_generation'],1);
    expect(args['arguments'],{'AngleX':5});
  });
  test('A to B to A carries a new generation',() async {
    await CaicaiLive2DService.selectProfile('deepseek-avatar');
    await CaicaiLive2DService.selectProfile('caicai');
    await CaicaiLive2DService.command('parameters');
    expect((calls.last.arguments as Map)['profile_generation'],2);
  });
  test('resource deletion is scoped to the selected family',() async {
    await CaicaiLive2DService.selectProfile('deepseek-avatar');
    await CaicaiLive2DService.clearImportedModels();
    expect(calls.last.method,'clearImportedModels');
    expect((calls.last.arguments as Map)['profile'],'deepseek-avatar');
  });
  test('read-only export finish neither reloads nor adds a status call',() async {
    final backend=AndroidPortableBackend();
    final snapshot=await backend.begin(exporting:true);
    final before=CaicaiLive2DService.revision.value;
    await backend.finish(snapshot,commit:true);
    expect(CaicaiLive2DService.revision.value,before);
    expect(calls.map((c)=>c.method),['portableBegin','portableFinish']);
  });
  test('settings-only restore selecting another model reloads once',() async {
    final backend=AndroidPortableBackend();final snapshot=await backend.begin();
    final before=CaicaiLive2DService.revision.value;
    profile='deepseek-avatar';epoch++;
    await backend.finish(snapshot,commit:true);
    expect(CaicaiLive2DService.activeProfile,'deepseek-avatar');
    expect(CaicaiLive2DService.revision.value,before+1);
  });
  test('same-model finish preserves editor and renderer revision',() async {
    await CaicaiLive2DService.selectProfile('deepseek-avatar');
    CaicaiLive2DService.editor.value={'mode':'stage'};
    final backend=AndroidPortableBackend();final snapshot=await backend.begin();
    final before=CaicaiLive2DService.revision.value;
    await backend.finish(snapshot,commit:true);
    expect(CaicaiLive2DService.revision.value,before);
    expect(CaicaiLive2DService.editor.value,isNotNull);
  });
  test('late status from before a selection cannot overwrite its identity',() async {
    final stale=Completer<Map<String,Object?>>();
    messenger.setMockMethodCallHandler(channel,(call) async {
      if(call.method=='status') return stale.future;
      if(call.method=='selectProfile') return {'profile':'deepseek-avatar','profile_generation':1};
      calls.add(call);return true;
    });
    final pending=CaicaiLive2DService.diagnostics;
    await CaicaiLive2DService.selectProfile('deepseek-avatar');
    stale.complete({'profile':'caicai','profile_generation':0});await pending;
    await CaicaiLive2DService.command('parameters');
    expect(CaicaiLive2DService.activeProfile,'deepseek-avatar');
    expect((calls.last.arguments as Map)['profile_generation'],1);
  });

}
