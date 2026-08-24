import 'package:ai_companion_localfirst/core/grounding/service_template_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core obedient standby bundle is rejected', () {
    final result = ServiceTemplateGuard.evaluate(
      text: '你忙你的，我不催你。我就在这儿，不走。',
      currentUserText: '我去处理点事情。',
    );

    expect(result.allowed, isFalse);
    expect(result.reason, 'core_service_template');
  });

  test('ordinary concrete care is not rejected', () {
    final result = ServiceTemplateGuard.evaluate(
      text: '先把会议开完吧，那个报表第三列我觉得还有点怪。',
      currentUserText: '我马上开会。',
    );

    expect(result.allowed, isTrue);
  });

  test('meta discussion of a quoted phrase remains possible', () {
    final result = ServiceTemplateGuard.evaluate(
      text: '“一直在”这种话确实太像模板，我不该顺手往句尾贴。',
      currentUserText: '你为什么总说一直在？',
    );

    expect(result.allowed, isTrue);
    expect(result.reason, 'quoted_or_meta_discussion');
  });

  test('soft family is cooled down across recent replies', () {
    final result = ServiceTemplateGuard.evaluate(
      text: '想说的时候再说。',
      recentAssistantTexts: const [
        '我会等你，什么时候想说都可以。',
      ],
      currentUserText: '嗯。',
    );

    expect(result.allowed, isFalse);
    expect(result.reason, 'repeated_service_template_family');
  });

  test('proactive contact cannot be a standby service template', () {
    final result = ServiceTemplateGuard.evaluate(
      text: '我在这里，想说的时候再说。',
      proactive: true,
    );

    expect(result.allowed, isFalse);
    expect(result.reason, 'proactive_service_template');
  });

  test('fallback removes template tail and keeps concrete reaction', () {
    final rewritten = ServiceTemplateGuard.removeTemplateSentences(
      '你这句把我逗笑了。你忙你的，我不催你。',
    );

    expect(rewritten, '你这句把我逗笑了。');
  });
}
