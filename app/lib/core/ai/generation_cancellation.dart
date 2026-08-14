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

class GenerationCancelledByUserException implements Exception {
  const GenerationCancelledByUserException();

  @override
  String toString() => 'generation_cancelled_by_user';
}
