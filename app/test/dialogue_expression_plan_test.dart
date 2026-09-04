import 'package:ai_companion_localfirst/core/ai/dialogue_expression_plan.dart';
import 'package:ai_companion_localfirst/core/diagnostics/dialogue_expression_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light chat stays natural and deterministically routed', () {
    final first = DialogueExpressionPlan.select(
      latestUserText: '我就是抖M',
      turnKey: 'message-42',
    );
    final replay = DialogueExpressionPlan.select(
      latestUserText: '我就是抖M',
      turnKey: 'message-42',
    );

    expect(first.mode, DialogueResponseMode.casual);
    expect(first.humor, replay.humor);
    expect(first.selectionSeed, replay.selectionSeed);
    expect(first.humor, DialogueHumorDevice.none);
    expect(first.render(), contains('不需要逐点答全'));
    expect(first.render(), contains('是否幽默由当前语境自然决定'));
  });

  test('direct negative feedback is literal and never routed to humor', () {
    const samples = <String>[
      '没看到哪里造梗',
      '好弱智',
      '也太简单了吧',
      '这个没难度，一眼就猜到了',
      '跳脱一点，别总代入自己',
      '换个思路，再难点',
      '很无聊，你真没有幽默感？',
      '确实没笑',
      '你又开始反问了',
    ];
    for (var i = 0; i < samples.length; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: samples[i],
        turnKey: 'feedback-$i',
      );
      expect(plan.mode, DialogueResponseMode.feedback);
      expect(plan.humor, DialogueHumorDevice.none);
      expect(plan.render(), contains('真实反馈'));
      expect(plan.render(), contains('不要反射性自证人格'));
    }
  });

  test('riddles and explicit creative challenges use quality-first routing', () {
    const samples = <String>[
      '我们来玩猜谜吧',
      '给我出个谜语',
      '来一道逻辑谜题',
      '来个真正有意思的挑战',
    ];
    for (var i = 0; i < samples.length; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: samples[i],
        turnKey: 'challenge-$i',
      );
      expect(plan.mode, DialogueResponseMode.challenge);
      expect(plan.humor, DialogueHumorDevice.none);
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

  test('casual turns no longer receive random humor devices', () {
    for (var i = 0; i < 4000; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: '随便聊聊$i',
        turnKey: 'casual-density-$i',
      );
      expect(plan.humor, DialogueHumorDevice.none);
    }
  });

  test('technical and deep turns may expand without humor pressure', () {
    final task = DialogueExpressionPlan.select(
      latestUserText: '帮我排查这个数据库报错，给出修复步骤',
      turnKey: 'task-1',
    );
    final deep = DialogueExpressionPlan.select(
      latestUserText: '我想认真聊聊我们的关系和未来',
      turnKey: 'deep-1',
    );

    expect(task.mode, DialogueResponseMode.task);
    expect(task.humor, DialogueHumorDevice.none);
    expect(task.render(), contains('正确完整优先'));
    expect(deep.mode, DialogueResponseMode.deep);
    expect(deep.humor, DialogueHumorDevice.none);
    expect(deep.render(), contains('允许按内容自然变长'));
  });

  test('sensitive content suppresses jokes but not directness', () {
    final plan = DialogueExpressionPlan.select(
      latestUserText: '我现在胸痛而且呼吸困难',
      turnKey: 'risk-1',
    );

    expect(plan.mode, DialogueResponseMode.sensitive);
    expect(plan.humor, DialogueHumorDevice.none);
    expect(plan.render(), contains('别拿痛苦本身造梗'));
    expect(plan.render(), contains('必要信息说全'));
  });

  test('expression plan leaves humor to the actual context', () {
    for (var i = 0; i < 64; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: '你猜我刚刚干了什么',
        turnKey: 'casual-$i',
      );
      final prompt = plan.render();
      expect(plan.humor, DialogueHumorDevice.none);
      expect(prompt, contains('不分配笑点类型'));
      expect(prompt, contains('不强制造梗'));
    }
  });

  test('telemetry stores counters without conversation or prompt bodies', () {
    final first = DialogueExpressionTelemetry.nextSnapshot(
      raw: null,
      mode: 'casual',
      humor: 'meaningSwerve',
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final second = DialogueExpressionTelemetry.nextSnapshot(
      raw: '{"modeCounts":{"casual":1},"humorCounts":{"meaningSwerve":1}}',
      mode: 'task',
      humor: 'none',
      now: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect((first['modeCounts']! as Map)['casual'], 1);
    expect((first['humorCounts']! as Map)['meaningSwerve'], 1);
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
