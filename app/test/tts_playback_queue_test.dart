import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_playback_queue.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';
import 'package:ai_companion_localfirst/core/tts/tts_queue_service.dart';
import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/tts/tts_voice_profile.dart';

class _FakeQueueService implements TtsQueueService {
  final prepared = <String>[];
  final generated = <String>[];
  final generatedLanguages = <ChatLanguage>[];
  final generatedVoices = <TtsVoiceMode>[];
  final played = <String>[];
  int stopCount = 0;
  Completer<void>? firstPlaybackGate;
  Completer<void>? firstGenerationGate;
  bool failFirstGeneration = false;
  TtsVoiceMode resolvedVoice = TtsVoiceMode.daily;
  Completer<TtsVoiceMode>? voiceResolutionGate;
  String Function(String text)? prepareTransform;

  @override
  Future<TtsVoiceMode> resolveVoice(TtsEmotionCue? emotion) async {
    final gate = voiceResolutionGate;
    if (gate != null) return gate.future;
    return resolvedVoice;
  }

  @override
  Future<String?> prepareText(
    String visibleText, {
    bool manual = false,
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    prepared.add(visibleText);
    return prepareTransform?.call(visibleText) ?? visibleText;
  }

  @override
  Future<Uint8List?> generatePrepared(
    String spokenText, {
    TtsEmotionCue? emotion,
    ChatLanguage language = ChatLanguage.chinese,
    TtsVoiceMode voice = TtsVoiceMode.daily,
  }) async {
    generated.add(spokenText);
    generatedLanguages.add(language);
    generatedVoices.add(voice);
    if (generated.length == 1 && firstGenerationGate != null) {
      await firstGenerationGate!.future;
    }
    if (generated.length == 1 && failFirstGeneration) return null;
    return Uint8List.fromList(utf8.encode('wav:$spokenText'));
  }

  @override
  Future<void> playPrepared(Uint8List wavBytes) async {
    played.add(utf8.decode(wavBytes));
    if (played.length == 1 && firstPlaybackGate != null) {
      await firstPlaybackGate!.future;
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  test('A2 generates later sentences while the first sentence is playing', () async {
    final fake = _FakeQueueService()..firstPlaybackGate = Completer<void>();
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.playText('第一句。第二句。第三句。', manual: true);
    await _turn();
    await _turn();

    expect(fake.played, ['wav:第一句']);
    expect(fake.generated, ['第一句', '第二句', '第三句']);

    fake.firstPlaybackGate!.complete();
    await queue.waitUntilIdle();
    expect(fake.played, ['wav:第一句', 'wav:第二句', 'wav:第三句']);
  });

  test('stop invalidates generated/queued audio that has not played', () async {
    final fake = _FakeQueueService()..firstPlaybackGate = Completer<void>();
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.playText('第一句。第二句。', manual: true);
    await _turn();
    expect(fake.played, ['wav:第一句']);

    await queue.stop();
    fake.firstPlaybackGate!.complete();
    await _turn();

    expect(fake.played, ['wav:第一句']);
    expect(queue.state.running, isFalse);
    expect(fake.stopCount, greaterThanOrEqualTo(2));
  });

  test('one generation failure does not poison later speech', () async {
    final fake = _FakeQueueService()..failFirstGeneration = true;
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.playText('第一句。第二句。', manual: true);
    await queue.waitUntilIdle();

    expect(fake.generated, ['第一句', '第二句']);
    expect(fake.played, ['wav:第二句']);
  });

  test('stream chunks preserve A2 sentence order', () async {
    final fake = _FakeQueueService();
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.beginStream(manual: false);
    queue.addDelta('先说第一句。再说');
    queue.addDelta('第二句！');
    queue.endStream();
    await queue.waitUntilIdle();

    expect(fake.generated, ['先说第一句', '再说第二句']);
    expect(fake.played, ['wav:先说第一句', 'wav:再说第二句']);
  });

  test('streaming text is capped again after speech replacement', () async {
    final fake = _FakeQueueService()
      ..prepareTransform = (text) => List<String>.filled(60, '鲸').join();
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.beginStream(manual: true);
    queue.addDelta('短句。');
    queue.endStream();
    await queue.waitUntilIdle();

    expect(fake.generated.length, greaterThan(1));
    expect(fake.generated.every((chunk) => chunk.length <= 54), isTrue);
    expect(fake.generated.join(), List<String>.filled(60, '鲸').join());
  });

  test('reports synthesizing, playing, and idle for the owning message', () async {
    final fake = _FakeQueueService()
      ..firstGenerationGate = Completer<void>()
      ..firstPlaybackGate = Completer<void>();
    final states = <TtsQueueState>[];
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
      onStateChanged: states.add,
    );

    await queue.playText('正在准备。', ownerId: 'assistant-1');
    expect(queue.state.phase, TtsPlaybackPhase.synthesizing);
    expect(queue.state.ownerId, 'assistant-1');

    fake.firstGenerationGate!.complete();
    await _turn();
    await _turn();
    expect(queue.state.phase, TtsPlaybackPhase.playing);
    expect(queue.state.ownerId, 'assistant-1');

    fake.firstPlaybackGate!.complete();
    await queue.waitUntilIdle();
    expect(queue.state, same(TtsQueueState.idle));
    expect(
      states.map((state) => state.phase),
      containsAllInOrder(<TtsPlaybackPhase>[
        TtsPlaybackPhase.synthesizing,
        TtsPlaybackPhase.playing,
        TtsPlaybackPhase.idle,
      ]),
    );
  });

  test('auto streaming announces synthesis before the first audio chunk', () async {
    final queue = TtsPlaybackQueue(
      service: _FakeQueueService(),
      initialPrefill: Duration.zero,
    );

    await queue.beginStream(manual: false, ownerId: 'assistant-stream');

    expect(queue.state.phase, TtsPlaybackPhase.synthesizing);
    expect(queue.state.ownerId, 'assistant-stream');
    await queue.stop();
    expect(queue.state.phase, TtsPlaybackPhase.idle);
  });

  test('lead-in audio and TTS synthesis run in parallel', () async {
    final cue = Completer<void>();
    final fake = _FakeQueueService();
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.playText(
      '情绪音效之后说话。',
      manual: true,
      leadIn: cue.future,
    );
    await _turn();
    await _turn();

    expect(fake.generated, ['情绪音效之后说话']);
    expect(fake.played, isEmpty);

    cue.complete();
    await queue.waitUntilIdle();
    expect(fake.played, ['wav:情绪音效之后说话']);
  });

  test('a finished lead-in adds no wait after slow synthesis', () async {
    final cue = Completer<void>()..complete();
    final generation = Completer<void>();
    final fake = _FakeQueueService()..firstGenerationGate = generation;
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.playText(
      '合成完成立即播放。',
      manual: true,
      leadIn: cue.future,
    );
    await _turn();
    expect(fake.played, isEmpty);

    generation.complete();
    await queue.waitUntilIdle();
    expect(fake.played, ['wav:合成完成立即播放']);
  });

  test('language and resolved voice stay locked for the full session', () async {
    final fake = _FakeQueueService()..resolvedVoice = TtsVoiceMode.cute;
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
      initialPrefill: Duration.zero,
    );

    await queue.playText(
      '最初の文。次の文。',
      language: ChatLanguage.japanese,
    );
    await queue.waitUntilIdle();

    expect(
      fake.generatedLanguages,
      everyElement(ChatLanguage.japanese),
    );
    expect(fake.generatedVoices, everyElement(TtsVoiceMode.cute));
  });

  test('stop during voice resolution prevents an old session from reviving', () async {
    final gate = Completer<TtsVoiceMode>();
    final fake = _FakeQueueService()..voiceResolutionGate = gate;
    final queue = TtsPlaybackQueue(
      service: fake,
      initialPrefill: Duration.zero,
    );

    final pending = queue.playText('这条旧请求不能复活。');
    await _turn();
    await queue.stop();
    gate.complete(TtsVoiceMode.daily);
    await pending;

    expect(fake.generated, isEmpty);
    expect(queue.state, same(TtsQueueState.idle));
  });

}
