import 'dart:convert';

import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../personality/personality_catalog.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';

class NsfwRouteDecision {
  const NsfwRouteDecision({
    required this.active,
    required this.referenceActive,
    required this.source,
  });

  final bool active;
  final bool referenceActive;
  final String source;
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
      );
    }
    final manual = await db.getSetting('nsfw_manual_override') ?? '';
    if (manual == 'on' || manual == 'off') {
      final decision = NsfwRouteDecision(
        active: manual == 'on',
        referenceActive: false,
        source: manual == 'on' ? 'manual_on' : 'manual_off',
      );
      await _persist(
        decision,
        turnId: turnId,
        consumeManualOverride: true,
      );
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

    try {
      final content = StringBuffer();
      await for (final delta in client.streamChat(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.high,
        thinking: false,
        maxTokens: 120,
        cancellationToken: cancellationToken,
        messages: <Map<String, Object?>>[
          const {
            'role': 'system',
            'content': '''You are a routing classifier for an adult private AI-companion chat. Return JSON only: {"mode":"daily|nsfw|nsfw_reference"}.

Choose daily for ordinary conversation, affection, nonsexual romance, neutral tasks, or when sexual context is absent.
Choose nsfw when the latest turn or clearly continuing recent context is consensual adult sexual conversation, explicit erotic roleplay, sexual action, or a direct request for explicit adult description.
Choose nsfw_reference only when that adult turn also benefits from the detailed reference layer: body-position continuity, clothing/contact state, toys/devices, remote-intimacy constraints, scene transitions, or an extended explicit scene.

Do not require a magic phrase, an already-open Session, or an earlier adult-mode flag. Session is scene continuity, not permission. Do not infer sex merely from libido, personality labels, affection, or an isolated ambiguous word. If SEDUCTRESS_BIAS is true, treat genuinely suggestive adult flirting and invitations as stronger evidence, but keep unrelated normal conversation daily.''',
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
      final decision = switch (mode) {
        'nsfw_reference' => const NsfwRouteDecision(
            active: true,
            referenceActive: true,
            source: 'auto_reference',
          ),
        'nsfw' => const NsfwRouteDecision(
            active: true,
            referenceActive: false,
            source: 'auto_nsfw',
          ),
        _ => const NsfwRouteDecision(
            active: false,
            referenceActive: false,
            source: 'auto_daily',
          ),
      };
      await _persist(decision, turnId: turnId);
      return decision;
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      // Routing must never make a durable chat turn unrecoverable. A failed
      // classifier falls back to ordinary chat so an unrelated turn cannot be
      // sexualized merely because the previous turn was adult. The user can
      // still force the next turn on with the visible button.
      const fallback = NsfwRouteDecision(
        active: false,
        referenceActive: false,
        source: 'fallback_daily',
      );
      await _persist(fallback, turnId: turnId);
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
    await db.setSetting('nsfw_route_turn_id', turnId);
    if (consumeManualOverride) {
      await db.setSetting('nsfw_manual_override', '');
    }
  }
}
