import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/visible_reasoning_transcript.dart';

void main() {
  test('keeps every planning round and the accepted final reasoning in order',
      () {
    final transcript = VisibleReasoningTranscript();
    transcript.addPlanning('先查看当前局面。');
    transcript.addPlanning('工具返回后继续行动。');
    expect(
      transcript.committed('现在告诉你真实结果。'),
      '【规划 1】\n先查看当前局面。\n\n'
      '【规划 2】\n工具返回后继续行动。\n\n'
      '【最终回复】\n现在告诉你真实结果。',
    );
  });

  test('an absent provider summary is never invented', () {
    final transcript = VisibleReasoningTranscript();
    transcript.addPlanning('确实执行了规划。');
    expect(transcript.committed(''), '【规划 1】\n确实执行了规划。');
    expect(VisibleReasoningTranscript().committed(''), isEmpty);
  });
}
