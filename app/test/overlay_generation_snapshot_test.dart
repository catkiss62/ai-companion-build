import 'package:ai_companion_localfirst/core/platform/overlay_generation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes real reasoning and answer deltas for the native overlay', () {
    const snapshot = OverlayGenerationSnapshot(
      sending: true,
      cancelling: false,
      reasoning: '正在比较两种回答方式',
      content: '我觉得',
    );

    expect(snapshot.phase, 'answering');
    expect(snapshot.toChannelMap(), <String, Object>{
      'sending': true,
      'cancelling': false,
      'reasoning': '正在比较两种回答方式',
      'content': '我觉得',
      'phase': 'answering',
    });
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
