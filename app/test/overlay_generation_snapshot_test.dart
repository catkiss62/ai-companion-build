import 'package:ai_companion_localfirst/core/platform/overlay_generation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes real reasoning and answer deltas for the native overlay', () {
    const snapshot = OverlayGenerationSnapshot(
      sending: true,
      cancelling: false,
      reasoning: '正在比较两种回答方式',
      content: '我觉得',
      assistantMessageId: 'assistant-1',
      statusText: '正在搜索公开网页…',
    );

    expect(snapshot.phase, 'answering');
    expect(snapshot.toChannelMap(), <String, Object>{
      'sending': true,
      'cancelling': false,
      'reasoning': '正在比较两种回答方式',
      'content': '我觉得',
      'phase': 'answering',
      'assistant_message_id': 'assistant-1',
      'status_text': '正在搜索公开网页…',
    });
  });

  test('unfinished snapshots can share reasoning without a candidate body', () {
    const snapshot = OverlayGenerationSnapshot(
      sending: true,
      cancelling: false,
      reasoning: '还在确认最终说法',
      content: '',
      assistantMessageId: 'assistant-2',
    );

    expect(snapshot.phase, 'thinking');
    expect(snapshot.toChannelMap()['reasoning'], '还在确认最终说法');
    expect(snapshot.toChannelMap()['content'], isEmpty);
  });

  test('shared runtime phase survives an empty cross-engine checkpoint', () {
    const snapshot = OverlayGenerationSnapshot(
      sending: true,
      cancelling: false,
      reasoning: '',
      content: '',
      runtimePhase: 'answering',
      statusText: '正在整理工具结果…',
    );
    expect(snapshot.phase, 'answering');
    expect(snapshot.toChannelMap()['status_text'], '正在整理工具结果…');
  });

  test('reports thinking, cancelling, and idle phases without inventing text', () {
    expect(
      const OverlayGenerationSnapshot(
        sending: true,
        cancelling: false,
        reasoning: '',
        content: '',
      ).phase,
      'thinking',
    );
    expect(
      const OverlayGenerationSnapshot(
        sending: true,
        cancelling: true,
        reasoning: '',
        content: '',
      ).phase,
      'cancelling',
    );
    expect(
      const OverlayGenerationSnapshot(
        sending: false,
        cancelling: false,
        reasoning: '',
        content: '',
      ).phase,
      'idle',
    );
  });
}
