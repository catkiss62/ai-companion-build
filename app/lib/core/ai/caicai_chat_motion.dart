import 'dart:async';
import 'dart:convert';
import '../database/app_database.dart';
import '../tts/native_tts_provider.dart';
import '../tts/spoken_text_index.dart';
import '../tts/tts_text_processor.dart';
import '../../widgets/caicai_live2d_stage.dart';
import 'caicai_motion_planner.dart';
import 'speech_performance_plan.dart';
import 'generation_cancellation.dart';

/// Immediate and real-audio performances share one stage owner.
/// Audio never waits for cosmetic planning; playback never purchases a call.
class CaicaiChatMotion {
  CaicaiChatMotion({
    Future<Object?> Function(String, Object?)? command,
    Future<Map<Object?, Object?>> Function()? playbackSnapshot,
    Future<String?> Function(String)? setting,
    this.planner = const CaicaiMotionPlanner(),
    this.pollInterval = const Duration(milliseconds: 200),
  }) : _command = command ?? ((method, args) => CaicaiLive2DService.command(method, args)),
       _snapshot = playbackSnapshot ?? NativeTtsProvider.instance.playbackSnapshot,
       _setting = setting ?? AppDatabase.instance.getSetting;
  final CaicaiMotionPlanner planner;
  final Duration pollInterval;
  final Future<Object?> Function(String, Object?) _command;
  final Future<Map<Object?, Object?>> Function() _snapshot;
  final Future<String?> Function(String) _setting;
  GenerationCancellationToken? _token;
  String? _lastIdentity, _messageId;
  Map<String, Object?>? _owner;
  Timer? _timer;
  bool _polling = false, _audioSeen = false, _planReady = false;
  List<Map<String, dynamic>> _speech = const [];
  Map<String, dynamic> _parameters = const {};
  String _fingerprint = '', _baseEmotion = 'normal', _spokenEmotion = 'normal';
  int? _speechLease;
  int? _observedLease;
  String? _lastCueKey;
  int _lastHead = -1;
  final _clock = Stopwatch()..start();
  int _lastAdvance = 0;
  int _presentationEpoch = 0;
  int _playbackEpoch = 0;
  int _modelRevision = 0;
  bool _resuming = false;
  bool Function()? _canContinue;

  Future<void> resume({required String id, required String reply, required int revision,
      bool Function()? canContinue}) async {
    if (CaicaiLive2DService.activeProfile != 'caicai' || canContinue?.call() == false) return;
    if (_resuming || _owner != null || _speech.isEmpty ||
        _modelRevision != CaicaiLive2DService.revision.value ||
        _lastIdentity != '$id:$revision:${SpokenTextIndex.fingerprint(reply)}') return;
    _resuming = true;
    _canContinue = canContinue;
    final epoch = ++_presentationEpoch;
    final token = GenerationCancellationToken();
    _token = token;
    try {
      final claimed = await _command('claimMotion', null);
      if (claimed is! Map) return;
      final owner = Map<String, Object?>.from(claimed);
      if (epoch != _presentationEpoch || token.isCancelled || _canContinue?.call() == false) {
        await _command('stopMotion', {'_motion_owner': owner}); return;
      }
      _owner = owner;
      _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll(token, owner)));
    } catch (_) { /* A hidden/replaced stage never buys a new plan. */ }
    finally { _resuming = false; }
  }

  void playbackChanged({required String? ownerId, required bool running}) {
    final owner = _owner;
    final token = _token;
    if (owner == null || token == null || !_current(token, owner)) return;
    if (running && ownerId == _messageId && _planReady && _speech.isNotEmpty) {
      _timer ??= Timer.periodic(pollInterval, (_) => unawaited(_poll(token, owner)));
    } else if (!running || ownerId != _messageId) {
      _playbackEpoch++;
      if (_planReady) { _timer?.cancel(); _timer = null; }
      unawaited(_releaseSpeech(owner));
    }
  }

  bool _current(GenerationCancellationToken token, Map<String, Object?> owner) =>
      identical(_token, token) && !token.isCancelled && identical(_owner, owner) &&
      _canContinue?.call() != false && CaicaiLive2DService.activeProfile == 'caicai' &&
      _modelRevision == CaicaiLive2DService.revision.value;
  Future<void> _releaseSpeech(Map<String, Object?> owner) async {
    final lease = _speechLease;
    _speechLease = null;
    if (lease == null) return;
    try { await _command('stopSpeechMotion', {'lease': lease, '_motion_owner': owner}); } catch (_) {}
  }
  Future<void> stop() async {
    _presentationEpoch++;
    await _clear();
  }
  Future<void> _clear() async {
    _token?.cancel(); _token = null;
    _timer?.cancel(); _timer = null;
    final owner = _owner; _owner = null;
    if (owner != null) {
      await _releaseSpeech(owner);
      try { await _command('stopMotion', {'_motion_owner': owner}); } catch (_) {}
    }
  }

  Future<void> present({required String id, required String user, required String reply,
      required String emotion, int revision = 0, bool Function()? canContinue}) async {
    if (CaicaiLive2DService.activeProfile != 'caicai' || canContinue?.call() == false) return;
    final identity = '$id:$revision:${SpokenTextIndex.fingerprint(reply)}';
    if (_lastIdentity == identity) return;
    final epoch = ++_presentationEpoch;
    _lastIdentity = identity;
    await _clear();
    if (epoch != _presentationEpoch) return;
    if (CaicaiLive2DService.activeProfile != 'caicai' || canContinue?.call() == false) return;
    _canContinue = canContinue;
    _lastIdentity = identity; _messageId = id;
    _modelRevision = CaicaiLive2DService.revision.value;
    _audioSeen = false; _planReady = false; _speech = const []; _fingerprint = '';
    _speechLease = null; _observedLease = null; _lastCueKey = null; _lastHead = -1;
    _baseEmotion = CaicaiLive2DService.nativeEmotionId(emotion);
    _spokenEmotion = _baseEmotion;
    final token = GenerationCancellationToken();
    _token = token;
    try {
      final claimed = await _command('claimMotion', null);
      if (claimed is! Map) return;
      final owner = Map<String, Object?>.from(claimed);
      if (!identical(_token, token) || token.isCancelled || _canContinue?.call() == false) {
        await _command('stopMotion', {'_motion_owner': owner}); return;
      }
      _owner = owner;
      await _command('setEmotion', {'event':id, 'emotion': _baseEmotion, '_motion_owner': owner});
      if (!_current(token, owner)) return;
      if (await _setting('caicai_jev_motion') == '0') return;
      final settings = await Future.wait([
        _setting('tts_enabled'), _setting('auto_tts'), _setting('tts_language'),
        _setting('tts_reading_scope'), _setting('tts_replacements_json'), _setting('tts_volume'),
      ]);
      if (!_current(token, owner)) return;
      var spoken = '';
      if (settings[0] != '0' && settings[1] != '0' &&
          (settings[2] == null || settings[2] == 'zh') &&
          (double.tryParse(settings[5] ?? '') ?? 1) > 0) {
        const processor = TtsTextProcessor();
        spoken = processor.processUnits(reply,
          scope: TtsReadingScope.fromSetting(settings[3]),
          replacements: processor.decodeReplacementJson(settings[4])).map((u) => u.text).join();
      }
      _fingerprint = spoken.isEmpty ? '' : SpokenTextIndex.fingerprint(spoken);
      if (spoken.isNotEmpty) _timer = Timer.periodic(pollInterval,
          (_) => unawaited(_poll(token, owner)));
      final raw = await _command('parameters', null);
      if (!_current(token, owner)) return;
      if (raw is! String) { _timer?.cancel(); _timer = null; return; }
      _parameters = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final plan = await planner.plan(user: user, reply: reply, emotion: emotion,
        parameters: _parameters, spokenText: spoken, cancellationToken: token);
      if (!_current(token, owner)) return;
      _planReady = true;
      if (plan == null) { _timer?.cancel(); _timer = null; return; }
      final chosen = plan['emotion']?.toString() ?? '';
      if (chosen.isNotEmpty) _baseEmotion = chosen;
      _spokenEmotion = _baseEmotion;
      _speech = (plan['speech'] as List? ?? const []).whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s)).toList();
      if (!_audioSeen) {
        if (chosen.isNotEmpty) await _command('setEmotion',
            {'event':id, 'emotion': chosen, '_motion_owner': owner});
        if (!_current(token, owner)) return;
        await _command('motionPlan', {...plan, '_motion_owner': owner});
      }
      if (_speech.isEmpty) { _timer?.cancel(); _timer = null; }
    } on GenerationCancelledByUserException {
      return;
    } catch (_) {
      if (identical(_token, token)) { _timer?.cancel(); _timer = null; }
    }
  }

  Future<void> _poll(GenerationCancellationToken token, Map<String, Object?> owner) async {
    if (identical(_token, token) && _canContinue?.call() == false) {
      await stop(); return;
    }
    if (_polling || !_current(token, owner)) return;
    if (_modelRevision != CaicaiLive2DService.revision.value) { await stop(); return; }
    _polling = true;
    final playbackEpoch = _playbackEpoch;
    try {
      final state = await _snapshot().timeout(const Duration(seconds: 1));
      if (!_current(token, owner) || playbackEpoch != _playbackEpoch) return;
      final lease = (state['lease'] as num?)?.toInt();
      final ours = state['message_id'] == _messageId && lease != null && lease >= 0;
      if (ours && lease != _observedLease) {
        _observedLease = lease; _lastHead = -1; _spokenEmotion = _baseEmotion;
      }
      if (ours && state['phase'] == 'playing' &&
          state['spoken_fingerprint'] == _fingerprint) _audioSeen = true;
      final head = (state['playhead'] as num?)?.toInt() ?? -1;
      if (head != _lastHead) { _lastHead = head; _lastAdvance = _clock.elapsedMilliseconds; }
      final playing = ours && state['phase'] == 'playing' && state['playing'] == true &&
          state['audible'] == true && state['spoken_language'] == 'zh' &&
          state['spoken_fingerprint'] == _fingerprint &&
          _clock.elapsedMilliseconds - _lastAdvance < 650;
      final position = state['spoken_position'];
      if (!playing || position is! num || _speech.isEmpty) {
        await _releaseSpeech(owner);
        if (_planReady && (!ours || state['phase'] == 'idle')) {
          _timer?.cancel(); _timer = null;
        }
        return;
      }
      final index = _speech.indexWhere((s) => position >= (s['start'] as num) && position < (s['end'] as num));
      if (index < 0) { await _releaseSpeech(owner); return; }
      final cue = _speech[index];
      final key = '$lease:$index';
      final changed = key != _lastCueKey;
      // A late attach or muted interval may have skipped earlier cues. Resolve
      // "keep" from the plan prefix, rather than only previously rendered cues.
      _spokenEmotion = _baseEmotion;
      for (var i = 0; i <= index; i++) {
        final emotion = _speech[i]['emotion']?.toString() ?? '';
        if (emotion.isNotEmpty) {
          _spokenEmotion = CaicaiLive2DService.nativeEmotionId(emotion);
        }
      }
      _speechLease = lease;
      final start = (cue['start'] as num).toDouble(), end = (cue['end'] as num).toDouble();
      final animate = changed && position - start < ((end - start) * .25).clamp(3, 12);
      _lastCueKey = key;
      final accepted = await _command('speechCue', {
        'lease': lease, 'cue': key, 'emotion': _spokenEmotion,
        'frames': animate ? SpeechPerformancePlan.frames(cue['delivery']?.toString() ?? 'hold', _parameters) : const [],
        'animate': animate,
        'face': cue['face']?.toString() ?? '',
        'wink': cue['wink']?.toString() ?? '',
        'action': cue['action']?.toString() ?? '',
        '_motion_owner': owner,
      });
      if (accepted == false && _current(token, owner)) await stop();
    } catch (_) { if (_current(token, owner)) await _releaseSpeech(owner); }
    finally { _polling = false; }
  }
}
