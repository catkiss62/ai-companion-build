import 'dart:async';
import 'dart:typed_data';

import 'tts_sentence_segmenter.dart';
import 'genie_fixed_text_segmenter.dart';
import 'tts_provider.dart';
import 'tts_queue_service.dart';
import 'tts_queued_segment_packer.dart';
import '../models/chat_language_variant.dart';
import 'tts_acoustic_segmenter.dart';
import 'tts_voice_profile.dart';

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

/// Genie speech scheduler shared by normal and overlay chat.
///
/// The important A2 behavior is generation-ahead:
///   1. split the utterance with Genie boundaries and retain punctuation;
///   2. submit the first complete unit immediately, then combine only later
///      units already waiting in the queue;
///   3. open one AudioTrack stream as soon as sentence 1 is ready;
///   4. let native prefill one second of first-segment PCM before AudioTrack.play;
///   5. append later WAV PCM to that same track while inference keeps running.
///
/// Native inference remains serialized, while generation of the next packed
/// unit overlaps playback of the current audio.
class TtsPlaybackQueue {
  TtsPlaybackQueue({
    required this.service,
    TtsSentenceSegmenter? segmenter,
    this.onStateChanged,
  }) : segmenter = segmenter ?? TtsSentenceSegmenter();

  final TtsQueueService service;
  final TtsSentenceSegmenter segmenter;
  final void Function(TtsQueueState state)? onStateChanged;

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
      phase: session.playbackActive && session.audiblePlaybackStarted
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
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final stoppedAt = await _invalidateAndStop();
    final voice = await service.resolveVoice(emotion);
    if (_generation != stoppedAt) return;
    _generation++;
    _session = _A2Session(
      token: _generation,
      manual: manual,
      ownerId: ownerId,
      emotion: emotion,
      leadIn: leadIn,
      language: language,
      voice: voice,
    );
    _streaming = true;
    _manual = manual;
    segmenter.reset();
    segmenter.configure(english: language == ChatLanguage.english);
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
    session.signalReadyEntry();
    _maybeComplete(session);
  }

  Future<void> playText(
    String text, {
    bool manual = true,
    bool segment = true,
    String? ownerId,
    TtsEmotionCue? emotion,
    Future<void>? leadIn,
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    final stoppedAt = await _invalidateAndStop();
    final voice = await service.resolveVoice(emotion);
    if (_generation != stoppedAt) return;
    _generation++;
    final session = _A2Session(
      token: _generation,
      manual: manual,
      ownerId: ownerId,
      emotion: emotion,
      leadIn: leadIn,
      language: language,
      voice: voice,
    );
    _session = session;
    _streaming = false;
    _manual = manual;
    segmenter.reset();
    segmenter.configure(english: language == ChatLanguage.english);
    _notify();

    // Full-message playback follows A2's processText order: speech-only text
    // cleanup/replacements happen before sentence splitting.
    final prepared = await service.prepareText(
      text,
      manual: manual,
      language: language,
    );
    if (!_isActive(session)) return;
    if (prepared == null || prepared.trim().isEmpty) {
      session.closed = true;
      _maybeComplete(session);
      return;
    }

    final chunks = segment
        ? GenieFixedTextSegmenter.splitFirstImmediate(prepared, language)
        : TtsAcousticSegmenter.split(prepared, language);
    for (final chunk in chunks) {
      _enqueuePrepared(session, chunk);
    }
    session.closed = true;
    _maybeComplete(session);
  }

  /// Wait until every sentence from the current A2 session has either played,
  /// failed independently, or been invalidated by stop()/a newer session.
  Future<void> waitUntilIdle() => _session?.idle.future ?? Future<void>.value();

  bool get playedAny => (_session?.completedPlaybackCount ?? 0) > 0;

  Future<void> stop() async {
    await _invalidateAndStop();
  }

  Future<int> _invalidateAndStop() async {
    _generation++;
    final stoppedAt = _generation;
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
    return stoppedAt;
  }

  void _enqueueRaw(
    _A2Session session,
    String raw, {
    required bool manual,
  }) {
    if (!_isActive(session) || raw.trim().isEmpty) return;
    session.rawPending.add(raw.trim());
    _notify();
    if (session.rawWorkerActive) return;
    session.rawWorkerActive = true;
    unawaited(_drainRawQueue(session, manual: manual));
  }

  Future<void> _drainRawQueue(
    _A2Session session, {
    required bool manual,
  }) async {
    try {
      while (_isActive(session) && session.rawPending.isNotEmpty) {
        final packed = session.rawUnitsSubmitted == 0
            ? TtsPackedPrefix(session.rawPending.first, 1)
            : TtsQueuedSegmentPacker.packPrefix(
                session.rawPending,
                session.language,
              );
        session.rawPending.removeRange(0, packed.sourceUnits);
        session.rawUnitsSubmitted += packed.sourceUnits;
        final index = session.reserve(packed.text);
        _notify();
        String? prepared;
        try {
          prepared = await service.prepareText(
            packed.text,
            manual: manual,
            language: session.language,
          );
        } catch (_) {
          prepared = null;
        }
        if (!_isActive(session)) return;
        if (prepared == null || prepared.trim().isEmpty) {
          _markGenerated(session, index, null);
          continue;
        }
        // Streaming boundaries are found before speech-only substitutions. A
        // hotword or user replacement can expand substantially, so enforce the
        // final Genie ceiling again after preparation without losing FIFO order.
        final chunks = TtsAcousticSegmenter.split(prepared, session.language);
        if (chunks.isEmpty) {
          _markGenerated(session, index, null);
          continue;
        }
        final indexes = <int>[
          index,
          for (var i = 1; i < chunks.length; i++) session.reserve(chunks[i]),
        ];
        _notify();
        for (var i = 0; i < chunks.length; i++) {
          session.textByIndex[indexes[i]] = chunks[i];
          await _generateAwaited(session, indexes[i], chunks[i]);
        }
      }
    } finally {
      if (_isActive(session)) {
        session.rawWorkerActive = false;
        // A new complete unit can arrive between the final emptiness check and
        // clearing the flag. Restart immediately without a timer.
        if (session.rawPending.isNotEmpty) {
          session.rawWorkerActive = true;
          unawaited(_drainRawQueue(session, manual: manual));
        }
        _maybeComplete(session);
        _notify();
      }
    }
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
    unawaited(_generateAwaited(session, index, text));
  }

  Future<void> _generateAwaited(
    _A2Session session,
    int index,
    String text,
  ) async {
    if (!_isActive(session)) return;
    session.generating++;
    _notify();
    Uint8List? audio;
    try {
      audio = await service.generatePrepared(
        text,
        emotion: session.emotion,
        language: session.language,
        voice: session.voice,
      );
    } catch (_) {
      audio = null;
    } finally {
      if (_isActive(session)) {
        session.generating = (session.generating - 1).clamp(0, 1 << 30).toInt();
        _markGenerated(session, index, audio);
      }
    }
  }

  void _markGenerated(_A2Session session, int index, Uint8List? audio) {
    if (!_isActive(session)) return;
    session.ready[index] = audio;
    session.signalReadyEntry();
    _startPlaybackPump(session);
    _maybeComplete(session);
    _notify();
  }

  void _startPlaybackPump(_A2Session session) {
    if (!_isActive(session) || session.playbackActive) return;
    if (!_hasReadyEntry(session) && !(session.closed && session.generating == 0)) {
      return;
    }
    session.playbackActive = true;
    unawaited(_drainPlayback(session));
  }

  bool _hasReadyEntry(_A2Session session) {
    var index = session.nextToPlay;
    while (index < session.total && session.ready.containsKey(index)) {
      final value = session.ready[index];
      if (value != null && value.isNotEmpty) return true;
      if (value == null || value.isEmpty) {
        index++;
        continue;
      }
    }
    return false;
  }

  Future<void> _drainPlayback(_A2Session session) async {
    var streamStarted = false;
    try {
      while (_isActive(session)) {
        while (_isActive(session) &&
            session.nextToPlay < session.total &&
            session.ready.containsKey(session.nextToPlay)) {
          final index = session.nextToPlay++;
          final audio = session.ready.remove(index);
          final text = session.textByIndex.remove(index) ?? '';
          if (audio == null || audio.isEmpty) continue;
          if (!streamStarted) {
            await session.waitForLeadIn();
            if (!_isActive(session)) return;
            await service.beginPlayback();
            if (!_isActive(session)) return;
            streamStarted = true;
          }
          _current = text;
          _notify();
          await service.enqueuePlayback(audio);
          if (!session.audiblePlaybackStarted) {
            session.audiblePlaybackStarted = true;
            _notify();
          }
          session.completedPlaybackCount++;
        }
        if (!_isActive(session)) return;
        final allSubmitted = session.closed &&
            !session.rawWorkerActive &&
            session.rawPending.isEmpty &&
            session.generating == 0 &&
            session.nextToPlay >= session.total;
        if (allSubmitted) {
          if (streamStarted) await service.finishPlayback();
          break;
        }
        await session.waitForReadyEntry();
      }
    } catch (_) {
      // One failed native stream is optional and must not poison chat.
      try {
        await service.stop();
      } catch (_) {}
    } finally {
      if (_isActive(session)) {
        session.playbackActive = false;
        session.audiblePlaybackStarted = false;
        _current = '';
        _notify();
        _maybeComplete(session);
      }
    }
  }

  void _maybeComplete(_A2Session session) {
    if (!_isActive(session) || session.idle.isCompleted) return;
    final done = session.closed &&
        !session.playbackActive &&
        !session.rawWorkerActive &&
        session.rawPending.isEmpty &&
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
    required this.language,
    required this.voice,
  });

  final int token;
  final bool manual;
  final String? ownerId;
  final TtsEmotionCue? emotion;
  final Future<void>? leadIn;
  final ChatLanguage language;
  final TtsVoiceMode voice;
  final Completer<void> idle = Completer<void>();
  final Map<int, Uint8List?> ready = <int, Uint8List?>{};
  final Map<int, String> textByIndex = <int, String>{};

  final List<String> rawPending = <String>[];
  bool rawWorkerActive = false;
  int rawUnitsSubmitted = 0;
  int total = 0;
  int nextToPlay = 0;
  int generating = 0;
  bool playbackActive = false;
  bool audiblePlaybackStarted = false;
  int completedPlaybackCount = 0;
  bool closed = false;
  bool _leadInConsumed = false;
  Completer<void> _readyEntry = Completer<void>();

  Future<void> waitForLeadIn() async {
    if (_leadInConsumed) return;
    _leadInConsumed = true;
    try {
      await Future.wait<void>(<Future<void>>[
        if (leadIn != null) leadIn!,
      ]);
    } catch (_) {
      // A decorative cue failure never blocks companion speech.
    }
  }

  int reserve(String text) {
    final index = total++;
    textByIndex[index] = text;
    return index;
  }

  void signalReadyEntry() {
    final signal = _readyEntry;
    _readyEntry = Completer<void>();
    if (!signal.isCompleted) signal.complete();
  }

  Future<void> waitForReadyEntry() => _readyEntry.future;
}
