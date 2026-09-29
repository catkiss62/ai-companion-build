/// Interprets Jev's pre-reply game intent without guessing from keywords.
/// Null is a transport failure, so only the established narrow candidates
/// may reach the existing DeepSeek on-demand planner in that case.
class CedarSemanticRoutePolicy {
  const CedarSemanticRoutePolicy._();

  static bool directRequest({
    required bool configured,
    required bool explicitRequest,
    required String? intent,
  }) => configured && explicitRequest &&
      (intent == null || intent == 'act_now' ||
          intent == 'accept');

  static bool contextualRequest({
    required bool configured,
    required bool sessionActive,
    required bool explicitRequest,
    required bool narrowCandidate,
    required String? intent,
  }) {
    if (!configured || sessionActive) return false;
    if (intent == null) return narrowCandidate && !explicitRequest;
    // Jev has already classified the current user turn against the dialogue.
    // A local 15-minute check must not cancel its valid acceptance decision.
    final accepted = intent == 'act_now' || intent == 'accept';
    return accepted && !explicitRequest;
  }
}
