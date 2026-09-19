import 'dart:async';

/// In-memory cancellation signal for one assistant-generation attempt.
///
/// Durable cancellation is owned by SQLite; this token exists to make the
/// current HTTP stream and its UI/TTS consumers stop immediately.
class GenerationCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const GenerationCancelledByUserException();
  }
}

/// Lets a multi-stage provider stop awaiting an in-flight operation even when
/// the underlying SDK does not expose an abort handle. Callers must still
/// fence all durable writes after this returns by checking the same token.
Future<T> cancelWithToken<T>(
  Future<T> operation,
  GenerationCancellationToken? token,
) {
  if (token == null) return operation;
  token.throwIfCancelled();
  return Future<T>.any(<Future<T>>[
    operation,
    token.whenCancelled.then<T>((_) {
      throw const GenerationCancelledByUserException();
    }),
  ]);
}

class GenerationCancelledByUserException implements Exception {
  const GenerationCancelledByUserException();

  @override
  String toString() => 'generation_cancelled_by_user';
}

/// The current provider request was stopped because this runtime is no longer
/// allowed to write (for example while a backup freezes state). Unlike an
/// explicit user Stop, this must preserve the durable user turn for recovery.
class GenerationSuspendedByRuntimeGateException implements Exception {
  const GenerationSuspendedByRuntimeGateException();

  @override
  String toString() => 'generation_suspended_by_runtime_gate';
}
