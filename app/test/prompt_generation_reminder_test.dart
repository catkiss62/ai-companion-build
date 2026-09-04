import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('per-turn reminder locks Chinese and separates normal from calm', () {
    final reminder = PromptBuilder.visibleChineseGenerationReminder();
    expect(reminder, contains('自然简体中文'));
    expect(reminder, contains('没打算说出口的心里话'));
    expect(reminder, contains('允许片段、跳念、改口或没想完'));
    expect(reminder, contains('所以我应该怎样回复'));
    expect(reminder, contains('<emotion>标签</emotion>'));
    expect(reminder, contains('没有清晰情绪色彩时用“正常”'));
    expect(reminder, contains('“平静”只用于明确安静'));
    expect(reminder, isNot(contains('普通聊天只写真正说出口的话')));
    expect(reminder, isNot(contains('不要机械复述、逐点覆盖、总结升华')));
    expect(reminder, isNot(contains('顿了顿，又小小声补了一句。')));
    expect(reminder, isNot(contains('结构示意')));
    expect(reminder, isNot(contains('[确有必要时的动作段]')));
    expect(reminder, isNot(contains('「……再摸一会儿也行。」')));
    expect(reminder, contains('用户是成年男性'));
    expect(reminder, contains('不要把用户写成第三人称“她”或“他”'));
    expect(reminder, contains('偶发口误不会被系统强制中断'));
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
    expect(reminder, contains('最终正文只允许真正说出口的「对白」'));
    expect(reminder, contains('不要输出无括号旁白、私下心声或裸露自然语言'));
    expect(reminder, isNot(contains('用户刚刚')));
  });

  test('proactive action reminder permits only marked action and dialogue', () {
    final reminder = PromptBuilder.visibleChineseGenerationReminder(
      proactive: true,
      ordinaryActionExperimentActive: true,
    );
    expect(reminder, contains('最终正文只允许两种可见段'));
    expect(reminder, contains('必须独占一行并写成（动作）'));
    expect(reminder, contains('必须独占一行并写成「对白」'));
    expect(reminder, contains('且至少有一段对白'));
  });

  test('action-expression reminder has removable A/B branches', () {
    final enabled = PromptBuilder.visibleChineseGenerationReminder(
      ordinaryActionExperimentActive: true,
    );
    final disabled = PromptBuilder.visibleChineseGenerationReminder(
      ordinaryActionExperimentActive: false,
    );

    expect(enabled, contains('当前世界书启用了动作神态'));
    expect(enabled, contains('写一个简短的自身动作/神态'));
    expect(enabled, contains('对白独占一行并使用「」'));
    expect(disabled, isNot(contains('动作神态')));
    expect(disabled, contains('偶发口误不会被系统强制中断'));
  });

  test('learning capability truth appears only for relevant conversation', () {
    final relevant = PromptBuilder.personalityLearningCapabilityContract(
      latestUserText: '我已经给你做好学习和成长系统了',
      recent: const <ChatMessage>[],
      mode: PromptGenerationMode.userTurn,
    );
    expect(relevant, contains('PHASE 2B BOUNDED BIAS'));
    expect(relevant, contains('最多两条低权重倾向'));
    expect(relevant, contains('Phase 3 尚未开启'));

    final ordinary = PromptBuilder.personalityLearningCapabilityContract(
      latestUserText: '今天晚饭吃什么？',
      recent: const <ChatMessage>[],
      mode: PromptGenerationMode.userTurn,
    );
    expect(ordinary, isEmpty);
  });
}
