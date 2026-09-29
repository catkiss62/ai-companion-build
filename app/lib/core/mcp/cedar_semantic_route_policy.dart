/// Interprets Jev's pre-reply game intent without guessing from keywords.
/// Null is a transport failure, so only the established narrow candidates
/// may reach the existing DeepSeek on-demand planner in that case.
class CedarSemanticRoutePolicy {
  const CedarSemanticRoutePolicy._();

  static bool directRequest({
    required bool configured,
    required bool explicitRequest,
    required String? intent,
    required bool recentAssistant,
  }) => configured && explicitRequest &&
      (intent == null || intent == 'act_now' ||
          (intent == 'accept' && recentAssistant));

  static bool contextualRequest({
    required bool configured,
    required bool sessionActive,
    required bool explicitRequest,
    required bool narrowCandidate,
    required String? intent,
    required bool recentAssistant,
  }) {
    if (!configured || sessionActive) return false;
    if (intent == null) return narrowCandidate && !explicitRequest;
    final accepted = intent == 'act_now' ||
        (intent == 'accept' && recentAssistant);
    return accepted && !explicitRequest;
  }
}
