class MoeExpressionDefaultPolicy {
  const MoeExpressionDefaultPolicy._();

  static const markerKey = 'moe_expression_default_v04130_applied';
  static const enabledValue = '1';
  static const expressionMode = 'obvious';

  static bool shouldApply(String? marker) => marker != '1';
}
