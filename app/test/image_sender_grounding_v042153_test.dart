import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';

void main() {
  for(final text in [
    '你发来的图片里有红色的花。', '看你刚发的这张照片，光线挺好。',
    '主人发来的图里是一只猫。', '你把这张图片发给我了。',
    '这张图是你发来的。', '用户刚刚发了一张图片。',
    '我看到了你发来的图片。',
  ]) {
    test('user image reference needs no assistant send receipt: $text',() {
      expect(OperationalClaimGroundingGuard.evaluate(text:text).allowed,true);
    });
  }
  for(final text in [
    '我给你发了一张海边照片。', '（传了一张图：画面里是一只猫）',
    '我把这张图拿给你看了。', '这张图发给你了。',
    '你发来的图片挺好，我也发了一张照片给你。',
    '你发来的图片我又发了一张图给你。',
    '主人发了图片，我把这张图发给你了。',
  ]) {
    test('assistant image send still needs a current receipt: $text',() {
      final result=OperationalClaimGroundingGuard.evaluate(text:text);
      expect(result.allowed,false); expect(result.reason,'ungrounded_image_send');
    });
  }
}
