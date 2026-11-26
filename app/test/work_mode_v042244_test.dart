import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/workspace_archive.dart';
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
  test('workspace backup round-trips more than 32 MiB of valid files', () async {
    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final original = CommissionWorkspace(directory: await Directory('${dir.path}/original').create());
    final restored = CommissionWorkspace(directory: await Directory('${dir.path}/restored').create());
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(paths, (_) async => dir.path);
    messenger.setMockMethodCallHandler(CommissionWorkspace.channel, (call) async {
      final zip = File('${dir.path}/copy.zip');
      if (call.method == 'saveCollectedStickerZip') {
        await File(call.arguments['sourcePath'] as String).copy(zip.path);
        return {'verified':true};
      }
      if (call.method == 'openPlainBackup') return {'filePath':zip.path};
      throw StateError(call.method);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(paths,null);
      messenger.setMockMethodCallHandler(CommissionWorkspace.channel,null);
    });
    final text = 'a' * CommissionWorkspace.maxBytes;
    for (var i = 0; i < 129; i++) {
      await original.write('报告-$i.md', text);
    }
    expect(await WorkspaceArchive.export(original), isTrue);
    expect(await WorkspaceArchive.import(restored), contains('129'));
    expect(await restored.list(), await original.list());
    expect(await restored.read('报告-128.md'), text);
  });

  test('quiz count is independent of screenshot delivery and dated work uses local calendar boundaries', () {
    expect(WorkQuiz.answerLimit('把题答完，最后只要截图'), isNull);
    expect(WorkQuiz.answerLimit('只做两道题，最后只要截图'), 2);
    expect(WorkQuiz.answerLimit('不要答，只截图'), 0);
    expect(WorkQuiz.answerLimit('不用答完，做两道题'), 2);
    final now = DateTime(2027, 1, 1, 7);
    expect(WorkHistoryLookup.dateRange('前天', now), (start: DateTime(2026,12,30), end: DateTime(2026,12,31)));
    expect(WorkHistoryLookup.dateRange('这周', now), (start: DateTime(2026,12,28), end: DateTime(2027,1,4)));
    expect(WorkHistoryLookup.dateRange('上个月', now), (start: DateTime(2026,12), end: DateTime(2027,1)));
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
        case 'workPageAct':
          expect(call.arguments['id'],id);expect(call.arguments['control'],0);
          actions++;return 'ok';
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

  test('partial answers, repeated respondent perspective and user handoff on a 35-question site survive a close failure', () async {
    final dir=await Directory.systemTemp.createTemp();
    addTearDown(()=>dir.delete(recursive:true));
    final workspace=CommissionWorkspace(directory:dir);
    const id='269254ed-86bc-4613-bffa-142a78ea5755';
    const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+i1JkAAAAASUVORK5CYII=';
    var answered=0, captures=0, closed=0;
    final decisionPrompts=<String>[];
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(CommissionWorkspace.channel,(call) async {
      switch(call.method){
        case 'workPageOpen': answered=0;
          continue read;
        read: case 'workPageRead':
          return jsonEncode({'key':'q$answered','position':'第 ${answered+1} / 35 题',
            'question':'题目 ${answered+1}','controls':[{'name':'比较同意','kind':'button'}]});
        case 'workPageAct': answered++;return 'ok';
        case 'workPageFrame': captures++;return png;
        case 'workQuizClose': closed++;throw PlatformException(code:'cleanup');
        default:throw StateError(call.method);
      }
    });
    addTearDown(()=>messenger.setMockMethodCallHandler(CommissionWorkspace.channel,null));
    Future<Map<String,Object?>> run(String goal,String model,{required int expected}) async {
      final choices=<Map>[];
      final result=await WorkQuiz.run(uri:Uri.parse('https://example.org/quiz'),order:id,id:id,goal:goal,
        workspace:workspace,cancel:GenerationCancellationToken(),answers:choices,save:() async{},
        ask:(messages) async {
          decisionPrompts.add(messages.first['content'] as String);
          return model;
        },vision:(_) async=>'可读',progress:(_){},
        onPhoto:(receipt) async {
          expect(await WorkQuiz.image(workspace,receipt['screenshot'] as String,receipt['digest'] as String),isNotEmpty);
          expect(answered,expected);
        });
      expect(result.containsKey('error'),isFalse);
      expect(choices.length,expected);
      return result;
    }
    final first=await run('你做两道做个测试（只需要做两道），然后顺便在测试页面随便截个屏做个测试','{"id":0}',expected:2);
    expect(first['questions'],2);
    expect(first['position'],'第 3 / 35 题');
    expect((first['answers'] as List).map((r)=>r['choice']),['比较同意','比较同意']);
    expect(first['screenshot'],isNotNull);
    expect(await WorkQuiz.photosAvailable(workspace,first),isTrue);
    await workspace.remove(first['screenshot'] as String);
    expect(await WorkQuiz.photosAvailable(workspace,first),isFalse);
    final next=await run('看看题目的形式，告诉我就可以了','{"finish":"已看到题型","capture":true}',expected:0);
    expect(next['summary'],'已看到题型');
    decisionPrompts.clear();
    final seven=await run('你给我做这个测试，答七题然后截图','{"id":0}',expected:7);
    expect(seven['questions'],7);
    expect(seven['position'],'第 8 / 35 题');
    expect(decisionPrompts,hasLength(7));
    for(final prompt in decisionPrompts){
      expect(prompt,contains('你是受测者小鲸鱼'));
      expect(prompt,contains('想象自己身处其中'));
    }
    decisionPrompts.clear();
    final handoff=await run('给我挑个测试让我自己答','{"id":0}',expected:0);
    expect(handoff['forUser'],isTrue);
    expect(decisionPrompts,isEmpty);
    expect(closed,4);
    expect(captures,3);
  });

  test('thread merges preserve siblings, older imports, and concurrent saves', () async {
    final dir=await Directory.systemTemp.createTemp();
    addTearDown(()=>dir.delete(recursive:true));
    final ws=CommissionWorkspace(directory:dir);
    String id(int i)=>'00000000-0000-0000-0000-${i.toString().padLeft(12,"0")}';
    final thread=id(1), name='会话-${id(1)}.json';
    Map<String,dynamic> turn(int i)=>{'threadId':thread,'id':id(i),'goal':'问题$i','state':'completed'};
    await ws.write('任务-$thread.json',jsonEncode(turn(1)));
    await Future.wait([ws.mergeTurns(name,[turn(1),turn(2)]),ws.mergeTurns(name,[turn(3)])]);
    await ws.mergeTurns(name,[{...turn(2),'goal':'旧的备份'},turn(4)],keepExisting:true);
    expect(await ws.list(),hasLength(2));
    final rows=await ws.conversation('任务-${id(2)}.json');
    expect(rows.map((r)=>r['goal']),['问题1','问题2','问题3','问题4']);
    await ws.remove(name);
    expect((await ws.conversation('任务-$thread.json')).length,1);
  });

}
