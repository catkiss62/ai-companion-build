import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generation cancellation is immediate and idempotent', () async {
    final token = GenerationCancellationToken();

    expect(token.isCancelled, isFalse);
    token.cancel();
    token.cancel();

    await token.whenCancelled;
    expect(token.isCancelled, isTrue);
    expect(
      token.throwIfCancelled,
      throwsA(isA<GenerationCancelledByUserException>()),
    );
  });
}
