import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../ai/model_profile.dart';
import '../models/immersive_room.dart';

class ImmersiveNsfwDecision {
  const ImmersiveNsfwDecision({
    required this.active,
    required this.source,
  });

  final bool active;
  final String source;
}

/// Selects whether the room-specific adult novel source is needed this turn.
/// This state is deliberately separate from ordinary chat's global NSFW route.
class ImmersiveNsfwRouter {
  const ImmersiveNsfwRouter(this.client);

  final DeepSeekClient client;

  Future<ImmersiveNsfwDecision> decide({
    required String apiKey,
    required String endpoint,
    required ImmersiveRoom room,
    required String latestUserText,
    required List<ImmersiveMessage> recent,
    GenerationCancellationToken? cancellationToken,
  }) async {
    final manual = room.nsfwManualOverride;
    if (manual == 'on' || manual == 'off') {
      return ImmersiveNsfwDecision(
        active: manual == 'on',
        source: manual == 'on' ? 'manual_on' : 'manual_off',
      );
    }

    final transcript = recent
        .where((message) => message.content.trim().isNotEmpty)
        .toList(growable: false)
        .reversed
        .take(12)
        .toList(growable: false)
        .reversed
        .map(
          (message) =>
              '${message.isUser ? 'REAL_USER_MESSAGE' : 'ASSISTANT_HISTORY'}: ${message.content.trim()}',
        )
        .join('\n');

    try {
      final content = StringBuffer();
      await for (final delta in client.streamChat(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.high,
        thinking: false,
        maxTokens: 80,
        cancellationToken: cancellationToken,
        messages: <Map<String, Object?>>[
          const {
            'role': 'system',
            'content': '''你只负责判断沉浸小说本轮是否需要成人描写规则。只返回 JSON：{"mode":"daily|nsfw"}。

daily：普通剧情、日常互动、轻度暧昧、没有进入成人身体细节的场景。
nsfw：正在发生或自然进入明确成人性场景、需要露骨身体/动作细节、姿势衣物接触连续性或长篇成人阶段推进。

结合最近剧情保持连续性；不要因为单个含糊词误开启，也不要在成人场景仍连续进行时仅因本轮措辞简短就关闭。该判断只选择规则深度，不生成小说正文。''',
          },
          {
            'role': 'user',
            'content': '''CURRENT_ROUTE=${room.nsfwActive ? 'nsfw' : 'daily'}

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
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) {
        throw const FormatException('immersive_nsfw_router_json_missing');
      }
      final result =
          (jsonDecode(raw.substring(start, end + 1)) as Map).cast<String, dynamic>();
      final mode = result['mode']?.toString().trim().toLowerCase();
      return ImmersiveNsfwDecision(
        active: mode == 'nsfw',
        source: mode == 'nsfw' ? 'auto_nsfw' : 'auto_daily',
      );
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      // Routing must never break a long room turn. Preserve the last known
      // room state if the tiny classifier request is unavailable.
      return ImmersiveNsfwDecision(
        active: room.nsfwActive,
        source: 'fallback_previous',
      );
    }
  }
}
