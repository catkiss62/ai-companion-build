import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('per-turn reminder locks Chinese and separates normal from calm', () {
    final reminder = PromptBuilder.visibleChineseGenerationReminder();
    expect(reminder, contains('绝对语言约束'));
    expect(reminder, contains('自然简体中文'));
    expect(reminder, contains('reasoning_content 必须非空'));
    expect(reminder, contains('客户端不会编造补写'));
    expect(reminder, contains('<emotion>标签</emotion>'));
    expect(reminder, contains('没有清晰情绪色彩时用“正常”'));
    expect(reminder, contains('“平静”只用于明确安静'));
    expect(reminder, contains('普通聊天台词边界 · 输出前最后检查'));
    expect(reminder, contains('普通聊天最终正文只写真正说出口的话'));
    expect(reminder, contains('不写动作、神态、语气说明、镜头、环境或旁白'));
    expect(reminder, contains('一至三个口语句'));
    expect(reminder, contains('毒舌、冷淡、调皮、腹黑和不耐烦不准自动改写成可爱'));
    expect(reminder, contains('许可—安抚—承诺链'));
    expect(reminder, isNot(contains('顿了顿，又小小声补了一句。')));
    expect(reminder, isNot(contains('结构示意')));
    expect(reminder, isNot(contains('[确有必要时的动作段]')));
    expect(reminder, isNot(contains('「……再摸一会儿也行。」')));
    expect(reminder, contains('最终正文与可见思考提及现实恋人时使用“你”'));
    expect(reminder, contains('不得写成“他、用户、玩家、男方或男人”'));
    expect(reminder, contains('只写真正说出口的话'));
    expect(reminder, isNot(contains('普通聊天正文的人称与可见 reasoning 分开')));
    expect(reminder, isNot(contains('禁止用“我”“她”')));
    expect(reminder, isNot(contains('只用第二人称“你”')));
    expect(reminder, isNot(contains('<system-reminder>')));
  });

  test('runtime identity does not prime third-person user narration', () {
    expect(PromptBuilder.identityPrompt, contains('用户是成年男性'));
    expect(PromptBuilder.identityPrompt, contains('你和用户都是成年人'));
    expect(PromptBuilder.identityPrompt, isNot(contains('他是成年男性')));
    expect(PromptBuilder.identityPrompt, isNot(contains('你和他都是成年人')));
  });

  test('proactive reminder preserves WAIT without inventing a user turn', () {
    final reminder = PromptBuilder.visibleChineseGenerationReminder(
      proactive: true,
    );
    expect(reminder, contains('只输出 WAIT'));
    expect(reminder, isNot(contains('用户刚刚')));
  });

  test('action-expression reminder has removable A/B branches', () {
    final enabled = PromptBuilder.visibleChineseGenerationReminder(
      ordinaryActionExperimentActive: true,
    );
    final disabled = PromptBuilder.visibleChineseGenerationReminder(
      ordinaryActionExperimentActive: false,
    );

    expect(enabled, contains('当前动作神态消融实验已启用'));
    expect(enabled, contains('允许零或一段'));
    expect(enabled, contains('不写动作—对白—动作夹心'));
    expect(disabled, contains('当前动作神态消融实验未启用或内容为空'));
    expect(disabled, contains('不写动作、神态、语气说明、镜头、环境或旁白'));
  });

  test('learning capability truth appears only for relevant conversation', () {
    final relevant = PromptBuilder.personalityLearningCapabilityContract(
      latestUserText: '我已经给你做好学习和成长系统了',
      recent: const <ChatMessage>[],
      mode: PromptGenerationMode.userTurn,
    );
    expect(relevant, contains('OBSERVATION ONLY'));
    expect(relevant, contains('Phase 2/3 尚未开启'));
    expect(relevant, contains('不得说“我已经学会了'));

    final ordinary = PromptBuilder.personalityLearningCapabilityContract(
      latestUserText: '今天晚饭吃什么？',
      recent: const <ChatMessage>[],
      mode: PromptGenerationMode.userTurn,
    );
    expect(ordinary, isEmpty);
  });
}
