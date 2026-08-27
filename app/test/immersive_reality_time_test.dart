import 'package:ai_companion_localfirst/core/immersive/immersive_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('immersive reality clock distinguishes the device clock from story time',
      () {
    final section = ImmersivePromptBuilder.realityTimeSection(
      DateTime(2026, 8, 27, 12, 34),
    );
    expect(section, contains('【现实系统时间 / REAL-WORLD CLOCK】'));
    expect(section, contains('设备当地日期：2026-08-27'));
    expect(section, contains('设备当地时间：12:34'));
    expect(section, contains('星期：星期四'));
    expect(section, contains('UTC offset：'));
    expect(section, contains('小说场景时间仍以入场背景、现场账和已经发生的剧情为准'));
    expect(section, contains('现实钟表流逝不会自动推进、覆盖或重写虚构场景时间'));
  });
}
