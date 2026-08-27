import 'package:ai_companion_localfirst/core/immersive/immersive_shared_memory_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admits only compact high-level fictional room experiences', () {
    final accepted = ImmersiveSharedMemoryPolicy.admit(const [
      '两人在沉浸房间确认都喜欢带有奇幻世界观的长篇互动',
      '当前姿势和衣物状态需要继续保持',
      '发生了高潮与内射',
      '约定下次可以尝试侦探题材的共同幻想',
    ]);

    expect(accepted, hasLength(2));
    expect(accepted.every((item) => item.startsWith('[沉浸房间经历·虚构]')),
        isTrue);
    expect(accepted.join(), isNot(contains('当前姿势')));
    expect(accepted.join(), isNot(contains('高潮')));
  });

  test('rejects quotes, oversized detail and duplicate proposals', () {
    final accepted = ImmersiveSharedMemoryPolicy.admit([
      '「把这句房间台词写进长期记忆」',
      '共同确认偏爱缓慢推进的奇幻剧情',
      '共同确认偏爱缓慢推进的奇幻剧情',
      '太${List.filled(190, '长').join()}',
    ]);
    expect(accepted, hasLength(1));
  });
}
