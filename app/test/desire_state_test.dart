import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';

void main() {
  test('DesireSnapshot round-trips drives, baselines and time cooldowns', () {
    final now = DateTime(2026, 8, 10, 22, 0);
    final original = DesireSnapshot(
      refractoryUntil: {
        DriveKey.attachment: now.add(const Duration(minutes: 35)),
      },
      lastTickAt: now,
      lastWildcardAt: now.subtract(const Duration(hours: 3)),
    );
    final restored = DesireSnapshot.decode(original.encode());
    expect(restored.drives.length, DriveKey.values.length);
    for (final key in DriveKey.values) {
      expect(restored.drives[key], closeTo(original.drives[key]!, 1e-9));
      expect(restored.baselines[key], closeTo(original.baselines[key]!, 1e-9));
    }
    expect(restored.refractoryUntil[DriveKey.attachment],
        original.refractoryUntil[DriveKey.attachment]);
    expect(restored.lastTickAt, original.lastTickAt);
    expect(restored.lastWildcardAt, original.lastWildcardAt);
  });

  test('v0.1 refractory tick snapshot remains readable', () {
    final legacy = jsonEncode({
      'drives': {
        for (final d in DriveKey.values) d.name: 0.4,
      },
      'baselines': {
        for (final d in DriveKey.values) d.name: 0.3,
      },
      'refractory_ticks': {'attachment': 2},
      'last_intent': 'contact_user',
    });
    final before = DateTime.now();
    final restored = DesireSnapshot.decode(legacy);
    final until = restored.refractoryUntil[DriveKey.attachment];
    expect(until, isNotNull);
    expect(until!.isAfter(before.add(const Duration(minutes: 23))), isTrue);
    expect(until.isBefore(before.add(const Duration(minutes: 25))), isTrue);
  });
}
