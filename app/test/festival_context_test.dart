import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/perception/festival_context.dart';

void main() {
  test('real lunar holidays and the last day of a short twelfth month', () {
    expect(FestivalContext.onDate(DateTime(2026, 2, 17)), contains('春节'));
    expect(FestivalContext.onDate(DateTime(2026, 9, 25)), contains('中秋节'));
    expect(FestivalContext.onDate(DateTime(2026, 2, 16)), contains('除夕'));
    expect(FestivalContext.onDate(DateTime(2026, 9, 26)), isNot(contains('中秋节')));
  });

  test('Christmas is a date fact and ordinary days add no prompt', () {
    expect(FestivalContext.onDate(DateTime(2026, 12, 25)), contains('圣诞节'));
    expect(FestivalContext.forPrompt(DateTime(2026, 9, 26)), isEmpty);
    expect(FestivalContext.forPrompt(DateTime(2026, 12, 25)),
        contains('不代表当地法定放假'));
  });
}
