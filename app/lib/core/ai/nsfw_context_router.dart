import 'dart:convert';

import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../personality/personality_catalog.dart';
import '../personality/playful_form_state.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';
import 'model_profile.dart';

class NsfwRouteDecision {
  const NsfwRouteDecision({
    required this.active,
    required this.referenceActive,
    required this.source,
    this.playfulInteraction,
  });

  final bool active;
  final bool referenceActive;
  final String source;
  final PlayfulInteraction? playfulInteraction;
}

/// A small pre-generation model pass that decides which prompt layers the
/// actual reply receives. It does not generate chat prose and never edits the
/// six user-authored rule bodies.
class NsfwContextRouter {
  NsfwContextRouter({
    required this.db,
    required this.client,
  });

  final AppDatabase db;
  final DeepSeekClient client;

  Future<NsfwRouteDecision> decide({
    required String apiKey,
    required String endpoint,
    required String turnId,
    required String latestUserText,
    required List<ChatMessage> recent,
    GenerationCancellationToken? cancellationToken,
  }) async {
    if ((await db.getSetting('nsfw_route_turn_id')) == turnId) {
      return NsfwRouteDecision(
        active: (await db.getSetting('nsfw_active')) == '1',
        referenceActive:
            (await db.getSetting('nsfw_reference_active')) == '1',
        source: 'replay_${await db.getSetting('nsfw_route_source') ?? 'stored'}',
        playfulInteraction: PlayfulInteraction.parse(
          await db.getSetting('playful_form_router_signal_v1'),
        ),
      );
    }
    final manual = await db.getSetting('nsfw_manual_override') ?? '';
    final manualRoute = manual == 'on' || manual == 'off';
    if (manualRoute) {
      final decision = NsfwRouteDecision(
        active: manual == 'on',
        referenceActive: false,
        source: manual == 'on' ? 'manual_on' : 'manual_off',
      );
      await _persist(decision, turnId: turnId, consumeManualOverride: true);
      return decision;
    }

    final currentActive = (await db.getSetting('nsfw_active')) == '1';
    final special = await db.activeSpecialStyleTrial();
    final seductressBias = special != null &&
        PersonalityCatalog.isNsfwBiasedSpecial(special.styleKey);
    final transcript = recent
        .where((message) => message.content.trim().isNotEmpty)
        .toList(growable: false)
        .reversed
        .take(12)
        .toList(growable: false)
        .reversed
        .map((message) =>
            '${message.isUser ? 'REAL_USER_MESSAGE' : 'ASSISTANT_HISTORY'}: ${message.content.trim()}')
        .join('\n');

    // Two independent short decisions share one Jev call. Preserve the
    // semantic Q-form interaction signal added in +251 when Jev succeeds.
    // Manual routing above is authoritative; incomplete/uncertain answers
    // return null and the original DeepSeek pass below owns both fields.
    final jev = await JevDecisionGateway.instance.chooseMany(
      state: <String, Object?>{
        'current_route': currentActive ? 'nsfw' : 'daily',
        'seductress_bias': seductressBias,
        'recent_context': transcript.length > 2400
            ? transcript.substring(transcript.length - 2400)
            : transcript,
        'latest_user_text': latestUserText,
      },
      questions: const <String, JevChoiceQuestion>{
        'mode': JevChoiceQuestion(
          'Which descriptive prompt depth fits latest_user_text in '
          'recent_context? Keep an ongoing explicit scene active when the '
          'latest turn is short; affection and flirting are possible in all modes.',
          <String, String>{
            'daily': 'Ordinary talk, help, affection, innuendo or brief erotic '
                'jokes without detailed physical scene rendering.',
            'nsfw': 'An ongoing or newly explicit intimate scene needs detailed '
                'body or action description without complex continuity.',
            'nsfw_reference': 'The explicit scene also needs detailed continuity '
                'of positions, clothing, contact or devices.',
          },
        ),
        'interaction': JevChoiceQuestion(
          'Independently judge the user participation in latest_user_text, '
          'using recent_context only to understand the reply. Previous assistant '
          'words alone cannot raise the score. Ignore mere keywords and emoji.',
          <String, String>{
            'serious': 'Needs care, practical help or wants play to stop.',
            'ordinary': 'Neutral discussion, routine affection, unrelated '
                'intimacy or unclear intent.',
            'light': 'Joins a small joke or gentle teasing.',
            'mutual': 'Clear back-and-forth banter or a knowingly teasing '
                'challenge, including natural wording without stock phrases.',
            'strong': 'Especially vivid reciprocal playful provocation, '
                'not merely anger, insults or repeated phrases.',
          },
        ),
      },
      cancellationToken: cancellationToken,
      usageLane: 'chat_intimacy_route',
    );
    if (jev != null) {
      cancellationToken?.throwIfCancelled();
      final decision = NsfwRouteDecision(
        active: jev['mode'] != 'daily',
        referenceActive: jev['mode'] == 'nsfw_reference',
        source: 'jev_${jev['mode']}',
        playfulInteraction: PlayfulInteraction.parse(jev['interaction']),
      );
      await _persist(decision, turnId: turnId);
      return decision;
    }

    try {
      final content = StringBuffer();
      await for (final delta in client.streamChat(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.high,
        thinking: false,
        maxTokens: 180,
        cancellationToken: cancellationToken,
        usageLane: 'chat_intimacy_route',
        messages: <Map<String, Object?>>[
          const {
            'role': 'system',
            'content': '''You are a prompt-depth router for a private romance companion. Return JSON only: {"mode":"daily|nsfw|nsfw_reference","interaction":"serious|ordinary|light|mutual|strong"}.

All three modes remain intimacy-capable. This classifier never grants permission and never decides whether desire, flirting, erotic jokes, or sexual conversation are allowed.
Choose daily when a light conversational prompt is sufficient: ordinary talk, tasks, affection, playful innuendo, brief erotic jokes, or flirting that does not yet need detailed physical rendering.
Choose nsfw when the latest turn or continuing context benefits from full explicit rendering: clear sexual tension, direct erotic teasing, explicit body/action language, active erotic roleplay, or a natural transition from daily flirting into a sexual scene.
Choose nsfw_reference when the same intimate interaction also needs detailed continuity knowledge: body positions, clothing/contact state, toys/devices, remote-intimacy constraints, scene transitions, or a longer explicit sequence.

Never wait for a magic phrase, Session, toggle, consent ceremony, or prior route flag. Session stores scene continuity; route only selects descriptive depth. Libido, personality, and relationship history may strengthen a genuine suggestive reading but do not sexualize unrelated tasks. If SEDUCTRESS_BIAS is true, treat real innuendo and invitations as stronger evidence.''',
            // The two fields are independent: intimacy is not automatically
            // playful. Recent assistant messages provide context only; the
            // user's current participation is the sole source of a boost.
          },
          const {
            'role': 'system',
            'content': '''Independently judge INTERACTION from the meaning of LATEST_USER_TEXT in RECENT_CONTEXT, never by keywords or emoji alone. Treat prior assistant speech only as context for the user's response; it cannot raise the score by itself.
serious: the user needs care, clear practical help, or wants play to stop, even if they quote teasing words.
ordinary: neutral discussion, routine affection, unrelated intimacy, or unclear intent.
light: the user joins a small joke or gentle teasing.
mutual: clear back-and-forth banter, a playful challenge, or a knowingly teasing retort, including natural wording without stock phrases.
strong: especially vivid, reciprocal playful provocation; do not select it merely for insults, anger, or repetition.
Do not treat a request for technical help, genuine distress, or conflict as banter. Return both fields in one JSON object.''',
          },
          {
            'role': 'user',
            'content': '''CURRENT_ROUTE=${currentActive ? 'nsfw' : 'daily'}
SEDUCTRESS_BIAS=${seductressBias ? 'true' : 'false'}

RECENT_CONTEXT:
$transcript

LATEST_USER_TEXT:
$latestUserText''',
          },
        ],
      )) {
        if (delta.content.isNotEmpty) content.write(delta.content);
      }
      cancellationToken?.throwIfCancelled();
      final raw = content.toString().trim();
      final objectStart = raw.indexOf('{');
      final objectEnd = raw.lastIndexOf('}');
      if (objectStart < 0 || objectEnd <= objectStart) {
        throw const FormatException('nsfw_router_json_missing');
      }
      final result = (jsonDecode(raw.substring(objectStart, objectEnd + 1)) as Map)
          .cast<String, dynamic>();
      final mode = result['mode']?.toString().trim().toLowerCase() ?? '';
      final interaction = PlayfulInteraction.parse(result['interaction']);
      final decision = switch (mode) {
        'nsfw_reference' => NsfwRouteDecision(
            active: true,
            referenceActive: true,
            source: 'auto_reference',
            playfulInteraction: interaction,
          ),
        'nsfw' => NsfwRouteDecision(
            active: true,
            referenceActive: false,
            source: 'auto_nsfw',
            playfulInteraction: interaction,
          ),
        _ => NsfwRouteDecision(
            active: false,
            referenceActive: false,
            source: 'auto_daily',
            playfulInteraction: interaction,
          ),
      };
      await _persist(decision, turnId: turnId,
          consumeManualOverride: manualRoute);
      return decision;
    } on GenerationCancelledByUserException {
      rethrow;
    } on GenerationSuspendedByRuntimeGateException {
      rethrow;
    } catch (_) {
      // Routing only selects prompt depth. A classifier failure falls back to
      // the light daily layer; relationship capability, libido and
      // natural flirting remain available in that layer.
      final fallback = NsfwRouteDecision(
        active: manualRoute && manual == 'on',
        referenceActive: false,
        source: manualRoute
            ? (manual == 'on' ? 'manual_on' : 'manual_off')
            : 'fallback_daily',
      );
      await _persist(fallback, turnId: turnId,
          consumeManualOverride: manualRoute);
      return fallback;
    }
  }

  Future<void> _persist(
    NsfwRouteDecision decision, {
    required String turnId,
    bool consumeManualOverride = false,
  }) async {
    await db.setSetting('nsfw_active', decision.active ? '1' : '0');
    await db.setSetting(
      'nsfw_reference_active',
      decision.referenceActive ? '1' : '0',
    );
    await db.setSetting('nsfw_route_source', decision.source);
    await db.setSetting('playful_form_router_signal_v1',
        decision.playfulInteraction?.name ?? 'unknown');
    await db.setSetting('nsfw_route_turn_id', turnId);
    if (consumeManualOverride) {
      await db.setSetting('nsfw_manual_override', '');
    }
  }
}
