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
    expect(reminder, contains('「」只包住实际发声'));
    expect(reminder, contains('必须另起一行留在「」外'));
    expect(reminder, contains('顿了顿，又小小声补了一句。'));
    expect(reminder, contains('「……再摸一会儿也行。」'));
    expect(reminder, contains('可见思考提及用户时也使用“你”'));
    expect(reminder, contains('不得写成“他、用户、玩家、男方或男人”'));
    expect(reminder, isNot(contains('允许纯对白')));
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
