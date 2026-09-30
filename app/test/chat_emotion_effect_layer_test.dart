import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/presentation/chat_visuals.dart';
import 'package:ai_companion_localfirst/widgets/chat_emotion_effect_layer.dart';

void main() {
  const emotion = ChatEmotionVisual(
    key: 'happy',
    zhLabel: '开心',
    portraitAsset: '',
    effectAsset: 'assets/lingchat/effects/happy.webp',
  );
  Widget layer(
    String id, {
    bool enabled = true,
    bool active = true,
    bool generating = false,
  }) => MaterialApp(
    home: SizedBox(
      width: 200,
      height: 300,
      child: ChatEmotionEffectLayer(
        emotion: emotion,
        replyId: id,
        enabled: enabled,
        active: active,
        generating: generating,
      ),
    ),
  );
  double opacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
  testWidgets(
    'history never replays; real reply plays once and hiding consumes it',
    (tester) async {
      await tester.pumpWidget(layer('history'));
      expect(opacity(tester), 0);
      await tester.pumpWidget(layer('new', generating: true));
      expect(opacity(tester), 0);
      await tester.pumpWidget(layer('new'));
      expect(opacity(tester), 1);
      await tester.pump(const Duration(seconds: 2));
      expect(opacity(tester), 0);
      await tester.pumpWidget(layer('new'));
      expect(opacity(tester), 0);
      await tester.pumpWidget(layer('hidden-reply', active: false));
      await tester.pumpWidget(layer('hidden-reply'));
      expect(opacity(tester), 0);
      await tester.pumpWidget(layer('next'));
      expect(opacity(tester), 1);
      await tester.pumpWidget(layer('next', enabled: false));
      expect(opacity(tester), 0);
      await tester.pumpWidget(layer('next'));
      expect(opacity(tester), 0);
    },
  );
}
