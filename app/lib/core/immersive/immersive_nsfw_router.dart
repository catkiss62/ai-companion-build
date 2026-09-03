import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../ai/model_profile.dart';
import '../models/immersive_room.dart';

enum ImmersiveClimaxEvent {
  none('none'),
  aiRelease('ai_release'),
  userNear('user_near'),
  userRelease('user_release'),
  hold('hold');

  const ImmersiveClimaxEvent(this.key);
  final String key;

  static ImmersiveClimaxEvent fromKey(Object? value) {
    final key = value?.toString().trim().toLowerCase() ?? '';
    return values.firstWhere(
      (item) => item.key == key,
      orElse: () => ImmersiveClimaxEvent.none,
    );
  }
}

class ImmersiveNsfwDecision {
  const ImmersiveNsfwDecision({
    required this.active,
    required this.source,
    this.climaxEvent = ImmersiveClimaxEvent.none,
  });

  final bool active;
  final String source;
  final ImmersiveClimaxEvent climaxEvent;

  String get turnDirective => switch (climaxEvent) {
        ImmersiveClimaxEvent.none =>
            '本轮没有已确认的高潮或射精状态跳转；只按当前现场推进一个节拍。',
        ImmersiveClimaxEvent.aiRelease =>
            '上一轮 AI 角色已在高潮临界；用户本轮允许她先释放，且没有表示自己濒临或已射精。本轮以女性 AI 单独一次高潮为主要事件；必须有说出口的激烈叠词叫声，但不得写用户射精，也不得结束 Session。',
        ImmersiveClimaxEvent.userNear =>
            '用户本轮只宣告自己濒临射精，尚未射精。AI 角色可以迎接、积累、继续逼近或忍住，但本轮不得写用户射精，必须停在等待用户明确释放的位置。',
        ImmersiveClimaxEvent.userRelease =>
            '用户本轮已明确表达已经或现在立即射精。本轮以用户射精与女性 AI 同时高潮为唯一主要阶段变化；AI 必须有说出口的激烈叠词尖叫或哭腔。不在同轮跳到清理、事后或 Session 结束。',
        ImmersiveClimaxEvent.hold =>
            '用户本轮要求忍住、等待，或在此前已宣告濒临后只要求继续积累。本轮任何一方都不得释放，必须留在临界。',
      };
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
    if (manual == 'off') {
      return ImmersiveNsfwDecision(
        active: false,
        source: 'manual_off',
      );
    }

    // Explicit climax language is a state transition, not a style guess. Do
    // not let the small routing model blur "nearing" into "released" or
    // return none for a clear user instruction.
    final explicitEvent = deterministicClimaxEvent(
      latestUserText,
      nsfwContext: manual == 'on' || room.nsfwActive,
    );
    final unresolvedNear = explicitEvent == ImmersiveClimaxEvent.none &&
        (manual == 'on' || room.nsfwActive) &&
        hasUnresolvedUserNear(recent);
    final deterministicEvent = unresolvedNear
        ? ImmersiveClimaxEvent.hold
        : explicitEvent;
    if (deterministicEvent != ImmersiveClimaxEvent.none) {
      return ImmersiveNsfwDecision(
        active: true,
        source: manual == 'on'
            ? 'manual_on_${deterministicEvent.key}'
            : 'deterministic_${deterministicEvent.key}',
        climaxEvent: deterministicEvent,
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
        maxTokens: 120,
        cancellationToken: cancellationToken,
        messages: <Map<String, Object?>>[
          const {
            'role': 'system',
            'content': '''你只负责判断沉浸小说本轮的规则深度和高潮语义事件。只返回 JSON：{"mode":"daily|nsfw","climax_event":"none|ai_release|user_near|user_release|hold"}。

daily：普通剧情、日常互动、轻度暧昧、没有进入成人身体细节的场景。
nsfw：正在发生或自然进入明确成人性场景、需要露骨身体/动作细节、姿势衣物接触连续性或长篇成人阶段推进。

高潮事件：none=没有已确认的释放跳转；ai_release=上一轮女性AI已明确停在高潮临界，用户本轮让她先高潮，或只要求继续/加快/更激烈且未表示自己濒临；user_near=用户只表示“我快射了/我要射了”等濒临宣言，尚未射精；user_release=用户明确表达已经或现在立即射精；hold=用户要求忍住/等待，或在之前已濒临后只说继续积累。
“快射/要射”绝对不是“已射”；否定、假设、引用和含糊表达均不判定为 user_release。若用户先前已进入 user_near，之后没有明确释放表达，则保持 hold。

结合最近剧情保持连续性；不要因为单个含糊词误开启，也不要在成人场景仍连续进行时仅因本轮措辞简短就关闭。该判断只选择规则深度和语义事件，不生成小说正文。''',
          },
          {
            'role': 'user',
            'content': '''CURRENT_ROUTE=${room.nsfwActive ? 'nsfw' : 'daily'}
FORCED_MODE=${manual == 'on' ? 'nsfw' : 'none'}

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
      final active = manual == 'on' || mode == 'nsfw';
      return ImmersiveNsfwDecision(
        active: active,
        source: manual == 'on'
            ? 'manual_on'
            : active
                ? 'auto_nsfw'
                : 'auto_daily',
        climaxEvent: active
            ? ImmersiveClimaxEvent.fromKey(result['climax_event'])
            : ImmersiveClimaxEvent.none,
      );
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      // Routing must never break a long room turn. Preserve the last known
      // room state if the tiny classifier request is unavailable.
      return ImmersiveNsfwDecision(
        active: manual == 'on' || room.nsfwActive,
        source: manual == 'on' ? 'manual_on_fallback' : 'fallback_previous',
        climaxEvent: (manual == 'on' || room.nsfwActive)
            ? fallbackClimaxEvent(latestUserText)
            : ImmersiveClimaxEvent.none,
      );
    }
  }

  static ImmersiveClimaxEvent fallbackClimaxEvent(String text) {
    return deterministicClimaxEvent(text, nsfwContext: true);
  }

  static ImmersiveClimaxEvent deterministicClimaxEvent(
    String text, {
    required bool nsfwContext,
  }) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    final explicitHold =
        RegExp(r'(憋住|别高潮|不要高潮|别射|不要射)').hasMatch(normalized) ||
            (normalized.contains('忍住') && !normalized.contains('忍不住'));
    if (explicitHold ||
        (nsfwContext && RegExp(r'(等一下|先别)').hasMatch(normalized))) {
      return ImmersiveClimaxEvent.hold;
    }
    if (RegExp(r'(快射|要射了|快要射|快不行了|快忍不住)').hasMatch(normalized)) {
      return ImmersiveClimaxEvent.userNear;
    }
    if (RegExp(r'(我射了|已经射|射出来了|现在射|立即射|直接射|射进来|射进去)').hasMatch(normalized)) {
      return ImmersiveClimaxEvent.userRelease;
    }
    if (RegExp(r'(你先高潮|高潮吧|你去吧|你释放)').hasMatch(normalized)) {
      return ImmersiveClimaxEvent.aiRelease;
    }
    return ImmersiveClimaxEvent.none;
  }

  static bool hasUnresolvedUserNear(List<ImmersiveMessage> recent) {
    for (final message in recent.reversed.take(12)) {
      if (!message.isUser) continue;
      final event = deterministicClimaxEvent(
        message.content,
        nsfwContext: true,
      );
      if (event == ImmersiveClimaxEvent.userRelease) return false;
      if (event == ImmersiveClimaxEvent.userNear ||
          event == ImmersiveClimaxEvent.hold) {
        return true;
      }
    }
    return false;
  }
}
