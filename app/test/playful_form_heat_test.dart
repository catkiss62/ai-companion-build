import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  test('full heat leaves Q form after five ordinary turns', () {
    var state = const PlayfulFormState(heat: 100, qForm: true);
    final now = DateTime.utc(2026, 9, 24);
    for (var turn = 1; turn <= 5; turn++) {
      state = state.advance(PlayfulInteraction.ordinary, 'turn_$turn', now);
      expect(state.heat, 100 - turn * 10);
    }
    expect(state.qForm, isFalse);
    expect(state.advance(PlayfulInteraction.strong, 'turn_5', now).heat, 50);
  });

  test('light banter grows slowly and neutral shyness cools', () {
    final now = DateTime.utc(2026, 9, 24);
    final teasing = const PlayfulFormState(heat: 65)
        .advance(PlayfulInteraction.light, 'banter', now);
    expect(teasing.heat, 71); // -10 +16
    expect(teasing.qForm, isFalse);
    final embarrassed = teasing.advance(PlayfulInteraction.ordinary, 'shy', now);
    expect(embarrassed.heat, 61);
    expect(embarrassed.qForm, isFalse);
  });
}
