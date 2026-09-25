import 'dart:convert';

import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';
import 'model_profile.dart';

/// Called only for the first real user turn after adult heat reaches 100.
/// A missing decision preserves the opportunity for a later turn.
class PlayfulBreakthroughJudge {
  PlayfulBreakthroughJudge(this.client, {JevDecisionGateway? jevGateway,
    this.fallbackClassifier}) : jevGateway = jevGateway ?? JevDecisionGateway.instance;

  final DeepSeekClient client;
  final JevDecisionGateway jevGateway;
  final Future<bool?> Function(String, String)? fallbackClassifier;

  static const instruction = 'Look at the latest user message in the context '
      'of the previous 3-5 exchanges. Would this specific interaction naturally '
      'make the companion visibly lose her playful composure, such as suddenly '
      'getting flustered, mock-angry or mischievous? Require a distinct, vivid '
      'emotional turn. Prior strong messages explain context but cannot by '
      'themselves trigger it. Routine conversation, mere affection, repetition, '
      'real distress, requests for serious help and real anger are not triggers. '
      'Judge the situation, not literal keywords or whether she already replied.';

  Future<bool?> decide({
    required String apiKey,
    required String endpoint,
    required String userText,
    required String recentContext,
    GenerationCancellationToken? cancellationToken,
  }) async {
    final recent = recentContext.length > 2600
        ? recentContext.substring(recentContext.length - 2600)
        : recentContext;
    final latest = userText.length > 1100
        ? userText.substring(userText.length - 1100)
        : userText;
    final jev = await jevGateway.choose(
      state: {'recent_context': recent, 'latest_user_text': latest},
      instruction: instruction,
      options: const {
        'breakthrough': 'The latest interaction has a clear and natural emotional tipping point for her.',
        'wait': 'No clear emotional tipping point in the latest interaction.',
      },
      cancellationToken: cancellationToken,
      usageLane: 'playful_breakthrough',
    );
    if (jev == 'breakthrough') return true;
    if (jev == 'wait') return false;
    cancellationToken?.throwIfCancelled();
    if (fallbackClassifier != null) return fallbackClassifier!(latest, recent);
    try {
      final output = StringBuffer();
      await for (final delta in client.streamChat(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.high,
        thinking: false,
        maxTokens: 55,
        requestTimeout: const Duration(seconds: 8),
        cancellationToken: cancellationToken,
        usageLane: 'playful_breakthrough',
        messages: [
          {'role': 'system', 'content': '$instruction Return only JSON: {"decision":"breakthrough|wait"}.'},
          {'role': 'user', 'content': 'RECENT_CONTEXT:\n$recent\nLATEST_USER_TEXT:\n$latest'},
        ],
      )) {
        if (delta.content.isNotEmpty) output.write(delta.content);
      }
      cancellationToken?.throwIfCancelled();
      final raw = output.toString();
      final start = raw.indexOf('{'), end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final parsed = jsonDecode(raw.substring(start, end + 1));
      return switch (parsed is Map ? parsed['decision'] : null) {
        'breakthrough' => true,
        'wait' => false,
        _ => null,
      };
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
