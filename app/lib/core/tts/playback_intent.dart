import 'tts_queue_service.dart';

abstract interface class TtsSessionFactory {
  Future<TtsQueueService> openPlaybackSession({bool? qForm, String? ownerId});
}

abstract interface class TtsPlaybackLeaseOwner {
  int? get playbackLease;
}

/// Created synchronously before translation or emotion work. Cancellation
/// cannot be undone by a later preparation result or a delayed native claim.
class PlaybackIntent {
  PlaybackIntent({required this.service, required this.isCurrent});
  final Future<TtsQueueService> service;
  final bool Function() isCurrent;
  bool cancelled = false;
  bool get valid => !cancelled && isCurrent();
  void cancel() { cancelled = true; }
  Future<int?> get lease async {
    final ready = await service;
    return ready is TtsPlaybackLeaseOwner ? (ready as TtsPlaybackLeaseOwner).playbackLease : null;
  }
}
