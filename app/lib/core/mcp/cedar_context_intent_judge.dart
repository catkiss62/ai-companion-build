import '../ai/generation_cancellation.dart';
import '../ai/jev_decision_gateway.dart';

/// An inexpensive semantic gate for a recent exchange about an active game.
/// If Jev is unavailable, the existing DeepSeek tool request makes the final
/// decision; a missing classifier never silently loses a possible invitation.
class CedarContextIntentJudge {
  CedarContextIntentJudge({JevDecisionGateway? gateway})
      : gateway = gateway ?? JevDecisionGateway.instance;

  final JevDecisionGateway gateway;

  Future<bool> shouldOfferTools({
    required String userText,
    required String previousAssistantText,
    required String activeGameTitle,
    String priorUserInvitation = '',
    GenerationCancellationToken? cancellationToken,
  }) async {
    final result = await gateway.choose(
      state: <String, String>{
        'active_game': activeGameTitle,
        if (priorUserInvitation.isNotEmpty)
          'prior_user_invitation': priorUserInvitation.length > 350
              ? priorUserInvitation.substring(0, 350)
              : priorUserInvitation,
        'previous_assistant': previousAssistantText.length > 850
            ? previousAssistantText.substring(previousAssistantText.length - 850)
            : previousAssistantText,
        'latest_user': userText,
      },
      instruction: 'Judge the latest user reply in the actual conversation. '
          'Does it authorize the companion to advance the active game or the '
          'prior user-authored invitation now? The prior invitation can name '
          'a different game from the old active game. Short agreement after '
          'that invitation counts; mere affection, a plan for another day, '
          'a refusal or changing topics does not. Only decide intent; do not '
          'choose an action or assume it happened.',
      options: const <String, String>{
        'advance': 'The user is asking or agreeing to advance this game now.',
        'chat': 'No current game action is requested or authorized.',
      },
      cancellationToken: cancellationToken,
      usageLane: 'cedar_context_intent',
    );
    return result != 'chat';
  }
}
