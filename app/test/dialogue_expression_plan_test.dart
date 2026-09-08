import 'package:ai_companion_localfirst/core/ai/dialogue_expression_plan.dart';
import 'package:ai_companion_localfirst/core/diagnostics/dialogue_expression_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light chat is deterministic and can receive a concrete humor card', () {
    final first = DialogueExpressionPlan.select(
      latestUserText: '我就是抖M，来点抽象的',
      turnKey: 'message-42',
      subjectivePlayfulness: 0.18,
      hasOwnThought: true,
    );
    final replay = DialogueExpressionPlan.select(
      latestUserText: '我就是抖M，来点抽象的',
      turnKey: 'message-42',
      subjectivePlayfulness: 0.18,
      hasOwnThought: true,
    );

    expect(first.mode, DialogueResponseMode.casual);
    expect(first.humor, replay.humor);
    expect(first.secondaryHumor, replay.secondaryHumor);
    expect(first.selectionSeed, replay.selectionSeed);
    expect(first.humor, isNot(DialogueHumorDevice.none));
    expect(first.render(), contains('已命中造梗机会'));
    expect(first.render(), contains('主造法'));
    expect(first.render(), isNot(contains('**')));
  });

  test('humor criticism requests a changed concrete method', () {
    const samples = <String>[
      '没看到哪里造梗',
      '很无聊，你真没有幽默感？',
      '确实没笑，换个梗',
      '跳脱一点，换个思路',
    ];
    for (var i = 0; i < samples.length; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: samples[i],
        turnKey: 'humor-feedback-$i',
      );
      expect(plan.mode, DialogueResponseMode.feedback);
      expect(plan.humor, isNot(DialogueHumorDevice.none));
      expect(plan.activationReason, 'humor_feedback');
      expect(plan.render(), contains('真实反馈'));
      expect(plan.render(), contains('本轮把它真正写进正文'));
    }
  });

  test('non-humor correction remains literal instead of becoming a bit', () {
    for (final sample in ['你又开始反问了', '别挑衅，也别替我总结']) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: sample,
        turnKey: 'ordinary-feedback-$sample',
      );
      expect(plan.mode, DialogueResponseMode.feedback);
      expect(plan.humor, DialogueHumorDevice.none);
      expect(plan.render(), contains('不要反射性自证人格'));
    }
  });

  test('riddles and explicit creative challenges use quality-first routing', () {
    for (final sample in ['我们来玩猜谜吧', '给我出个谜语', '来一道逻辑谜题']) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: sample,
        turnKey: 'challenge-$sample',
      );
      expect(plan.mode, DialogueResponseMode.challenge);
      expect(plan.render(), contains('内容质量与明确要求是硬标准'));
      expect(plan.render(), contains('题面没有直接暴露答案'));
      expect(plan.render(), contains('不要改写成标准助手答题模板'));
    }
  });

  test('casual guessing and ordinary games do not become task mode', () {
    for (final sample in ['你猜我刚刚干了什么', '我最近在玩一个飞机游戏']) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: sample,
        turnKey: 'ordinary-$sample',
      );
      expect(plan.mode, DialogueResponseMode.casual);
    }
  });

  test('all eleven primary mechanisms are reachable in casual routing', () {
    final reached = <DialogueHumorDevice>{};
    var activated = 0;
    for (var i = 0; i < 5000; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: '随便聊聊第$i件小事',
        turnKey: 'casual-density-$i',
      );
      if (plan.humor != DialogueHumorDevice.none) {
        activated++;
        reached.add(plan.humor);
      }
    }
    expect(activated, inInclusiveRange(1250, 1750));
    expect(
      reached,
      containsAll(<DialogueHumorDevice>{
        DialogueHumorDevice.homophonicMutation,
        DialogueHumorDevice.violentStitching,
        DialogueHumorDevice.deadpanNonsense,
        DialogueHumorDevice.microTheater,
        DialogueHumorDevice.identityMismatch,
        DialogueHumorDevice.epicMundanity,
        DialogueHumorDevice.semanticSwerve,
        DialogueHumorDevice.enumerationMania,
        DialogueHumorDevice.genreParody,
        DialogueHumorDevice.meaninglessNonsense,
        DialogueHumorDevice.characterMutation,
      }),
    );
  });

  test('own state raises opportunity and enables controlled extensions', () {
    var baseline = 0;
    var subjective = 0;
    final auxiliaries = <DialogueHumorDevice>{};
    for (var i = 0; i < 3000; i += 1) {
      final plain = DialogueExpressionPlan.select(
        latestUserText: '今天发生了一件小事$i',
        turnKey: 'state-$i',
      );
      final alive = DialogueExpressionPlan.select(
        latestUserText: '今天发生了一件小事$i',
        turnKey: 'state-$i',
        subjectivePlayfulness: 0.22,
        hasOwnThought: true,
      );
      if (plain.humor != DialogueHumorDevice.none) baseline++;
      if (alive.humor != DialogueHumorDevice.none) subjective++;
      if (alive.secondaryHumor != DialogueHumorDevice.none) {
        auxiliaries.add(alive.secondaryHumor);
      }
    }
    expect(subjective, greaterThan(baseline));
    expect(
      auxiliaries,
      containsAll(<DialogueHumorDevice>{
        DialogueHumorDevice.emotionalAvalanche,
        DialogueHumorDevice.linguisticMutilation,
        DialogueHumorDevice.joinTheBit,
      }),
    );
  });

  test('object and theater cues select the intended mechanisms', () {
    expect(
      DialogueExpressionPlan.select(
        latestUserText: '我又忘记关冰箱门了，开个玩笑',
        turnKey: 'fridge',
      ).humor,
      DialogueHumorDevice.identityMismatch,
    );
    expect(
      DialogueExpressionPlan.select(
        latestUserText: '你不是说再偷吃就是狗吗，汪汪',
        turnKey: 'dog',
      ).humor,
      DialogueHumorDevice.microTheater,
    );
  });

  test('technical and deep turns keep answer quality directives', () {
    final task = DialogueExpressionPlan.select(
      latestUserText: '帮我排查这个数据库报错，给出修复步骤',
      turnKey: 'task-1',
    );
    final deep = DialogueExpressionPlan.select(
      latestUserText: '我想认真聊聊我们的关系和未来',
      turnKey: 'deep-1',
    );

    expect(task.mode, DialogueResponseMode.task);
    expect(task.render(), contains('正确完整优先'));
    expect(deep.mode, DialogueResponseMode.deep);
    expect(deep.render(), contains('允许按内容自然变长'));
  });

  test('urgent sensitive content suppresses a method card but stays direct', () {
    final plan = DialogueExpressionPlan.select(
      latestUserText: '我现在胸痛而且呼吸困难',
      turnKey: 'risk-1',
      subjectivePlayfulness: 0.35,
      hasOwnThought: true,
    );

    expect(plan.mode, DialogueResponseMode.sensitive);
    expect(plan.humor, DialogueHumorDevice.none);
    expect(plan.render(), contains('别拿痛苦本身造梗'));
    expect(plan.render(), contains('必要信息说全'));
  });

  test('telemetry stores counters without conversation or prompt bodies', () {
    final first = DialogueExpressionTelemetry.nextSnapshot(
      raw: null,
      mode: 'casual',
      humor: 'semanticSwerve',
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final second = DialogueExpressionTelemetry.nextSnapshot(
      raw: '{"modeCounts":{"casual":1},"humorCounts":{"semanticSwerve":1}}',
      mode: 'task',
      humor: 'none',
      now: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect((first['modeCounts']! as Map)['casual'], 1);
    expect((first['humorCounts']! as Map)['semanticSwerve'], 1);
    expect((second['modeCounts']! as Map)['task'], 1);
    expect((second['humorCounts']! as Map)['none'], 1);
    expect(second['lastAt'], 2000);
    expect(second['userTextIncluded'], isFalse);
    expect(second['promptBodiesIncluded'], isFalse);
    expect(second['generatedTextIncluded'], isFalse);
    expect(second['reasoningIncluded'], isFalse);
    expect(second['messageIdsIncluded'], isFalse);
  });
}
