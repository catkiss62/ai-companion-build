import '../models/autonomous_action.dart';

/// Pure, deterministic gate for tool execution.
///
/// Desire/Thought choose why an action is wanted before this policy runs.
/// This policy never creates an intent and never decides whether to contact
/// the user. Proactive delivery retains its separate rhythm/frequency Gate.
class AutonomousActionPolicy {
  const AutonomousActionPolicy._();

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
    if (!context.providerAvailable || request.tool == AutonomousToolKind.screenObservation) {
      return AutonomousGateDecision(
        allowed: false,
        reason: AutonomousGateReason.providerUnavailable,
        budgetRemaining: context.budgetRemaining,
      );
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
