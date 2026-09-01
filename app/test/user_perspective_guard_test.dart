import 'package:flutter_test/flutter_test.dart';

import '../lib/core/grounding/user_perspective_guard.dart';

void main() {
  group('UserPerspectiveGuard', () {
    test('blocks narration that turns the current user into him', () {
      final result = UserPerspectiveGuard.evaluate(
        '被他这句突然冒出来的话逗笑了，我抬眼看过去。',
      );

      expect(result.allowed, isFalse);
      expect(result.reason, 'current_user_narrated_as_third_person');
    });

    test('blocks mixed him narration even when dialogue also says you', () {
      final result = UserPerspectiveGuard.evaluate(
        '被他这句话逗笑了。\n\n「你怎么突然问这个？」',
        currentUserText: '在干嘛呢？',
      );

      expect(result.allowed, isFalse);
    });

    test('allows a genuine third party mentioned by the user', () {
      final result = UserPerspectiveGuard.evaluate(
        '你老板他今天又临时改需求了？',
        currentUserText: '我老板他说今天要改需求。',
      );

      expect(result.allowed, isTrue);
    });

    test('allows direct second-person companion narration', () {
      final result = UserPerspectiveGuard.evaluate(
        '被你这句突然冒出来的话逗笑了，我抬眼看你。',
      );

      expect(result.allowed, isTrue);
    });
  });
}
