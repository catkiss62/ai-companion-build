import 'package:ai_companion_localfirst/core/immersive/immersive_nsfw_router.dart';
import 'package:ai_companion_localfirst/core/rules/intimacy_prompt_sections.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_content_immersive.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reviewed intimacy self-check is moved to a late silent prompt', () {
    final core = defaultRuleLayers
        .singleWhere((layer) => layer.key == '04_intimacy_core')
        .content;
    final sections = IntimacyPromptSections.parse(core);

    expect(sections.body, isNot(contains('【输出前自查】')));
    expect(sections.preflight, contains('【输出前自查】'));
    expect(sections.preflight, contains('肉棒'));
    expect(sections.preflight, contains('龟头/顶端/柱身/囊袋/根部'));
    expect(sections.preflight, contains('大量叠词'));

    final late = sections.latePrompt(
      turnState: '用户尚未射精。',
      immersive: true,
    );
    expect(late, contains('NSFW 末端静默校验'));
    expect(late, contains('不是可见思考的内容'));
    expect(late, contains('小鲸鱼=她、用户=你'));
    expect(late, contains('用户尚未射精'));

    final ordinary = sections.latePrompt();
    expect(ordinary, contains('普通聊天正文沿用当前对白/动作格式'));
    expect(ordinary, isNot(contains('沉浸正文是否坚持 AI=她')));
  });

  test('conservative fallback never confuses nearing with release', () {
    expect(
      ImmersiveNsfwRouter.fallbackClimaxEvent('我快射了'),
      ImmersiveClimaxEvent.userNear,
    );
    expect(
      ImmersiveNsfwRouter.fallbackClimaxEvent('我要射了，等一下'),
      ImmersiveClimaxEvent.hold,
    );
    expect(
      ImmersiveNsfwRouter.fallbackClimaxEvent('我已经射出来了'),
      ImmersiveClimaxEvent.userRelease,
    );
    expect(
      ImmersiveNsfwRouter.fallbackClimaxEvent('你先高潮吧'),
      ImmersiveClimaxEvent.aiRelease,
    );
  });

  test('rendering rule installs the cross-turn climax flow', () {
    final rendering = defaultRuleLayers
        .singleWhere((layer) => layer.key == '05_intimacy_rendering')
        .content;

    expect(rendering, contains('【高潮引导 · 跨轮同步状态机】'));
    expect(rendering, contains('只是宣言，不是已发生的射精'));
    expect(rendering, contains('此时仍必须再次同步到达'));
    expect(rendering, isNot(contains('没有固定阶段表、固定字数、固定高潮口令或同步流程')));
  });

  test('immersive source restores sections without overriding control', () {
    final source = immersiveNsfwSourceForPrompt(immersiveNsfwSource);

    expect(source, isNot(contains(r'\n')));
    expect(source, contains('本参考的控制边界'));
    expect(source, contains('05 NSFW 状态机对本轮能否进阶拥有唯一裁决权'));
    expect(source, contains('只有当前现场已明确建立初次、疼痛或出血事实'));
    expect(source, isNot(contains('以玩家视角为主')));
  });

  test('climax directives preserve gender and one-turn transitions', () {
    const near = ImmersiveNsfwDecision(
      active: true,
      source: 'test',
      climaxEvent: ImmersiveClimaxEvent.userNear,
    );
    const release = ImmersiveNsfwDecision(
      active: true,
      source: 'test',
      climaxEvent: ImmersiveClimaxEvent.userRelease,
    );

    expect(near.turnDirective, contains('用户本轮只宣告'));
    expect(near.turnDirective, contains('尚未射精'));
    expect(release.turnDirective, contains('女性 AI 同时高潮'));
    expect(release.turnDirective, contains('唯一主要阶段变化'));
  });
}
