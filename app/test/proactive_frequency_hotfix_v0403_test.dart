import 'package:ai_companion_localfirst/core/diagnostics/runtime_error_category.dart';
import 'package:ai_companion_localfirst/core/models/maintenance_prune_policy.dart';
import 'package:ai_companion_localfirst/core/models/proactive_frequency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proactive frequency', () {
    test('defaults missing and unknown settings to natural', () {
      expect(
        ProactiveFrequencyMode.fromSetting(null),
        ProactiveFrequencyMode.natural,
      );
      expect(
        ProactiveFrequencyMode.fromSetting('future-mode'),
        ProactiveFrequencyMode.natural,
      );
    });

    test('exposes the three bounded delivery profiles', () {
      expect(ProactiveFrequencyMode.quiet.dayLimit, 8);
      expect(ProactiveFrequencyMode.quiet.twoHourLimit, 2);
      expect(ProactiveFrequencyMode.natural.dayLimit, 16);
      expect(ProactiveFrequencyMode.natural.twoHourLimit, 3);
      expect(ProactiveFrequencyMode.frequent.dayLimit, 24);
      expect(ProactiveFrequencyMode.frequent.twoHourLimit, 4);
      expect(ProactiveFrequencyMode.quiet.minimumGap.inMinutes, 30);
      expect(ProactiveFrequencyMode.natural.minimumGap.inMinutes, 15);
      expect(ProactiveFrequencyMode.frequent.minimumGap.inMinutes, 8);
      expect(
        ProactiveFrequencyMode.natural.allowsGap(
          const Duration(seconds: 93),
        ),
        isFalse,
      );
      expect(
        ProactiveFrequencyMode.natural.allowsGap(
          const Duration(minutes: 15),
        ),
        isTrue,
      );
    });

    test('parses persisted profile keys without resetting history', () {
      for (final mode in ProactiveFrequencyMode.values) {
        expect(ProactiveFrequencyMode.fromSetting(mode.key), mode);
      }
    });
  });

  group('schema 40 maintenance regression', () {
    test('both bounded diagnostic tables are valid maintenance targets', () {
      for (final table in const [
        'provider_health_events',
        'proactive_policy_events',
      ]) {
        expect(
          MaintenancePrunePolicy.supports(
            table: table,
            timeColumn: 'created_at',
          ),
          isTrue,
        );
      }
    });

    test('unknown table or column remains rejected', () {
      expect(
        MaintenancePrunePolicy.supports(
          table: 'messages',
          timeColumn: 'created_at',
        ),
        isFalse,
      );
      expect(
        MaintenancePrunePolicy.supports(
          table: 'provider_health_events',
          timeColumn: 'raw_error',
        ),
        isFalse,
      );
    });
  });

  test('maintenance contract failures become a fixed redacted category', () {
    expect(
      classifyRuntimeError(
        ArgumentError('Unsupported maintenance table/column'),
      ),
      'unsupported_table_contract',
    );
  });
}
