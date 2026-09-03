import 'package:ai_companion_localfirst/core/integration/moe_expression_default_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.41.30 enables obvious Moe expression only once', () {
    expect(MoeExpressionDefaultPolicy.shouldApply(null), isTrue);
    expect(MoeExpressionDefaultPolicy.shouldApply('0'), isTrue);
    expect(MoeExpressionDefaultPolicy.shouldApply('1'), isFalse);
    expect(MoeExpressionDefaultPolicy.enabledValue, '1');
    expect(MoeExpressionDefaultPolicy.expressionMode, 'obvious');
  });
}
