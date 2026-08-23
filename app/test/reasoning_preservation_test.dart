import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider reasoning is not discarded because it is mostly English', () {
    const raw =
        'I should consider the concrete context before answering naturally.';
    expect(preserveProviderReasoning(raw), raw);
  });

  test('only surrounding whitespace is removed', () {
    expect(
      preserveProviderReasoning('  中文思考和 API term  \n'),
      '中文思考和 API term',
    );
    expect(preserveProviderReasoning('   '), isEmpty);
  });
}
