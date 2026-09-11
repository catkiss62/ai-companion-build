import 'package:ai_companion_localfirst/core/immersive/immersive_nsfw_router.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_prompt_builder.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
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
    expect(sections.preflight, contains('叙述层·直白中性词'));
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
    expect(rendering, contains('非性交行为（例如口交、乳交等）不要求 AI 角色与用户同步高潮'));
    expect(rendering, isNot(contains('没有固定阶段表、固定字数、固定高潮口令或同步流程')));
    expect(rendering, contains('自然停顿与后续衔接'));
    expect(rendering, isNot(contains('下一轮就直接解用户扣子')));
  });

  test('immersive source restores sections without overriding control', () {
    final source = defaultRuleLayers
        .singleWhere((layer) => layer.key == 'immersive_07_nsfw_source')
        .content;

    expect(source, isNot(contains(r'\n')));
    expect(source, startsWith('[【色情描写强化模块】'));
    expect(source, isNot(contains('重要：色情模块，一定要认真执行')));
    expect(source, contains('本参考的控制边界'));
    expect(source, contains('05 NSFW 状态机对本轮能否进阶拥有唯一裁决权'));
    expect(source, isNot(contains('以玩家视角为主')));
    expect(source, isNot(contains('每个阶段至少500字')));
  });

  test('immersive paragraphs and humor identity boundary are explicit', () {
    final global = defaultRuleLayers
        .singleWhere((layer) => layer.key == 'immersive_07_global')
        .content;
    expect(global, contains('使用「」包裹'));
    expect(global, isNot(contains('中文弯引号“”')));
    expect(global, contains('引号只是叙述的一部分'));
    expect(global, contains('每段对白独占一个自然段'));
    expect(worldBookOptimizedHumorV04128, contains('一轮最多一个主要笑点'));
    expect(worldBookOptimizedHumorV04128, contains('禁止用性别错位'));
    expect(worldBookOptimizedHumorV04128, isNot(contains('我是一个男孩子')));
    expect(worldBookHumorV04149, contains('场景小剧场 / 抽象舞台'));
    expect(worldBookHumorV04149, contains('临时身份错位'));
    expect(worldBookHumorV04149, contains('从业二十年的资深冰箱'));
    expect(worldBookHumorV04149, contains('受控语言破坏'));
    expect(worldBookHumorV04149, contains('可以说粗口、荤话或黑色幽默'));
    expect(worldBookHumorV04149, isNot(contains('**')));
    expect(worldBookHumorV04149, isNot(contains('{{char}}')));
    expect(worldBookHumorV04149, isNot(contains('{{user}}')));
    final humor = worldBookSystemPresets
        .singleWhere((preset) => preset.id == 'builtin.worldbook.humor');
    expect(humor.content, contains('NSFW时不要造梗和抽象'));
    expect(humor.probability, 30);
  });

  test('continuation repairs truncation instead of filling a word quota', () {
    expect(
      ImmersivePromptBuilder.shouldContinue('她停了下来。', 'stop'),
      isFalse,
    );
    expect(
      ImmersivePromptBuilder.shouldContinue('她仍然', 'stop'),
      isTrue,
    );
    expect(
      ImmersivePromptBuilder.shouldContinue('“别动', 'stop'),
      isTrue,
    );
    expect(
      ImmersivePromptBuilder.shouldContinue('「别动', 'stop'),
      isTrue,
    );
    expect(
      ImmersivePromptBuilder.shouldContinue('她停了下来。', 'length'),
      isTrue,
    );
    expect(
      ImmersivePromptBuilder.continuationBoundary('她停了下来。', 'stop'),
      isEmpty,
    );
    expect(
      ImmersivePromptBuilder.continuationBoundary('她仍然', 'stop'),
      isEmpty,
    );
    expect(
      ImmersivePromptBuilder.continuationBoundary('她停了下来。', 'length'),
      '\n\n',
    );
    final continuation = ImmersivePromptBuilder.continuationMessages(
      const <Map<String, Object?>>[],
      '她仍然',
    ).last['content']! as String;
    expect(continuation, contains('不补字数'));
    expect(continuation, contains('当前这一个叙事节拍'));
    expect(continuation, contains('女性 AI 角色'));
    expect(continuation, isNot(contains('1000')));
    expect(continuation, isNot(contains('硬下限')));
  });

  test('continuation reasoning stays private and does not overwrite phase one', () {
    expect(
      ImmersiveRoomController.mergePersistedReasoning(
        '第一段思考',
        '继续思考',
        capture: false,
      ),
      '第一段思考',
    );
    expect(
      ImmersiveRoomController.mergePersistedReasoning(
        '第一段思考',
        '后续',
        capture: true,
      ),
      '第一段思考后续',
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
