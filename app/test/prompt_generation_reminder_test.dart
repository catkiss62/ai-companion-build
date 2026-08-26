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
