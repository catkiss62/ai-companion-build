import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/widgets/caicai_stage_viewport.dart';

void main() {
  test('IME frames, including zero-inset lag, preserve scene height', () {
    final viewport = CaicaiStageViewport();
    expect(viewport.resolve(width: 400, availableHeight: 760, keyboardInset: 0), 760);
    for (final sample in [
      (available: 700.0, inset: 40.0),
      (available: 590.0, inset: 170.0),
      (available: 440.0, inset: 320.0),
      (available: 440.0, inset: 0.0),
      (available: 590.0, inset: 0.0),
      (available: 880.0, inset: 170.0),
    ]) {
      expect(viewport.resolve(width: 400,
        availableHeight: sample.available, keyboardInset: sample.inset), 760);
    }
    expect(viewport.resolve(width: 400, availableHeight: 760, keyboardInset: 0), 760);
  });

  test('entering with keyboard open and changing orientation', () {
    final viewport = CaicaiStageViewport();
    expect(viewport.resolve(width: 400, availableHeight: 440, keyboardInset: 320), 760);
    expect(viewport.resolve(width: 400, availableHeight: 720, keyboardInset: 0), 760);
    expect(viewport.resolve(width: 400, availableHeight: 780, keyboardInset: 0), 780);
    expect(viewport.resolve(width: 800, availableHeight: 240, keyboardInset: 120), 360);
  });
}
