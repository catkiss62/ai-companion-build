import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/fate_wheel/fate_wheel_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled source has seven complete dimensions and default gore lock',
      () async {
    final catalog = await FateWheelCatalog.load();
    expect(catalog.length, 7);
    expect(catalog.map((d) => d.tags.length).reduce((a, b) => a + b), 502);
    expect(catalog.where((d) => d.gore).map((d) => d.id), ['gore']);
    expect(catalog.every((d) => d.tags.isNotEmpty), isTrue);
  });

  test('selection preserves the exact drawn tag as fictional room data',
      () async {
    final catalog = await FateWheelCatalog.load();
    final scenario = catalog.firstWhere((d) => d.id == 'scenario');
    final selected = FateWheelResult.draw(scenario, Random(7));
    expect(scenario.tags.contains(selected), isTrue);
    final context = FateWheelResult({'scenario': selected})
        .toEntryContext(catalog);
    expect(context, contains('"dimension":"scenario"'));
    expect(context, contains('"tag":'));
    expect(context, contains('不表示用户已经行动、同意'));
    expect(context, isNot(contains('"dimension":"gore"')));
    expect(FateWheelResult.preview(context),
        ['${scenario.label} · ${selected.zh.isNotEmpty ? selected.zh : selected.en}']);
  });
}
