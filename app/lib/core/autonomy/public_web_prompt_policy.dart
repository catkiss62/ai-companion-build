import '../agent/agent_tool.dart';
import '../models/thought.dart';
import 'public_web_share_policy.dart';

/// Keeps autonomous discovery data out of unrelated ordinary prompts.
///
/// Raw search results are not ambient knowledge. A public-web card enters a
/// prompt only when the current selected Thought names that exact candidate,
/// or when the proactive writer explicitly supplies the selected candidate.
/// A user-turn web tool result always wins and excludes autonomous cards.
class PublicWebPromptPolicy {
  const PublicWebPromptPolicy._();

  static List<String> candidateIds({
    required Iterable<AgentToolResult> agentToolResults,
    CompanionThought? selectedThought,
    String? selectedCandidateId,
  }) {
    final hasCurrentUserWebResult = agentToolResults.any(
      (result) => result.toolId == 'public_web.search',
    );
    if (hasCurrentUserWebResult) return const [];

    final explicit = (selectedCandidateId ?? '').trim().toLowerCase();
    if (explicit.isNotEmpty) return [explicit];

    if (!PublicWebSharePolicy.isCandidateThought(selectedThought)) {
      return const [];
    }
    final fromThought = PublicWebSharePolicy.candidateIdFromTopic(
      selectedThought!.topicKey,
    );
    return fromThought == null ? const [] : [fromThought];
  }
}
