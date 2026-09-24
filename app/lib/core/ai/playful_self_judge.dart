import 'dart:convert';

import '../personality/playful_form_state.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';
import 'model_profile.dart';

/// Judges the final visible reply candidate, never a proposed inclination.
/// Jev owns the normal short decision; the existing DeepSeek Flash endpoint
/// classifies the same visible text if Jev is absent, uncertain or unavailable.
class PlayfulSelfJudge {
  PlayfulSelfJudge({
    required this.client,
    JevDecisionGateway? jevGateway,
    this.fallbackClassifier,
  }) : jevGateway = jevGateway ?? JevDecisionGateway.instance;

  final DeepSeekClient client;
  final JevDecisionGateway jevGateway;
  final Future<PlayfulSelfActivity?> Function(String, String)?
      fallbackClassifier;

  static const options = <String, String>{
    'none': 'No independent playful challenge in the assistant reply. '
        'Routine warmth, shyness, empathy, or simply copying the user '
        'or intimacy alone are not playful contributions.',
    'playful': 'The assistant actually opens a small pointed joke or adds '
        'an original playful retort to the exchange.',
    'strong': 'The assistant clearly initiates or actively escalates '
        'a reciprocal provocative challenge, rather than repeating '
        'the user or expressing real anger.',
    'settle': 'The assistant explicitly chooses to end an ongoing '
        'playful contest and makes peace. Ordinary direct conversation '
        'or practical help alone does not count.',
  };

  Future<PlayfulSelfActivity?> classify({
    required String apiKey,
    required String endpoint,
    required String userText,
    required String assistantText,
    String recentContext = '',
    GenerationCancellationToken? cancellationToken,
  }) async {
    if (assistantText.trim().isEmpty) return PlayfulSelfActivity.none;
    final recent = recentContext.length > 900
        ? recentContext.substring(recentContext.length - 900)
        : recentContext;
    final state = <String, Object?>{
      'recent_context': recent,
      'latest_user_text': _bounded(userText, 900),
      'assistant_reply': _bounded(assistantText, 1500),
    };
    final jev = await jevGateway.choose(
      state: state,
      instruction: 'Judge only the assistant_reply that was actually '
          'generated. Use latest_user_text and recent_context to tell '
          'an original playful challenge from merely mirroring the user. '
          'Do not score an intention or prompt, and do not treat affection, '
          'embarrassment, intimate narration or helpful answers as teasing.',
      options: options,
      cancellationToken: cancellationToken,
      usageLane: 'chat_playful_self',
    );
    final selected = PlayfulSelfActivity.parse(jev);
    if (selected != null) return selected;
    cancellationToken?.throwIfCancelled();

    // Injecting the fallback makes the Jev -> DeepSeek contract testable
    // without a network request or a local Genie runtime.
    if (fallbackClassifier != null) {
      return fallbackClassifier!(userText, assistantText);
    }
    try {
      final output = StringBuffer();
      await for (final delta in client.streamChat(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.high,
        thinking: false,
        maxTokens: 70,
        requestTimeout: const Duration(seconds: 8),
        cancellationToken: cancellationToken,
        usageLane: 'chat_playful_self',
        messages: <Map<String, Object?>>[
          const {
            'role': 'system',
            'content': 'Classify only the actual ASSISTANT_REPLY against '
                'LATEST_USER_TEXT and RECENT_CONTEXT. Return one JSON object '
                'with exactly one field: {"self":"none|playful|strong|settle"}. '
                'none: no original playful challenge, ordinary care, shyness, '
                'mirroring, intimacy or direct help. playful: her own pointed light joke '
                'or original retort. strong: she initiates or escalates an '
                'explicit reciprocal provocative challenge, not anger. '
                'settle: she deliberately ends ongoing playful contest; '
                'ordinary direct speech alone is not settle. Do not infer '
                'an unspoken desire to play.',
          },
          {
            'role': 'user',
            'content': 'RECENT_CONTEXT:\n$recent\n'
                'LATEST_USER_TEXT:\n${_bounded(userText, 900)}\n'
                'ASSISTANT_REPLY:\n${_bounded(assistantText, 1500)}',
          },
        ],
      )) {
        if (delta.content.isNotEmpty) output.write(delta.content);
      }
      cancellationToken?.throwIfCancelled();
      final raw = output.toString();
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final parsed = jsonDecode(raw.substring(start, end + 1));
      return parsed is Map ? PlayfulSelfActivity.parse(parsed['self']) : null;
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      // If both providers fail, omit her bonus; the user turn and reply live on.
      return null;
    }
  }

  static String _bounded(String value, int limit) {
    final cleaned = value.trim();
    return cleaned.length > limit
        ? cleaned.substring(cleaned.length - limit)
        : cleaned;
  }
}
