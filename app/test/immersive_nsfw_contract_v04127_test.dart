import 'package:ai_companion_localfirst/core/immersive/immersive_nsfw_router.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_prompt_builder.dart';
import 'package:ai_companion_localfirst/core/models/immersive_room.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_presets.dart';
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
    expect(
      ImmersiveNsfwRouter.fallbackClimaxEvent('我快忍不住了'),
      ImmersiveClimaxEvent.userNear,
    );
  });

  test('generic waiting only becomes a climax hold inside an active scene', () {
    expect(
      ImmersiveNsfwRouter.deterministicClimaxEvent(
        '等一下，我看看门外是谁',
        nsfwContext: false,
      ),
      ImmersiveClimaxEvent.none,
    );
    expect(
      ImmersiveNsfwRouter.deterministicClimaxEvent(
        '等一下',
        nsfwContext: true,
      ),
      ImmersiveClimaxEvent.hold,
    );
  });

  test('an unresolved user-near event survives an ordinary continuation', () {
    final recent = <ImmersiveMessage>[
      ImmersiveMessage(
        id: 'near',
        roomId: 'room',
        role: 'user',
        content: '我快射了',
        reasoningContent: '',
        createdAt: DateTime(2026, 9, 3),
      ),
      ImmersiveMessage(
        id: 'assistant',
        roomId: 'room',
        role: 'assistant',
        content: '她仍停在临界。',
        reasoningContent: '',
        createdAt: DateTime(2026, 9, 3),
      ),
      ImmersiveMessage(
        id: 'continue',
        roomId: 'room',
        role: 'user',
        content: '继续',
        reasoningContent: '',
        createdAt: DateTime(2026, 9, 3),
      ),
    ];
    expect(ImmersiveNsfwRouter.hasUnresolvedUserNear(recent), isTrue);
  });

  test('rendering rule installs the cross-turn climax flow', () {
    final rendering = defaultRuleLayers
        .singleWhere((layer) => layer.key == '05_intimacy_rendering')
        .content;

    expect(rendering, contains('【高潮引导 · 跨轮同步状态机】'));
    expect(rendering, contains('只是宣言，不是已发生的射精'));
    expect(rendering, contains('此时仍必须再次同步到达'));
    expect(rendering, isNot(contains('没有固定阶段表、固定字数、固定高潮口令或同步流程')));
    expect(rendering, contains('自然停顿与后续衔接'));
    expect(rendering, isNot(contains('下一轮就直接解用户扣子')));
  });

  test('immersive source restores sections without overriding control', () {
    final source = immersiveNsfwSourceForPrompt(immersiveNsfwSource);

    expect(source, isNot(contains(r'\n')));
    expect(source, contains('本参考的控制边界'));
    expect(source, contains('05 NSFW 状态机对本轮能否进阶拥有唯一裁决权'));
    expect(source, contains('只有当前现场已明确建立初次、疼痛或出血事实'));
    expect(source, isNot(contains('以玩家视角为主')));
    expect(source, isNot(contains('每个阶段至少500字')));
  });

  test('immersive paragraphs and humor identity boundary are explicit', () {
    expect(immersiveRuleGlobal, contains('中文直角引号「」'));
    expect(immersiveRuleGlobal, contains('中文弯引号“”只是引用内容'));
    expect(immersiveRuleGlobal, contains('引号只是叙述的一部分'));
    expect(immersiveRuleGlobal, contains('每段对白独占一个自然段'));
    expect(worldBookOptimizedHumorV04128, contains('一轮最多一个主要笑点'));
    expect(worldBookOptimizedHumorV04128, contains('禁止用性别错位'));
    expect(worldBookOptimizedHumorV04128, isNot(contains('我是一个男孩子')));
  });

  test('clean continuation starts a new paragraph but fragments do not', () {
    expect(
      ImmersivePromptBuilder.continuationBoundary('她停了下来。', 'stop'),
      '\n\n',
    );
    expect(
      ImmersivePromptBuilder.continuationBoundary('她仍然', 'stop'),
      isEmpty,
    );
    expect(
      ImmersivePromptBuilder.continuationBoundary('她停了下来。', 'length'),
      isEmpty,
    );
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
