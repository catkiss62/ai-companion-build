import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/agent/commission_session.dart';
import 'package:ai_companion_localfirst/core/agent/work_history_lookup.dart';
import 'package:ai_companion_localfirst/core/agent/work_quiz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('casual roleplay stays in chat and genuine work reads are explicit', () {
    for (final text in ['上班了，进入工作模式','最近做了什么','第二个','比如说你去看工作区？']) {
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
    expect(WorkQuiz.requested('做个五题元素测试，发截图')?.toString(),WorkQuiz.example);
    expect(WorkQuiz.requested('写一份关于元素的报告'),isNull);
    expect(()=>WorkQuiz.requested('请答题 https://unknown.invalid/a'),throwsFormatException);
  });
}
