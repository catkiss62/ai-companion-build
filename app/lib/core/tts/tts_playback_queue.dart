import 'dart:async';

import 'tts_sentence_segmenter.dart';
import 'tts_provider.dart';
import 'tts_queue_service.dart';

enum TtsPlaybackPhase { idle, synthesizing, playing }

class TtsQueueState {
  const TtsQueueState({
    required this.running,
    required this.pending,
    required this.currentText,
    required this.phase,
    required this.ownerId,
  });

  final bool running;
  final int pending;
  final String currentText;
  final TtsPlaybackPhase phase;
  final String? ownerId;

  static const idle = TtsQueueState(
    running: false,
    pending: 0,
    currentText: '',
    phase: TtsPlaybackPhase.idle,
    ownerId: null,
  );
}

/// Meju A2-equivalent speech scheduler shared by normal and overlay chat.
///
/// The important A2 behavior is generation-ahead:
///   1. split the utterance with A2 boundaries;
///   2. submit every sentence to native generation without awaiting playback;
///   3. start playing as soon as sentence 1 is ready;
///   4. let the native generation worker prepare later WAVs while AudioTrack is
///      still playing the current sentence;
///   5. when another WAV is already queued, keep the original ~200 ms gap.
///
/// This deliberately does NOT serialize "generate + play" sentence-by-sentence.
class TtsPlaybackQueue {
  TtsPlaybackQueue({
    required this.service,
    TtsSentenceSegmenter? segmenter,
    this.onStateChanged,
    this.interSentenceGap = const Duration(milliseconds: 200),
  }) : segmenter = segmenter ?? TtsSentenceSegmenter();

  final TtsQueueService service;
  final TtsSentenceSegmenter segmenter;
  final void Function(TtsQueueState state)? onStateChanged;
  final Duration interSentenceGap;

  int _generation = 0;
  _A2Session? _session;
  bool _streaming = false;
  bool _manual = false;
  String _current = '';

  TtsQueueState get state {
    final session = _session;
    if (session == null || session.idle.isCompleted) return TtsQueueState.idle;
    final pending = (session.total - session.nextToPlay).clamp(0, 1 << 30).toInt();
    return TtsQueueState(
      running: true,
      pending: pending,
      currentText: _current,
      phase: session.playing
          ? TtsPlaybackPhase.playing
          : TtsPlaybackPhase.synthesizing,
      ownerId: session.ownerId,
    );
  }

  Future<void> beginStream({
    bool manual = false,
    String? ownerId,
    TtsEmotionCue? emotion,
    Future<void>? leadIn,
  }) async {
    await stop();
    _generation++;
    _session = _A2Session(
      token: _generation,
      manual: manual,
      ownerId: ownerId,
      emotion: emotion,
      leadIn: leadIn,
    );
    _streaming = true;
    _manual = manual;
    segmenter.reset();
    _notify();
  }

  void addDelta(String delta) {
    final session = _session;
    if (!_streaming || delta.isEmpty || session == null) return;
    for (final raw in segmenter.add(delta)) {
      _enqueueRaw(session, raw, manual: _manual);
    }
  }

  void endStream() {
    final session = _session;
    if (!_streaming || session == null) return;
    for (final raw in segmenter.flush()) {
      _enqueueRaw(session, raw, manual: _manual);
    }
    _streaming = false;
    session.closed = true;
    _maybeComplete(session);
  }

  Future<void> playText(
    String text, {
    bool manual = true,
    bool segment = true,
    String? ownerId,
    TtsEmotionCue? emotion,
    Future<void>? leadIn,
  }) async {
    await stop();
    _generation++;
    final session = _A2Session(
      token: _generation,
      manual: manual,
      ownerId: ownerId,
      emotion: emotion,
      leadIn: leadIn,
    );
    _session = session;
    _streaming = false;
    _manual = manual;
    segmenter.reset();
    _notify();

    // Full-message playback follows A2's processText order: speech-only text
    // cleanup/replacements happen before sentence splitting.
    final prepared = await service.prepareText(text, manual: manual);
    if (!_isActive(session)) return;
    if (prepared == null || prepared.trim().isEmpty) {
      session.closed = true;
      _maybeComplete(session);
      return;
    }

    final chunks = segment
        ? <String>[...segmenter.add(prepared), ...segmenter.flush()]
        : <String>[prepared.trim()];
    for (final chunk in chunks) {
      _enqueuePrepared(session, chunk);
    }
    session.closed = true;
    _maybeComplete(session);
  }

  /// Wait until every sentence from the current A2 session has either played,
  /// failed independently, or been invalidated by stop()/a newer session.
  Future<void> waitUntilIdle() => _session?.idle.future ?? Future<void>.value();

  Future<void> stop() async {
    _generation++;
    _streaming = false;
    _manual = false;
    segmenter.reset();
    final old = _session;
    _session = null;
    _current = '';
    if (old != null && !old.idle.isCompleted) old.idle.complete();
    _notify();
    try {
      await service.stop();
    } catch (_) {
      // Voice is optional. A native shutdown error must not poison chat.
    }
  }

  void _enqueueRaw(
    _A2Session session,
    String raw, {
    required bool manual,
  }) {
    if (!_isActive(session) || raw.trim().isEmpty) return;
    final index = session.reserve(raw.trim());
    _notify();

    // Preserve input order while doing async settings/text preparation. Once a
    // sentence is prepared, generation is launched and NOT awaited, matching
    // A2's generateTTS(...).then(...) fan-out behavior.
    session.prepareTail = session.prepareTail.then((_) async {
      if (!_isActive(session)) return;
      String? prepared;
      try {
        prepared = await service.prepareText(raw, manual: manual);
      } catch (_) {
        prepared = null;
      }
      if (!_isActive(session)) return;
      if (prepared == null || prepared.trim().isEmpty) {
        _markGenerated(session, index, null);
        return;
      }
      session.textByIndex[index] = prepared.trim();
      _launchGeneration(session, index, prepared.trim());
    });
  }

  void _enqueuePrepared(_A2Session session, String text) {
    final cleaned = text.trim();
    if (!_isActive(session) || cleaned.isEmpty) return;
    final index = session.reserve(cleaned);
    _notify();
    _launchGeneration(session, index, cleaned);
  }

  void _launchGeneration(_A2Session session, int index, String text) {
    if (!_isActive(session)) return;
    session.generating++;
    _notify();
    unawaited(() async {
      String? audio;
      try {
        audio = await service.generatePrepared(
          text,
          emotion: session.emotion,
        );
      } catch (_) {
        audio = null;
      } finally {
        if (_isActive(session)) {
          session.generating = (session.generating - 1).clamp(0, 1 << 30).toInt();
          _markGenerated(session, index, audio);
        }
      }
    }());
  }

  void _markGenerated(_A2Session session, int index, String? audio) {
    if (!_isActive(session)) return;
    session.ready[index] = audio;
    _pump(session);
    _maybeComplete(session);
    _notify();
  }

  void _pump(_A2Session session) {
    if (!_isActive(session) || session.playing) return;

    while (session.nextToPlay < session.total &&
        session.ready.containsKey(session.nextToPlay)) {
      final index = session.nextToPlay++;
      final audio = session.ready.remove(index);
      final text = session.textByIndex.remove(index) ?? '';
      if (audio == null || audio.isEmpty) continue;

      session.playing = true;
      _current = text;
      _notify();
      unawaited(_playOne(session, audio));
      return;
    }
    _maybeComplete(session);
  }

  Future<void> _playOne(_A2Session session, String audio) async {
    try {
      await session.waitForLeadIn();
      if (!_isActive(session)) return;
      await service.playPrepared(audio);
    } catch (_) {
      // A2 treats one sentence failure as local: later generated speech should
      // still be allowed to continue.
    }
    if (!_isActive(session)) return;

    session.playing = false;
    _current = '';
    _notify();

    // Original GenieTTSManager waits ~200 ms only when another generated item
    // is already waiting in audioQueue at playback completion. If generation
    // has not caught up yet, the next completed sentence starts immediately.
    if (_hasPlayableReady(session)) {
      await Future<void>.delayed(interSentenceGap);
      if (!_isActive(session)) return;
    }
    _pump(session);
  }

  bool _hasPlayableReady(_A2Session session) {
    var index = session.nextToPlay;
    while (index < session.total && session.ready.containsKey(index)) {
      final value = session.ready[index];
      if (value != null && value.isNotEmpty) return true;
      index++;
    }
    return false;
  }

  void _maybeComplete(_A2Session session) {
    if (!_isActive(session) || session.idle.isCompleted) return;
    final done = session.closed &&
        !session.playing &&
        session.generating == 0 &&
        session.nextToPlay >= session.total;
    if (!done) return;
    session.idle.complete();
    _current = '';
    _notify();
  }

  bool _isActive(_A2Session session) =>
      identical(_session, session) && session.token == _generation;

  void _notify() => onStateChanged?.call(state);
}

class _A2Session {
  _A2Session({
    required this.token,
    required this.manual,
    required this.ownerId,
    required this.emotion,
    required this.leadIn,
  });

  final int token;
  final bool manual;
  final String? ownerId;
  final TtsEmotionCue? emotion;
  final Future<void>? leadIn;
  final Completer<void> idle = Completer<void>();
  final Map<int, String?> ready = <int, String?>{};
  final Map<int, String> textByIndex = <int, String>{};

  Future<void> prepareTail = Future<void>.value();
  int total = 0;
  int nextToPlay = 0;
  int generating = 0;
  bool playing = false;
  bool closed = false;
  bool _leadInConsumed = false;

  Future<void> waitForLeadIn() async {
    if (_leadInConsumed) return;
    _leadInConsumed = true;
    try {
      await leadIn;
    } catch (_) {
      // A decorative cue failure never blocks companion speech.
    }
  }

  int reserve(String text) {
    final index = total++;
    textByIndex[index] = text;
    return index;
  }
}
