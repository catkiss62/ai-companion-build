import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/agent/commission_session.dart';
import 'package:ai_companion_localfirst/core/agent/work_history_lookup.dart';
import 'package:ai_companion_localfirst/core/agent/work_quiz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('casual roleplay stays in chat and genuine work reads are explicit', () {
    for (final text in ['上班了，进入工作模式','最近做了什么','第二个','工作模式是什么','工作区在哪','比如说你去看工作区？']) {
      expect(WorkHistoryLookup.explicit(text),isFalse,reason:text);
      expect(WorkHistoryLookup.followup(text),isFalse,reason:text);
    }
    expect(WorkHistoryLookup.explicit('你最近在工作模式里替我做了什么'),isTrue);
    expect(WorkHistoryLookup.explicit('找一下上周你给我写的那份人设报告'),isTrue);
    expect(WorkHistoryLookup.followup('把第二段读给我'),isTrue);
    expect(CommissionSession.resumesOrder('继续任务，刚才断网了'),isTrue);
    expect(CommissionSession.omittedActions('继续，但别响铃了'),{'ring'});
  });
  test('named pages are stable, collision safe, and tied to receipts', () async {
    final dir=await Directory.systemTemp.createTemp();
    addTearDown(()=>dir.delete(recursive:true));
    final workspace=CommissionWorkspace(directory:dir);
    final first=await workspace.savePage('元素测验','<p>甲</p>',null);
    expect(first,'作品-元素测验.html');
    expect(await workspace.savePage('元素测验','<p>甲</p>',null),first);
    final second=await workspace.savePage('元素测验','<p>乙</p>',null);
    expect(second,'作品-元素测验（2）.html');
    expect(await workspace.readHtml(first),'<p>甲</p>');
    await expectLater(workspace.readHtml(second,expectedDigest:'wrong'),throwsFormatException);
  });
  test('explicit quiz requests select the supported HTTPS document', () {
    expect(WorkQuiz.requested('做个五题元素测试，发截图'),isNull);
    expect(WorkQuiz.requested('你来答题 https://uwakihantei.com/zh-cn/dere-type/#dere-tool')?.fragment,'dere-tool');
    expect(WorkQuiz.requested('给我挑个测试')?.host,'zodiacgalore.com');
    expect(WorkQuiz.requested('写一份关于元素的报告'),isNull);
    expect(()=>WorkQuiz.requested('请答题 https://unknown.invalid/a'),throwsFormatException);
  });
  test('three stuck actions share one visual recovery and return the actual stop frame', () async {
    final dir=await Directory.systemTemp.createTemp();
    addTearDown(()=>dir.delete(recursive:true));
    const id='269254ed-86bc-4613-bffa-142a78ea5755';
    const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+i1JkAAAAASUVORK5CYII=';
    final state=jsonEncode({'key':'same','question':'Choose','position':'第 1 题','page':'/quiz',
      'controls':[{'id':0,'name':'A','kind':'button'}]});
    var actions=0, images=0, closed=false;
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(CommissionWorkspace.channel,(call) async {
      switch(call.method){
        case 'workPageOpen': case 'workPageRead': return state;
        case 'workPageAct': actions++;return 'ok';
        case 'workPageFrame':return png;
        case 'workQuizClose':closed=true;return null;
        default:throw StateError(call.method);
      }
    });
    addTearDown(()=>messenger.setMockMethodCallHandler(CommissionWorkspace.channel,null));
    final result=await WorkQuiz.run(uri:Uri.parse('https://example.org/quiz'),order:id,id:id,goal:'答题',
      workspace:CommissionWorkspace(directory:dir),cancel:GenerationCancellationToken(),answers:[],
      save:() async{},ask:(_) async=>'{"id":0}',vision:(_) async{images++;return '一个按钮';},progress:(_){});
    expect(actions,3);expect(images,1);expect(closed,isTrue);
    expect(result['questions'],0);expect(result['error'],contains('三次'));
    expect(await File('${dir.path}/${result['screenshot']}').exists(),isTrue);
  });

}
