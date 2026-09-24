import 'dart:convert';

import '../personality/playful_form_state.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';
import 'model_profile.dart';

class PlayfulTurnDecision {
  const PlayfulTurnDecision(this.interaction, this.initiativeOpportunity);
  final PlayfulInteraction? interaction;
  final bool initiativeOpportunity;
}

/// Immersive rooms use their own NSFW router, but share this same user-side
/// heat semantics and the persisted PlayfulFormStore with ordinary chat.
/// Failure of Jev always reaches DeepSeek Flash; neither model's arbitrary
/// numeric output is allowed to change the heat meter.
class PlayfulTurnJudge {
  PlayfulTurnJudge(this.client, {JevDecisionGateway? jevGateway,
      this.fallbackClassifier})
      : jevGateway = jevGateway ?? JevDecisionGateway.instance;
  final DeepSeekClient client;
  final JevDecisionGateway jevGateway;
  final Future<PlayfulTurnDecision> Function(String, String)? fallbackClassifier;

  Future<PlayfulTurnDecision> decide({
    required String apiKey,
    required String endpoint,
    required String userText,
    required String recentContext,
    GenerationCancellationToken? cancellationToken,
  }) async {
    final state = {
      'latest_user_text': userText,
      'recent_context': recentContext.length > 1800
          ? recentContext.substring(recentContext.length - 1800)
          : recentContext,
    };
    final result = await jevGateway.chooseMany(
      state: state,
      questions: const {
        'interaction': JevChoiceQuestion(
          'Judge only the latest user participation. Previous assistant '
          'words clarify context but never add points. Do not count warmth, '
          'affection, shyness or routine jokes as reciprocal provocation.',
          {
            'serious': 'Wants to stop playful exchange or needs help.',
            'ordinary': 'Ordinary talk, warmth or shy response without a retort.',
            'light': 'The user deliberately joins a light pointed joke; '
                'ordinary friendly speech is not enough.',
            'mutual': 'The user actively escalates reciprocal teasing into '
                'a playful challenge aimed at the assistant.',
            'strong': 'Clearly intense reciprocal playful provocation, '
                'not real anger or recycled words.',
          },
        ),
        'initiative': JevChoiceQuestion(
          'Does the latest user message leave a natural opening for the '
          'assistant to start a light playful challenge? This is only an '
          'option for her, never an instruction to joke.',
          {
            'open': 'A small original joke fits this exchange naturally.',
            'closed': 'A direct response fits better, or no opening exists.',
          },
        ),
      },
      cancellationToken: cancellationToken,
      usageLane: 'immersive_playful_route',
    );
    if (result != null) {
      return PlayfulTurnDecision(
        PlayfulInteraction.parse(result['interaction']),
        result['initiative'] == 'open',
      );
    }
    cancellationToken?.throwIfCancelled();
    if (fallbackClassifier != null) {
      return fallbackClassifier!(userText, recentContext);
    }
    try {
      final output = StringBuffer();
      await for (final delta in client.streamChat(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.high,
        thinking: false,
        maxTokens: 95,
        requestTimeout: const Duration(seconds: 8),
        cancellationToken: cancellationToken,
        usageLane: 'immersive_playful_route',
        messages: <Map<String, Object?>>[
          const {
            'role': 'system',
            'content': 'Return JSON only: '
                '{"interaction":"serious|ordinary|light|mutual|strong",'
                '"initiative":"open|closed"}. Classify only the latest user '
                'message with recent conversation for context. Ordinary '
                'affection, shyness and polite conversation are ordinary. '
                'light means deliberately joining a pointed joke. mutual '
                'means actively escalating reciprocal teasing; strong is '
                'especially vivid reciprocal provocation, not real anger. '
                'initiative=open only if the assistant could naturally start '
                'one small joke; it never grants heat points.',
          },
          {
            'role': 'user',
            'content': 'RECENT_CONTEXT:\n${state['recent_context']}\n'
                'LATEST_USER_TEXT:\n${state['latest_user_text']}',
          },
        ],
      )) {
        if (delta.content.isNotEmpty) output.write(delta.content);
      }
      cancellationToken?.throwIfCancelled();
      final raw = output.toString();
      final begin = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (begin < 0 || end <= begin) return const PlayfulTurnDecision(null, false);
      final parsed = jsonDecode(raw.substring(begin, end + 1));
      if (parsed is! Map) return const PlayfulTurnDecision(null, false);
      return PlayfulTurnDecision(
        PlayfulInteraction.parse(parsed['interaction']),
        parsed['initiative'] == 'open',
      );
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      return const PlayfulTurnDecision(null, false);
    }
  }
}
