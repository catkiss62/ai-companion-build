import '../ai/generation_cancellation.dart';
import '../ai/jev_decision_gateway.dart';

/// An inexpensive semantic gate for a recent exchange about an active game.
/// If Jev is unavailable, the existing DeepSeek tool request makes the final
/// decision; a missing classifier never silently loses a possible invitation.
class CedarContextIntentJudge {
  CedarContextIntentJudge({JevDecisionGateway? gateway})
      : gateway = gateway ?? JevDecisionGateway.instance;

  final JevDecisionGateway gateway;

  Future<bool> answersPuzzle({required String question, required String userText,
      GenerationCancellationToken? cancellationToken}) async {
    final answer = await gateway.choose(
      state: {'question':question, 'user_reply':userText},
      instruction: 'Does this message answer this puzzle question, offer a clue, decline help, or tell her to think again? Changing subject and asking her to stop playing do not resume the puzzle.',
      options: const {'reply':'Answers or sends her back to investigate.', 'other':'Unrelated, unclear, or stops play.'},
      usageLane:'cedar_puzzle_reply', cancellationToken:cancellationToken);
    if (answer != null) return answer == 'reply';
    return RegExp(r'^(?:提示[：:，]|(?:这题的?)?(?:答案|谜底)(?:是|[：:，])|(?:你)?(?:再|先)?自己(?:想想|试试|继续))').hasMatch(userText.trim());
  }

  Future<bool> shouldOfferTools({
    required String userText,
    required String previousAssistantText,
    String originalInvitationText = '',
    required String activeGameTitle,
    GenerationCancellationToken? cancellationToken,
  }) async {
    final details = <String, JevChoiceDecision>{};
    final result = await gateway.choose(
      state: <String, String>{
        'active_game': activeGameTitle,
        'previous_assistant': previousAssistantText.length > 850
            ? previousAssistantText.substring(previousAssistantText.length - 850)
            : previousAssistantText,
        if (originalInvitationText.isNotEmpty)
          'original_user_invitation': originalInvitationText.length > 240
              ? originalInvitationText.substring(0, 240)
              : originalInvitationText,
        'latest_user': userText,
      },
      instruction: 'Judge the latest user reply in the actual conversation. '
          'Does it accept the original user game invitation or ask the companion '
          'to advance a game now? “走着” or “开始吧” can accept a recent fishing '
          'invitation even without an active session. Mere affection, discussing a game, a plan '
          'for another day, a refusal or changing topics does not count. '
          'Only decide intent; do not choose an action or assume it happened.',
      options: const <String, String>{
        'advance': 'The user is asking or agreeing to advance this game now.',
        'chat': 'No current game action is requested or authorized.',
      },
      cancellationToken: cancellationToken,
      usageLane: 'cedar_context_intent',
      decisionDetails: details,
    );
    return details['route']?.ambiguous != true && result != 'chat';
  }
}
