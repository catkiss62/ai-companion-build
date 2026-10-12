import '../ai/final_reply_failure_policy.dart';
import '../ai/final_reply_route.dart';
import '../ai/generation_cancellation.dart';

class ProactiveReplyResult<T> {
  const ProactiveReplyResult({
    required this.candidate,
    required this.usedSecondChannel,
    required this.secondChannelAttempts,
    required this.failures,
  });

  final T candidate;
  final bool usedSecondChannel;
  final int secondChannelAttempts;
  final List<Object> failures;
}

/// Request retries only produce private candidates. The caller still owns
/// semantic correction, WAIT, the atomic delivery and its one quota charge.
///
/// Unlike ordinary chat's transient-only policy, proactive replies allow one
/// retry for every failed provider request, including an HTTP rejection. A
/// missing local key is not a request. Cancellation and lost ownership must
/// never be mistaken for a provider failure or trigger a fallback.
class ProactiveFinalReplyRetry {
  const ProactiveFinalReplyRetry._();

  static Future<ProactiveReplyResult<T>?> generate<T extends Object>({
    required FinalReplyRoute route,
    required bool secondChannelConfigured,
    required Future<bool> Function() canContinue,
    required Future<T?> Function({required bool secondChannel}) request,
    required void Function(T candidate) validateSecondChannel,
    required Future<void> Function(int attempts, List<Object> failures)
        onFallback,
    Future<void> Function(Duration delay)? wait,
  }) async {
    var attempts = 0;
    final failures = <Object>[];
    if (route.useSecondChannel) {
      if (!secondChannelConfigured) {
        failures.add(const FormatException('missing_gemini_final_reply_key'));
      } else {
        for (var attempt = 1;
            attempt <= FinalReplyFailurePolicy.maxGeminiAttempts;
            attempt++) {
          if (!await canContinue()) return null;
          T? candidate;
          var accepted = false;
          try {
            attempts++;
            candidate = await request(secondChannel: true);
            if (candidate == null) return null;
            validateSecondChannel(candidate);
            accepted = true;
          } on GenerationSuspendedByRuntimeGateException {
            rethrow;
          } on GenerationCancelledByUserException {
            rethrow;
          } catch (error) {
            failures.add(error);
          }
          // Run boundary checks outside the provider-error catch: a failed
          // database/runtime check must not become a paid provider retry.
          if (!await canContinue()) return null;
          if (accepted) {
            return ProactiveReplyResult(
              candidate: candidate!,
              usedSecondChannel: true,
              secondChannelAttempts: attempts,
              failures: List.unmodifiable(failures),
            );
          }
          if (attempt < FinalReplyFailurePolicy.maxGeminiAttempts) {
            await (wait ?? _wait)(FinalReplyFailurePolicy.retryDelay);
          }
        }
      }
      if (!await canContinue()) return null;
      route.recordFailure(failures.last);
      await onFallback(attempts, List.unmodifiable(failures));
    }
    // The delay or diagnostics may have yielded to a new user turn, transfer
    // or lease owner. Recheck immediately before opening the fallback request.
    if (!await canContinue()) return null;
    final candidate = await request(secondChannel: false);
    if (candidate == null || !await canContinue()) return null;
    return ProactiveReplyResult(
      candidate: candidate,
      usedSecondChannel: false,
      secondChannelAttempts: attempts,
      failures: List.unmodifiable(failures),
    );
  }

  static Future<void> _wait(Duration delay) => Future<void>.delayed(delay);
}
