import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
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
    expect(reminder, isNot(contains('允许纯对白')));
    expect(reminder, isNot(contains('普通聊天正文的人称与可见 reasoning 分开')));
    expect(reminder, isNot(contains('禁止用“我”“她”')));
    expect(reminder, isNot(contains('只用第二人称“你”')));
    expect(reminder, isNot(contains('<system-reminder>')));
  });

  test('proactive reminder preserves WAIT without inventing a user turn', () {
    final reminder = PromptBuilder.visibleChineseGenerationReminder(
      proactive: true,
    );
    expect(reminder, contains('只输出 WAIT'));
    expect(reminder, isNot(contains('用户刚刚')));
  });
}
