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

  static const instruction = 'The companion is in her normal adult form and her '
      'playful heat is already fully charged at 100. Look at the latest user '
      'message together with the previous 3-5 exchanges. Does the accumulated '
      'teasing, her own mischievous pushback, or strong flustered embarrassment '
      'now make her naturally lose composure? A continuous escalation can '
      'reach this tipping point without a brand-new event. Being fully charged '
      'is readiness, not an obligation to transform. Ordinary affection, '
      'routine talk, repetition without escalation, real anger, distress and '
      'serious help can comfortably remain wait. Judge the interpersonal '
      'situation and its accumulated intensity, not literal keywords.';

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
      state: {'recent_context': recent, 'latest_user_text': latest,
        'current_form': 'normal', 'heat': 100},
      instruction: instruction,
      options: const {
        'breakthrough': 'The latest exchange reaches a natural loss of composure through cumulative teasing, mischief or intense embarrassment.',
        'wait': 'She remains composed; full heat alone does not require a transformation.',
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
