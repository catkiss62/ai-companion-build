import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  test('full heat leaves Q form only at zero after ten ordinary turns', () {
    var state = const PlayfulFormState(heat: 100, qForm: true);
    final now = DateTime.utc(2026, 9, 24);
    for (var turn = 1; turn <= 9; turn++) {
      state = state.advance(PlayfulInteraction.ordinary, 'turn_$turn', now);
      expect(state.heat, 100 - turn * 10);
      expect(state.qForm, isTrue);
    }
    state = state.advance(PlayfulInteraction.ordinary, 'turn_10', now);
    expect(state.heat, 0);
    expect(state.qForm, isFalse);
    expect(state.advance(PlayfulInteraction.strong, 'turn_10', now).heat, 0);
  });

  test('light banter cools despite a joke, neutral shyness cools faster', () {
    final now = DateTime.utc(2026, 9, 24);
    final teasing = const PlayfulFormState(heat: 65)
        .advance(PlayfulInteraction.light, 'banter', now);
    expect(teasing.heat, 59); // -10 +4
    expect(teasing.qForm, isFalse);
    final embarrassed = teasing.advance(PlayfulInteraction.ordinary, 'shy', now);
    expect(embarrassed.heat, 49);
    expect(embarrassed.qForm, isFalse);
  });

  test('repeated minor jokes cannot maintain Q form indefinitely', () {
    final now = DateTime.utc(2026, 9, 24);
    var state = const PlayfulFormState(heat: 100, qForm: true);
    for (var turn = 1; turn <= 9; turn++) {
      state = state.advance(PlayfulInteraction.light, 'light_$turn', now);
    }
    expect(state.heat, 46);
    expect(state.qForm, isTrue);
    for (var turn = 10; turn <= 16; turn++) {
      state = state.advance(PlayfulInteraction.light, 'light_$turn', now);
    }
    expect(state.heat, 4);
    expect(state.qForm, isTrue);
    state = state.advance(PlayfulInteraction.light, 'light_17', now);
    expect(state.heat, 0);
    expect(state.qForm, isFalse);
  });
}
