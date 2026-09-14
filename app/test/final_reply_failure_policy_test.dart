import 'dart:async';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_failure_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gemini final lane retries only transient failures', () {
    expect(FinalReplyFailurePolicy.maxGeminiAttempts, 2);
    expect(
      FinalReplyFailurePolicy.isTransient(TimeoutException('late')),
      isTrue,
    );
    for (final status in <int>[429, 500, 502, 503, 504]) {
      expect(
        FinalReplyFailurePolicy.isTransient(
          DeepSeekException(status, 'temporary'),
        ),
        isTrue,
      );
    }
    for (final status in <int>[400, 401, 403, 404]) {
      expect(
        FinalReplyFailurePolicy.isTransient(
          DeepSeekException(status, 'permanent'),
        ),
        isFalse,
      );
    }
    expect(
      FinalReplyFailurePolicy.isTransient(
        const GenerationStreamIncompleteException(),
      ),
      isTrue,
    );
  });

  test('partial terminal reasons require an explicit user decision', () {
    expect(FinalReplyFailurePolicy.isIncompleteFinishReason('stop'), isFalse);
    expect(FinalReplyFailurePolicy.isIncompleteFinishReason(''), isFalse);
    expect(FinalReplyFailurePolicy.isIncompleteFinishReason('length'), isTrue);
    expect(
      FinalReplyFailurePolicy.isIncompleteFinishReason('content_filter'),
      isTrue,
    );
    expect(
      FinalReplyFailurePolicy.isIncompleteFinishReason('stream_incomplete'),
      isTrue,
    );
  });

  test('only strong structural evidence marks a stop reply incomplete', () {
    expect(
      FinalReplyFailurePolicy.hasStrongIncompleteStructure('「我现在满脑子'),
      isTrue,
    );
    expect(
      FinalReplyFailurePolicy.hasStrongIncompleteStructure('「说完了。」'),
      isFalse,
    );
    expect(
      FinalReplyFailurePolicy.hasStrongIncompleteStructure('忽然有点想你'),
      isFalse,
    );
  });
}
