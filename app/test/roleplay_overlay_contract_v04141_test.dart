import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/reference/reference_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roleplay overlays the companion instead of replacing her', () {
    for (final prompt in <String>[
      PromptBuilder.identityPrompt,
      PromptBuilder.roleplayExecutionAnchor,
      ReferenceLibrary.roleplayContract,
    ]) {
      expect(prompt, contains('同一个小鲸鱼'));
      expect(prompt, contains('明确'));
      expect(prompt, contains('未声明部分'));
      expect(prompt, isNot(contains('场景身份的完整接管')));
      expect(prompt, isNot(contains('角色卡完整决定')));
    }
    expect(
      ReferenceLibrary.roleplayContract,
      contains('正式性格、关系历史、AI Self'),
    );
    expect(
      PromptBuilder.roleplayExecutionAnchor,
      contains('只写表达风格'),
    );
  });

  test('immersive second-person contract stays out of the overlay rewrite', () {
    expect(
      PromptBuilder.roleplayExecutionAnchor,
      isNot(contains('沉浸正文')),
    );
    expect(
      ReferenceLibrary.roleplayContract,
      isNot(contains('AI角色在正文中始终写作“她”')),
    );
  });
}
