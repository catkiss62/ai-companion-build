export 'playback_intent.dart';
import 'playback_intent.dart';
import 'dart:async';
import 'dart:typed_data';

import 'tts_sentence_segmenter.dart';
import 'genie_fixed_text_segmenter.dart';
import 'tts_provider.dart';
import 'tts_queue_service.dart';
import 'tts_queued_segment_packer.dart';
import '../models/chat_language_variant.dart';
import 'tts_acoustic_segmenter.dart';
import 'tts_text_processor.dart';
import 'spoken_text_index.dart';
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
  PlaybackIntent? _intent;
  PlaybackIntent createIntent({bool? formForPlayback, String? ownerId,
      Future<bool> Function()? canContinue}) {
    final stopped = _invalidateAndStop();
    unawaited(stopped);
    late PlaybackIntent intent;
    Future<TtsQueueService> open() => service is TtsSessionFactory
        ? (service as TtsSessionFactory).openPlaybackSession(qForm: formForPlayback, ownerId: ownerId)
        : stopped.then((_) => service);
    final ready = canContinue == null ? open() : Future<void>.value().then((_) async {
      if (!await intent.refresh()) throw StateError('playback_superseded');
      return open();
    });
    intent = PlaybackIntent(service: ready, isCurrent: () => identical(_intent, intent),
        canContinue: canContinue);
    _intent = intent;
    // A late claim may only release itself; it must never stop a newer owner.
    unawaited(ready.then((owned) async { if (!intent.valid) await owned.stop(); }).catchError((Object _) {}));
    return intent;
  }
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
    PlaybackIntent? intent,
    bool? formForPlayback,
  }) async {
    final requested = intent ?? createIntent(formForPlayback: formForPlayback, ownerId: ownerId);
    if (!await requested.refresh()) return;
    final activeService = await requested.service;
    if (!await requested.refresh()) { await _releasePrepared(requested, activeService); return; }
    final voice = await activeService.resolveVoice(emotion);
    if (!await requested.refresh()) { await _releasePrepared(requested, activeService); return; }
    _session = _A2Session(
      token: _generation,
      service: activeService,
      intent: requested,
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

  /// Adds a sentence whose visible role has already been established by a
  /// streaming surface. Immersive rooms use this so narration can be voiced
  /// gently while quoted dialogue keeps the selected/automatic voice.
  void addStructuredUnit(String text, {required TtsSpeechRole role}) {
    final session = _session;
    if (!_streaming || text.trim().isEmpty || session == null) return;
    _enqueueRaw(session, text, manual: _manual, role: role);
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
    PlaybackIntent? intent,
    bool? formForPlayback,
  }) async {
    final requested = intent ?? createIntent(formForPlayback: formForPlayback, ownerId: ownerId);
    if (!await requested.refresh()) return;
    final activeService = await requested.service;
    if (!await requested.refresh()) { await _releasePrepared(requested, activeService); return; }
    final voice = await activeService.resolveVoice(emotion);
    if (!await requested.refresh()) { await _releasePrepared(requested, activeService); return; }
    final session = _A2Session(
      token: _generation,
      service: activeService,
      intent: requested,
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
    final prepared = await activeService.prepareUnits(
      text,
      manual: manual,
      language: language,
    );
    if (!await _refreshSession(session)) return;
    if (prepared.isEmpty) {
      session.closed = true;
      _maybeComplete(session);
      return;
    }

    session.presentationFingerprint = SpokenTextIndex.fingerprint(prepared.map((u) => u.text).join());
    for (final unit in prepared) {
      final chunks = segment
          ? GenieFixedTextSegmenter.splitFirstImmediate(unit.text, language)
          : TtsAcousticSegmenter.split(unit.text, language);
      final voice = unit.role == TtsSpeechRole.narration
          ? TtsVoiceMode.gentle
          : session.voice;
      for (final chunk in chunks) {
        _enqueuePrepared(session, chunk, voice: voice);
      }
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
    final oldIntent = _intent;
    _intent = null;
    oldIntent?.cancel();
    final old = _session;
    _session = null;
    _current = '';
    if (old != null && !old.idle.isCompleted) old.idle.complete();
    _notify();
    try {
      if (old != null) { await old.service.stop(); }
      else if (oldIntent != null) { await (await oldIntent.service).stop(); }
      else if (service is! TtsSessionFactory) { await service.stop(); }
    } catch (_) {
      // Voice is optional. A native shutdown error must not poison chat.
    }
    return stoppedAt;
  }

  void _enqueueRaw(
    _A2Session session,
    String raw, {
    required bool manual,
    TtsSpeechRole? role,
  }) {
    if (!_isActive(session) || raw.trim().isEmpty) return;
    session.rawPending.add(_RawUnit(raw.trim(), role));
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
        final role = session.rawPending.first.role;
        final compatible = session.rawPending
            .takeWhile((item) => item.role == role)
            .map((item) => item.text)
            .toList(growable: false);
        final packed = session.rawUnitsSubmitted == 0
            ? TtsPackedPrefix(compatible.first, 1)
            : TtsQueuedSegmentPacker.packPrefix(compatible, session.language);
        session.rawPending.removeRange(0, packed.sourceUnits);
        session.rawUnitsSubmitted += packed.sourceUnits;
        final index = session.reserve(packed.text);
        _notify();
        TtsPreparedUnit? prepared;
        try {
          if (role == null) {
            final text = await session.service.prepareText(
              packed.text,
              manual: manual,
              language: session.language,
            );
            if (text != null && text.trim().isNotEmpty) {
              prepared = TtsPreparedUnit(
                text: text,
                role: TtsSpeechRole.dialogue,
              );
            }
          } else {
            prepared = await session.service.prepareUnit(
              packed.text,
              role: role,
              manual: manual,
              language: session.language,
            );
          }
        } catch (_) {
          prepared = null;
        }
        if (!_isActive(session)) return;
        if (prepared == null || prepared.text.trim().isEmpty) {
          _markGenerated(session, index, null);
          continue;
        }
        // Streaming boundaries are found before speech-only substitutions. A
        // hotword or user replacement can expand substantially, so enforce the
        // final Genie ceiling again after preparation without losing FIFO order.
        final chunks =
            TtsAcousticSegmenter.split(prepared.text, session.language);
        if (chunks.isEmpty) {
          _markGenerated(session, index, null);
          continue;
        }
        final voice = prepared.role == TtsSpeechRole.narration
            ? TtsVoiceMode.gentle
            : session.voice;
        session.voiceByIndex[index] = voice;
        final indexes = <int>[
          index,
          for (var i = 1; i < chunks.length; i++)
            session.reserve(chunks[i], voice: voice),
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

  void _enqueuePrepared(
    _A2Session session,
    String text, {
    required TtsVoiceMode voice,
  }) {
    final cleaned = text.trim();
    if (!_isActive(session) || cleaned.isEmpty) return;
    final index = session.reserve(cleaned, voice: voice);
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
    if (!await _refreshSession(session)) return;
    session.generating++;
    _notify();
    Uint8List? audio;
    try {
      final voice = session.voiceByIndex[index] ?? session.voice;
      audio = await session.service.generatePrepared(
        text,
        emotion: session.emotion,
        language: session.language,
        voice: voice,
        segmentIndex: index,
      );
    } catch (_) {
      audio = null;
    } finally {
      if (await _refreshSession(session)) {
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
            if (!await _refreshSession(session)) return;
            await session.service.beginPlayback();
            if (!await _refreshSession(session)) return;
            streamStarted = true;
          }
          if (!await _refreshSession(session)) return;
          _current = text;
          _notify();
          final voice = session.voiceByIndex.remove(index) ?? session.voice;
          final activeService = session.service;
          final offset = session.presentationOffsets.remove(index);
          if (activeService is TtsPresentationQueueService && offset != null &&
              session.presentationFingerprint.isNotEmpty) {
            await (activeService as TtsPresentationQueueService).enqueuePresented(audio,
              speedMultiplier: voice == TtsVoiceMode.gentle ? 1.2 : 1.0,
              textStart: offset, textLength: SpokenTextIndex.normalize(text).length,
              fingerprint: session.presentationFingerprint, language: session.language.key);
          } else {
            await session.service.enqueuePlayback(audio,
              speedMultiplier: voice == TtsVoiceMode.gentle ? 1.2 : 1.0);
          }
          if (!session.audiblePlaybackStarted) {
            session.audiblePlaybackStarted = true;
            _notify();
          }
          if (!_isActive(session)) return;
        }
        if (!_isActive(session)) return;
        final allSubmitted = session.closed &&
            !session.rawWorkerActive &&
            session.rawPending.isEmpty &&
            session.generating == 0 &&
            session.nextToPlay >= session.total;
        if (allSubmitted) {
          if (streamStarted) {
            await session.service.finishPlayback();
            if (_isActive(session)) session.completedPlaybackCount = session.nextToPlay;
          }
          break;
        }
        await session.waitForReadyEntry();
      }
    } catch (_) {
      // One failed native stream is optional and must not poison chat.
      try {
        if (_isActive(session)) await session.service.stop();
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
    if (session.completedPlaybackCount == 0 && session.service is TtsPlaybackLeaseOwner) unawaited(session.service.stop().catchError((Object _) {}));
    _current = '';
    _notify();
  }

  bool _isActive(_A2Session session) =>
      identical(_session, session) && session.token == _generation && session.intent.valid;

  Future<bool> _refreshSession(_A2Session session) async {
    if (await session.intent.refresh() && _isActive(session)) return true;
    if (identical(_session, session)) await _invalidateAndStop();
    return false;
  }

  Future<void> _releasePrepared(PlaybackIntent requested, TtsQueueService owned) async {
    // A stale preparation may only stop its own native lease. An unscoped
    // service can be shared with a newer intent and must not receive old Stop.
    if (owned is TtsPlaybackLeaseOwner && (owned as TtsPlaybackLeaseOwner).playbackLease != null) {
      await owned.stop();
    } else if (identical(_intent, requested)) {
      await _invalidateAndStop();
    }
  }

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
    required this.service,
    required this.intent,
  });

  final TtsQueueService service;
  final PlaybackIntent intent;
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
  final Map<int, TtsVoiceMode> voiceByIndex = <int, TtsVoiceMode>{};
  final Map<int, int> presentationOffsets = <int, int>{};
  String presentationFingerprint = '';
  int presentationCharacters = 0;

  final List<_RawUnit> rawPending = <_RawUnit>[];
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
        if (leadIn != null) Future.any<void>([leadIn!, idle.future]),
      ]);
    } catch (_) {
      // A decorative cue failure never blocks companion speech.
    }
  }

  int reserve(String text, {TtsVoiceMode? voice}) {
    final index = total++;
    textByIndex[index] = text;
    if (presentationFingerprint.isNotEmpty) {
      presentationOffsets[index] = presentationCharacters;
      presentationCharacters += SpokenTextIndex.normalize(text).length;
    }
    if (voice != null) voiceByIndex[index] = voice;
    return index;
  }

  void signalReadyEntry() {
    final signal = _readyEntry;
    _readyEntry = Completer<void>();
    if (!signal.isCompleted) signal.complete();
  }

  Future<void> waitForReadyEntry() => _readyEntry.future;
}

class _RawUnit {
  const _RawUnit(this.text, this.role);

  final String text;
  final TtsSpeechRole? role;
}
