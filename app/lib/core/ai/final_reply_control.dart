import 'dart:async';
import 'generation_cancellation.dart';

/// One user turn. Cancels expression only; planning/tools keep their ownership.
class FinalReplyControl {
  static const settingKey = 'generation_manual_deepseek_job_v1';
  final GenerationCancellationToken _choice = GenerationCancellationToken();
  bool _sealed = false;
  void Function()? onChanged;

  bool get requested => _choice.isCancelled;
  bool get accepting => !_sealed && !requested;
  Future<void> get whenRequested => _choice.whenCancelled;

  bool requestDeepSeek() {
    if (!accepting) return false;
    _choice.cancel();
    onChanged?.call();
    return true;
  }

  GenerationCancellationToken secondChannelToken(
      GenerationCancellationToken wholeTurn) {
    final token = GenerationCancellationToken();
    if (requested || wholeTurn.isCancelled) token.cancel();
    unawaited(whenRequested.then((_) => token.cancel()));
    unawaited(wholeTurn.whenCancelled.then((_) => token.cancel()));
    return token;
  }

  void seal() {
    _sealed = true;
    onChanged?.call();
  }
}
