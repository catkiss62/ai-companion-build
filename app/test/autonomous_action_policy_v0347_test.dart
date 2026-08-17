import 'package:ai_companion_localfirst/core/autonomy/autonomous_action_policy.dart';
import 'package:ai_companion_localfirst/core/models/autonomous_action.dart';
import 'package:flutter_test/flutter_test.dart';

AutonomousActionRequest request(AutonomousToolKind tool) =>
    AutonomousActionRequest(
      id: 'run-1',
      dedupeKey: 'topic-window-1',
      tool: tool,
      intentAction: 'explore_interest',
      driveKey: 'curiosity',
      intentScore: 0.72,
      reasonSource: 'internal',
      requestedAt: DateTime.utc(2026, 8, 18, 1),
    );

AutonomousActionContext context({
  bool activeBrain = true,
  bool transferLocked = false,
  bool generationActive = false,
  bool screenInteractive = true,
  bool deviceLocked = false,
  bool sensitiveSurface = false,
  bool providerAvailable = true,
  bool duplicateActive = false,
  int? budgetLimit = 6,
  int budgetUsed = 0,
}) => AutonomousActionContext(
  activeBrain: activeBrain,
  transferLocked: transferLocked,
  generationActive: generationActive,
  screenInteractive: screenInteractive,
  deviceLocked: deviceLocked,
  sensitiveSurface: sensitiveSurface,
  providerAvailable: providerAvailable,
  duplicateActive: duplicateActive,
  budgetLimit: budgetLimit,
  budgetUsed: budgetUsed,
);

void main() {
  group('AutonomousActionPolicy ownership fencing', () {
    test('inactive brain cannot execute a tool', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.publicWeb),
        context: context(activeBrain: false),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.inactiveBrain);
    });

    test('transfer lock blocks every tool', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.publicWeb),
        context: context(transferLocked: true),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.transferLocked);
    });

    test('active generation prevents concurrent model-backed tools', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.publicWeb),
        context: context(generationActive: true),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.generationActive);
    });
  });

  group('screen-off behavior', () {
    test('locked screen blocks only live screen observation', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.screenObservation),
        context: context(deviceLocked: true, screenInteractive: false),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.screenLocked);
    });

    test('locked screen does not block quiet public web work', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.publicWeb),
        context: context(deviceLocked: true, screenInteractive: false),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, AutonomousGateReason.allowed);
    });

    test('sensitive surface blocks screen observation', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.screenObservation),
        context: context(sensitiveSurface: true),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.sensitiveSurface);
    });
  });

  group('provider, dedupe and budget protection', () {
    test('unconnected provider is explicit and does not fake success', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.publicWeb),
        context: context(providerAvailable: false, budgetLimit: null),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.providerUnavailable);
    });

    test('active duplicate is rejected before another execution', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.publicWeb),
        context: context(duplicateActive: true),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.duplicate);
    });

    test('rolling budget exhaustion is a hard loop guard', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.screenObservation),
        context: context(budgetLimit: 6, budgetUsed: 6),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, AutonomousGateReason.budgetExhausted);
      expect(result.budgetRemaining, 0);
    });

    test('remaining budget is reported for diagnostics', () {
      final result = AutonomousActionPolicy.evaluate(
        request: request(AutonomousToolKind.screenObservation),
        context: context(budgetLimit: 6, budgetUsed: 2),
      );
      expect(result.allowed, isTrue);
      expect(result.budgetRemaining, 4);
    });
  });

  test('latency is exported only as a coarse bucket', () {
    expect(autonomousLatencyBucket(const Duration(milliseconds: 700)), 'lt_1s');
    expect(autonomousLatencyBucket(const Duration(seconds: 8)), '5_15s');
    expect(autonomousLatencyBucket(const Duration(minutes: 2)), 'gte_60s');
  });
}
