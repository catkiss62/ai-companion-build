import '../models/autonomous_action.dart';

/// Pure, deterministic gate for tool execution.
///
/// Desire/Thought choose why an action is wanted before this policy runs.
/// This policy never creates an intent and never decides whether to contact
/// the user. Proactive delivery retains its separate rhythm/frequency Gate.
class AutonomousActionPolicy {
  const AutonomousActionPolicy._();

  static const screenObservationHourlyLimit = 6;

  static AutonomousGateDecision evaluate({
    required AutonomousActionRequest request,
    required AutonomousActionContext context,
  }) {
    if (!context.activeBrain) {
      return const AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.inactiveBrain,
      );
    }
    if (context.transferLocked) {
      return const AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.transferLocked,
      );
    }
    if (context.generationActive) {
      return const AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.generationActive,
      );
    }
    if (context.duplicateActive) {
      return const AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.duplicate,
      );
    }
    if (!context.providerAvailable) {
      return AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.providerUnavailable,
        budgetRemaining: context.budgetRemaining,
      );
    }

    // Screen-off pauses only live screen observation. Quiet public-web work
    // and later candidate media analysis remain eligible while locked.
    if (request.tool == AutonomousToolKind.screenObservation) {
      if (context.deviceLocked) {
        return const AutonomousGateDecision(
          allowed: false,
          reason: AutonomousGateReason.screenLocked,
        );
      }
      if (!context.screenInteractive) {
        return const AutonomousGateDecision(
          allowed: false,
          reason: AutonomousGateReason.screenNotInteractive,
        );
      }
      if (context.sensitiveSurface) {
        return const AutonomousGateDecision(
          allowed: false,
          reason: AutonomousGateReason.sensitiveSurface,
        );
      }
    }

    final remaining = context.budgetRemaining;
    if (remaining != null && remaining <= 0) {
      return const AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.budgetExhausted,
        budgetRemaining: 0,
      );
    }
    return AutonomousGateDecision(
      allowed: true,
      reason: AutonomousGateReason.allowed,
      budgetRemaining: remaining,
    );
  }
}
