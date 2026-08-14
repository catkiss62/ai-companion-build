import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_playback_queue.dart';
import 'package:ai_companion_localfirst/core/tts/tts_queue_service.dart';

class _FakeQueueService implements TtsQueueService {
  final prepared = <String>[];
  final generated = <String>[];
  final played = <String>[];
  int stopCount = 0;
  Completer<void>? firstPlaybackGate;
  Completer<void>? firstGenerationGate;
  bool failFirstGeneration = false;

  @override
  Future<String?> prepareText(String visibleText, {bool manual = false}) async {
    prepared.add(visibleText);
    return visibleText;
  }

  @override
  Future<String?> generatePrepared(String spokenText) async {
    generated.add(spokenText);
    if (generated.length == 1 && firstGenerationGate != null) {
      await firstGenerationGate!.future;
    }
    if (generated.length == 1 && failFirstGeneration) return null;
    return 'wav:$spokenText';
  }

  @override
  Future<void> playPrepared(String wavBase64) async {
    played.add(wavBase64);
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
    );

    await queue.beginStream(manual: false);
    queue.addDelta('先说第一句。再说');
    queue.addDelta('第二句！');
    queue.endStream();
    await queue.waitUntilIdle();

    expect(fake.generated, ['先说第一句', '再说第二句']);
    expect(fake.played, ['wav:先说第一句', 'wav:再说第二句']);
  });

  test('reports synthesizing, playing, and idle for the owning message', () async {
    final fake = _FakeQueueService()
      ..firstGenerationGate = Completer<void>()
      ..firstPlaybackGate = Completer<void>();
    final states = <TtsQueueState>[];
    final queue = TtsPlaybackQueue(
      service: fake,
      interSentenceGap: Duration.zero,
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
    final queue = TtsPlaybackQueue(service: _FakeQueueService());

    await queue.beginStream(manual: false, ownerId: 'assistant-stream');

    expect(queue.state.phase, TtsPlaybackPhase.synthesizing);
    expect(queue.state.ownerId, 'assistant-stream');
    await queue.stop();
    expect(queue.state.phase, TtsPlaybackPhase.idle);
  });
}
