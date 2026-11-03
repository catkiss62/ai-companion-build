import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/caicai_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_review_material.dart';

void main() {
  test('DeepSeek exposes complete presets and the same visible beat template as Caicai', () async {
    Map? sent;
    final gateway = JevDecisionGateway(enabledReader: () async => true,
      keyReader: () async => 'synthetic', clientFactory: () => MockClient((request) async {
        sent = jsonDecode(request.body) as Map;
        return http.Response('{}', 503);
      }));
    final parameters = <String, dynamic>{for (final channel in DeepseekMotionPlanner.channels.values)
      for (final option in channel.values) for (final id in option.keys)
        id: {'min': id.contains('Open') ? 0 : -30, 'max': id.contains('Open') ? 1.5 : 30}};
    await DeepseekMotionPlanner(gateway: gateway).plan(user: '让我看看你的反应',
      reply: '哼，你再说一遍？', emotion: 'playful', spokenText: '哼，你再说一遍？', parameters: parameters);
    final questions = sent!['questions'] as Map;
    for (final prefix in ['', 'speech0_']) {
      for (final layer in ['face', 'effect', 'wink']) {
        final prompt = questions['$prefix${layer}_use']['instructions'] as String;
        expect(prompt, contains('已有其他层不是不用的理由'));
        expect(prompt, contains('普通形态和小豆丁使用同样的资格'));
      }
      expect(questions['${prefix}effect_use']['instructions'], contains('不必等情绪强烈'));
    }
    expect(questions['f0_head']['criteria']['右转'], contains('25'));
    expect(questions.keys, containsAll(['f0_eyes', 'f3_intensity']));
    expect(DeepseekMotionPlanner.intensities, CaicaiMotionPlanner.intensities);
    final plan = DeepseekMotionPlanner.buildPlan({'f0_head': '右转',
      'f0_intensity': '夸张', 'f0_eyes': '左笑眼wink', 'f1_body': '右摆重心'}, parameters);
    final frames = plan['frames'] as List;
    expect(frames.first['parameters']['AngleX'], closeTo(28, .001));
    expect(frames.first['parameters']['ParamEyeLOpen'], 0);
    expect(frames[1]['parameters'], isNot(contains('ParamEyeLOpen')));
    expect(frames.first['duration'], closeTo(.95 * .34, .001));
    final special = DeepseekMotionPlanner.buildPlan({'face_use': 'yes', 'face': '爱心眼',
      'effect_use': 'yes', 'effect': '脸红', 'f0_eyes': '左笑眼wink', 'f0_mouth': '不高兴'}, parameters);
    expect(special['face'], '爱心眼'); expect(special['effect'], '脸红');
    expect((special['frames'] as List).first['parameters']['ParamMouthForm'], -1);
    expect((special['frames'] as List).first['parameters'], isNot(contains('ParamEyeLOpen')));
  });

  test('dedup history keeps original goals while live criteria and protected archive remain intact', () {
    final now = DateTime(2026, 11, 3);
    CompanionWish wish(String id, String route, {String state = 'active', bool hold = false}) =>
      CompanionWish(id: id, goal: '想和你一起看傍晚窗外的云$id', reason: '今天看见云很漂亮',
        route: route, criterion: '用户实际描述一起看到的云朵形状', createdAt: now,
        updatedAt: now, state: state, manualHold: hold, progress: '一大段旧进度',
        baseline: '完整旧回执', evidenceQuote: '旧证据');
    final items = [wish('live', 'user'), wish('paused', 'aspiration', state: 'paused'),
      wish('held', 'user', state: 'paused', hold: true), wish('old', 'game', state: 'completed')];
    final original = jsonEncode(items.map((w) => w.toJson()).toList());
    final material = WishReviewMaterial.wishes(items);
    final live = material['wishes'] as List;
    expect(live.map((w) => w['id']), ['live', 'paused']);
    expect(live.first['criterion'], items.first.criterion);
    final history = material['wish_history'] as List;
    expect(history.map((w) => w['id']), ['held', 'old']);
    expect(history.last['goal'], items.last.goal);
    expect(jsonEncode(history), isNot(contains('完整旧回执')));
    expect(jsonEncode(items.map((w) => w.toJson()).toList()), original);
    for (final route in ['user', 'aspiration']) {
      final result = WishPolicy.apply(wishes: [], payload: {'new_wish': {
        'goal': '想和你一起记录窗外的云', 'reason': '今天看见云很漂亮', 'route': route,
        'criterion': '用户实际描述一起看到的云朵形状', 'completion_kind': 'user_text',
        'source_ids': ['chat'],
      }}, evidence: [WishEvidence(id: 'chat', kind: 'user_text', text: '今天看见云很漂亮', at: now)],
        catalogIds: {}, now: now, canGenerate: true);
      expect(result.single.route, route);
    }
  });
}
