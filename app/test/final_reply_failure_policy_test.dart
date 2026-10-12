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

  test('length identifies the output limit and retains provider evidence', () {
    final failure = FinalReplyFailurePolicy.incompleteResponseFailure(
      sawTerminalSignal: true,
      finishReason: ' LENGTH ',
      reasoning: 'partial reasoning',
      content: '「没说完',
    );

    expect(failure, isNotNull);
    expect(failure!.reason, GenerationIncompleteReason.outputLimit);
    expect(failure.diagnosticCode, 'output_limit');
    expect(failure.finishReason, ' LENGTH ');
    expect(failure.reasoning, 'partial reasoning');
    expect(failure.content, '「没说完');
    expect(FinalReplyFailurePolicy.userCategory(failure), '达到输出上限');
    expect(failure.toString(), isNot(contains('连接')));
    expect(FinalReplyFailurePolicy.isTransient(failure), isTrue);
  });

  test('provider rejection is distinct from transport completion', () {
    for (final finishReason in <String>['content_filter', 'safety', 'error']) {
      final failure = FinalReplyFailurePolicy.incompleteResponseFailure(
        sawTerminalSignal: true,
        finishReason: finishReason,
        content: '「没说完',
      );

      expect(failure, isNotNull);
      expect(failure!.reason, GenerationIncompleteReason.abnormalFinishReason);
      expect(failure.diagnosticCode, 'abnormal_finish_reason');
      expect(failure.finishReason, finishReason);
      expect(
        FinalReplyFailurePolicy.userCategory(failure),
        '模型异常结束（$finishReason）',
      );
      expect(FinalReplyFailurePolicy.isTransient(failure), isTrue);
    }
  });

  test('unclosed dialogue with stop is a structure failure', () {
    final failure = FinalReplyFailurePolicy.incompleteResponseFailure(
      sawTerminalSignal: true,
      finishReason: 'stop',
      content: '「没说完',
    );

    expect(failure, isNotNull);
    expect(failure!.reason, GenerationIncompleteReason.incompleteStructure);
    expect(failure.diagnosticCode, 'incomplete_structure');
    expect(FinalReplyFailurePolicy.userCategory(failure), '对白结构不完整');
    expect(FinalReplyFailurePolicy.isTransient(failure), isTrue);
  });

  test('missing terminal marker does not claim a network disconnection', () {
    final failure = FinalReplyFailurePolicy.incompleteResponseFailure(
      sawTerminalSignal: false,
      content: '已经写完的短句',
    );

    expect(failure, isNotNull);
    expect(failure!.reason, GenerationIncompleteReason.missingTerminalSignal);
    expect(failure.diagnosticCode, 'missing_terminal_signal');
    expect(FinalReplyFailurePolicy.userCategory(failure), '未收到流式完成标记');
    expect(FinalReplyFailurePolicy.isTransient(failure), isTrue);
    expect(
      const GenerationStreamIncompleteException().reason,
      GenerationIncompleteReason.missingTerminalSignal,
    );
  });

  test('explicit terminal reasons take priority over a missing marker', () {
    expect(
      FinalReplyFailurePolicy.incompleteResponseFailure(
        sawTerminalSignal: false,
        finishReason: 'length',
      )!.reason,
      GenerationIncompleteReason.outputLimit,
    );
    expect(
      FinalReplyFailurePolicy.incompleteResponseFailure(
        sawTerminalSignal: false,
        finishReason: 'error',
      )!.reason,
      GenerationIncompleteReason.abnormalFinishReason,
    );
    expect(
      FinalReplyFailurePolicy.incompleteResponseFailure(
        sawTerminalSignal: true,
        finishReason: 'stream_incomplete',
      )!.reason,
      GenerationIncompleteReason.missingTerminalSignal,
    );
  });

  test('normal completion and empty-body classification stay unchanged', () {
    for (final content in <String>['「说完了。」', '忽然有点想你', 'WAIT', '']) {
      for (final finishReason in <String>['stop', '']) {
        expect(
          FinalReplyFailurePolicy.incompleteResponseFailure(
            sawTerminalSignal: true,
            finishReason: finishReason,
            content: content,
          ),
          isNull,
        );
      }
    }
    expect(
      FinalReplyFailurePolicy.userCategory(const EmptyFinalReplyException()),
      '没有返回正文',
    );
  });
}
