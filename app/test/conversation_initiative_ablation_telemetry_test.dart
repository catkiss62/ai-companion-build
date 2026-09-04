import 'package:ai_companion_localfirst/core/diagnostics/conversation_initiative_ablation_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt responsibility shape stores presence but not prompt bodies', () {
    final shape = PromptResponsibilityShape.fromMessages(const [
      {
        'role': 'system',
        'content': '你是女性 AI 伴侣。\n【本轮动态表达倾向】\n【本轮对话表达计划】\n【本轮最终呈现提醒】',
      },
      {'role': 'user', 'content': 'private user body'},
    ]);
    final json = shape.toRedactedJson();
    final layers = json['layers']! as Map<String, bool>;
    expect(layers['identity'], isTrue);
    expect(layers['dynamicMoe'], isTrue);
    expect(layers['dialogueExpressionPlan'], isTrue);
    expect(layers['finalReminder'], isTrue);
    expect(json['promptBodiesIncluded'], isFalse);
    expect(json.toString(), isNot(contains('private user body')));
  });

  test('raw and final verifier reasons locate the responsibility stage', () {
    expect(
      ConversationInitiativeAblationTelemetry.attribution(
        'planned_bid_not_expressed',
        'planned_bid_not_expressed',
      ),
      'raw_generation_or_prompt',
    );
    expect(
      ConversationInitiativeAblationTelemetry.attribution(
        'expressed_match',
        'planned_bid_not_expressed',
      ),
      'post_generation_changed_to_mismatch',
    );
    expect(
      ConversationInitiativeAblationTelemetry.attribution(
        'planned_bid_not_expressed',
        'expressed_match',
      ),
      'post_generation_recovered',
    );
  });

  test('prompt size is exported only as a coarse bucket', () {
    expect(PromptResponsibilityShape.characterBucket(12000), '8_16k');
    expect(PromptResponsibilityShape.characterBucket(50000), '32k_plus');
  });
}
