import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/widgets/caicai_stage_viewport.dart';
void main() {
  test('IME animations and bottom safe-area changes never reshape cached canvas', () {
    final v=CaicaiStageViewport();
    expect(v.resolve(width:400,availableHeight:760,keyboardInset:0),760);
    for(final inset in [40.0,170.0,320.0,170.0,40.0]) {
      expect(v.resolve(width:400,availableHeight:760-inset+24,keyboardInset:inset),760);
    }
    expect(v.resolve(width:400,availableHeight:760,keyboardInset:0),760);
    expect(v.resolve(width:800,availableHeight:240,keyboardInset:120),360);
  });
  test('opening chat while keyboard visible reconstructs initial canvas', () {
    expect(CaicaiStageViewport().resolve(width:400,availableHeight:440,keyboardInset:320),760);
  });
}
