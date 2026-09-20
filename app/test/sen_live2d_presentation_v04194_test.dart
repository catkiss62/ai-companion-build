import 'package:ai_companion_localfirst/core/presentation/chat_visuals.dart';
import 'package:ai_companion_localfirst/core/presentation/sen_live2d_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all existing chat emotions map into Sen authored emotions', () {
    final mapped = ChatVisualResolver.values
        .map((emotion) => senLive2DEmotionFor(emotion.key, outfit: 'maid'))
        .toSet();

    expect(ChatVisualResolver.values, hasLength(20));
    expect(mapped, hasLength(20));
    expect(mapped, everyElement(isIn(senLive2DEmotionKeys)));
    expect(senLive2DEmotionKeys, hasLength(21));
    expect(senLive2DEmotionFor('nervous', outfit: 'maid'), 'tense');
    expect(senLive2DEmotionFor('crying', outfit: 'maid'), 'sad');
    expect(senLive2DEmotionFor('embarrassed', outfit: 'maid'), 'ashamed');
  });

  test('undressed presentation uses visual-only romantic shy', () {
    for (final emotion in ChatVisualResolver.values) {
      expect(
        senLive2DEmotionFor(emotion.key, outfit: 'undressed'),
        'romantic_shy',
      );
    }
    expect(senLive2DOutfitKeys, {
      'maid',
      'white_shirt',
      'bunny',
      'undressed',
    });
  });

  test('NSFW presentation uses visual-only romantic shy in every outfit', () {
    for (final outfit in senLive2DOutfitKeys.where((it) => it != 'undressed')) {
      expect(
        senLive2DEmotionFor('happy', outfit: outfit, nsfwActive: true),
        'romantic_shy',
      );
    }
  });

  test('unknown presentation values fall back without inventing truth', () {
    expect(senLive2DEmotionFor('unknown', outfit: 'maid'), 'normal');
  });
}
