import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/final_reply_failure_policy.dart';
import '../ai/model_profile.dart';
import 'cedar_toy_activity.dart';

enum CedarAgentDisposition {
  act('act'),
  inviteUser('invite_user'),
  awaitUser('await_user'),
  awaitRemote('await_remote'),
  complete('complete');

  const CedarAgentDisposition(this.key);
  final String key;

  static CedarAgentDisposition? tryParse(Object? value) {
    final key = value?.toString().trim() ?? '';
    for (final item in values) {
      if (item.key == key) return item;
    }
    return null;
  }
}

class CedarAgentDecision {
  const CedarAgentDecision({
    required this.disposition,
    required this.participationMode,
    this.action = '',
    this.params = const <String, Object?>{},
    this.roomReplyIntent = '',
    this.reason = '',
    this.resumeAfterSeconds = 0,
  });

  final CedarAgentDisposition disposition;
  final CedarParticipationMode participationMode;
  final String action;
  final Map<String, Object?> params;
  final String roomReplyIntent;
  final String reason;
  final int resumeAfterSeconds;
}

class CedarAgentGameChoice {
  const CedarAgentGameChoice({required this.game, this.title = ''});
  final String game;
  final String title;
}

class CedarAgentOutcomeClassification {
  const CedarAgentOutcomeClassification({
    required this.nextActor,
    required this.shareLevel,
    required this.resumeAfterSeconds,
  });

  final String nextActor;
  final String shareLevel;
  final int resumeAfterSeconds;
}

abstract interface class CedarAgentDecisionModel {
  Future<CedarAgentGameChoice> chooseGame({
    required String apiKey,
    required String endpoint,
    required String instruction,
  });

  Future<CedarAgentDecision> decideTurn({
    required String apiKey,
    required String endpoint,
    required String instruction,
  });

  Future<CedarAgentOutcomeClassification> classifyOutcome({
    required String apiKey,
    required String endpoint,
    required String instruction,
  });
}

/// Uses a required native function call for Cedar control decisions.
///
/// The previous JSON-body path could spend the whole token budget in hidden
/// reasoning and then expose an empty/truncated `content` string. A native
/// call keeps the control payload separate from prose and lets us reject an
/// incomplete stream before any game state is changed.
class DeepSeekCedarAgentDecisionModel implements CedarAgentDecisionModel {
  DeepSeekCedarAgentDecisionModel({
    required this.client,
    this.onRetry,
  });

  static const maxAttempts = 2;

  final DeepSeekClient client;
  final Future<void> Function(Object error)? onRetry;

  @override
  Future<CedarAgentGameChoice> chooseGame({
    required String apiKey,
    required String endpoint,
    required String instruction,
  }) async {
    final payload = await _requiredCall(
      apiKey: apiKey,
      endpoint: endpoint,
      instruction: instruction,
      name: 'cedar_choose_game',
      description: '从真实 Cedar 游戏目录选择一项。',
      properties: const <String, Object?>{
        'game': <String, Object?>{
          'type': 'string',
          'description': '目录中的精确游戏 ID。',
        },
        'title': <String, Object?>{
          'type': 'string',
          'description': '目录返回的显示名。',
        },
      },
      requiredFields: const <String>['game'],
    );
    return CedarAgentGameChoice(
      game: payload['game']?.toString().trim() ?? '',
      title: payload['title']?.toString().trim() ?? '',
    );
  }

  @override
  Future<CedarAgentDecision> decideTurn({
    required String apiKey,
    required String endpoint,
    required String instruction,
  }) async {
    final payload = await _requiredCall(
      apiKey: apiKey,
      endpoint: endpoint,
      instruction: instruction,
      name: 'cedar_agent_turn',
      description: '依据玩家指南和最新真实状态决定本回合行动或等待。',
      properties: const <String, Object?>{
        'participation_mode': <String, Object?>{
          'type': 'string',
          'enum': <String>['solo', 'co_play', 'multiplayer', 'hybrid'],
        },
        'disposition': <String, Object?>{
          'type': 'string',
          'enum': <String>[
            'act',
            'invite_user',
            'await_user',
            'await_remote',
            'complete',
          ],
        },
        'action': <String, Object?>{
          'type': 'string',
          'description': 'disposition=act 时填写指南中的精确 action。',
        },
        'params': <String, Object?>{
          'type': 'object',
          'description': '直接提交给该 action 的参数对象。',
          'additionalProperties': true,
        },
        'room_reply_intent': <String, Object?>{
          'type': 'string',
          'description': '共玩房间内想表达的简短内部意图；不是最终台词。',
        },
        'reason': <String, Object?>{
          'type': 'string',
          'description': '只说明依据哪条真实状态，不写攻略或长分析。',
        },
        'resume_after_seconds': <String, Object?>{
          'type': 'integer',
          'minimum': 0,
          'maximum': 3600,
          'description': '仅远端/游戏明确要求等待时填写；否则为 0。',
        },
      },
      requiredFields: const <String>['participation_mode', 'disposition'],
    );
    final disposition = CedarAgentDisposition.tryParse(payload['disposition']);
    final mode = CedarParticipationMode.fromKey(
      payload['participation_mode']?.toString(),
    );
    if (disposition == null || mode == CedarParticipationMode.unknown) {
      throw const FormatException('invalid_cedar_agent_turn_disposition');
    }
    final rawParams = payload['params'];
    return CedarAgentDecision(
      disposition: disposition,
      participationMode: mode,
      action: payload['action']?.toString().trim() ?? '',
      params: rawParams is Map
          ? rawParams.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{},
      roomReplyIntent:
          payload['room_reply_intent']?.toString().trim() ?? '',
      reason: payload['reason']?.toString().trim() ?? '',
      resumeAfterSeconds:
          ((payload['resume_after_seconds'] as num?)?.toInt() ?? 0)
              .clamp(0, 3600)
              .toInt(),
    );
  }

  @override
  Future<CedarAgentOutcomeClassification> classifyOutcome({
    required String apiKey,
    required String endpoint,
    required String instruction,
  }) async {
    final payload = await _requiredCall(
      apiKey: apiKey,
      endpoint: endpoint,
      instruction: instruction,
      name: 'cedar_classify_outcome',
      description: '只分类真实游戏 Outcome 的下一参与者和分享级别。',
      properties: const <String, Object?>{
        'next_actor': <String, Object?>{
          'type': 'string',
          'enum': <String>['companion', 'user', 'shared', 'wait', 'finished'],
        },
        'share_level': <String, Object?>{
          'type': 'string',
          'enum': <String>['quiet', 'notable', 'required'],
        },
        'resume_after_seconds': <String, Object?>{
          'type': 'integer',
          'minimum': 0,
          'maximum': 3600,
        },
      },
      requiredFields: const <String>['next_actor', 'share_level'],
      maxTokens: 700,
    );
    final actor = payload['next_actor']?.toString().trim() ?? '';
    final share = payload['share_level']?.toString().trim() ?? '';
    if (!const <String>{
          'companion',
          'user',
          'shared',
          'wait',
          'finished',
        }.contains(actor) ||
        !const <String>{'quiet', 'notable', 'required'}.contains(share)) {
      throw const FormatException('invalid_cedar_outcome_classification');
    }
    final rawResume = (payload['resume_after_seconds'] as num?)?.toInt() ?? 0;
    return CedarAgentOutcomeClassification(
      nextActor: actor,
      shareLevel: share,
      resumeAfterSeconds: rawResume.clamp(0, 3600).toInt(),
    );
  }

  Future<Map<String, dynamic>> _requiredCall({
    required String apiKey,
    required String endpoint,
    required String instruction,
    required String name,
    required String description,
    required Map<String, Object?> properties,
    required List<String> requiredFields,
    int maxTokens = 1800,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final builders = <int, _CedarToolCallBuilder>{};
        var terminal = false;
        var finishReason = '';
        await for (final delta in client.streamChat(
          apiKey: apiKey,
          model: DeepSeekModelProfile.flash,
          endpoint: endpoint,
          thinking: attempt == 0,
          effort: attempt == 0 ? ReasoningEffort.medium : ReasoningEffort.low,
          maxTokens: maxTokens,
          toolChoice: 'required',
          tools: <Map<String, Object?>>[
            <String, Object?>{
              'type': 'function',
              'function': <String, Object?>{
                'name': name,
                'description': description,
                'parameters': <String, Object?>{
                  'type': 'object',
                  'properties': properties,
                  'required': requiredFields,
                  'additionalProperties': false,
                },
              },
            },
          ],
          messages: <Map<String, Object?>>[
            <String, Object?>{'role': 'system', 'content': instruction},
          ],
        )) {
          if (delta.done || delta.finishReason != null) terminal = true;
          if (delta.finishReason != null) finishReason = delta.finishReason!;
          for (final fragment in delta.toolCallDeltas) {
            builders
                .putIfAbsent(
                  fragment.index,
                  () => _CedarToolCallBuilder(fragment.index),
                )
                .add(fragment);
          }
        }
        if (!terminal ||
            FinalReplyFailurePolicy.isIncompleteFinishReason(finishReason)) {
          throw const FormatException('incomplete_cedar_native_call');
        }
        if (builders.length != 1) {
          throw const FormatException('missing_cedar_native_call');
        }
        final call = builders.values.single.build();
        if (call.name != name || call.arguments.trim().isEmpty) {
          throw const FormatException('unexpected_cedar_native_call');
        }
        final decoded = jsonDecode(call.arguments);
        if (decoded is! Map) {
          throw const FormatException('invalid_cedar_native_arguments');
        }
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      } catch (error) {
        lastError = error;
        final retryable = error is FormatException ||
            FinalReplyFailurePolicy.isTransient(error);
        if (!retryable || attempt + 1 >= maxAttempts) rethrow;
        final callback = onRetry;
        if (callback != null) await callback(error);
      }
    }
    throw lastError!;
  }
}

final class _CedarToolCallBuilder {
  _CedarToolCallBuilder(this.index);

  final int index;
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  void add(DeepSeekToolCallDelta fragment) {
    if (fragment.id.isNotEmpty) id = fragment.id;
    if (fragment.name.isNotEmpty) name = fragment.name;
    if (fragment.argumentsFragment.isNotEmpty) {
      arguments.write(fragment.argumentsFragment);
    }
  }

  DeepSeekToolCall build() => DeepSeekToolCall(
        id: id.isEmpty ? 'cedar_call_$index' : id,
        name: name,
        arguments: arguments.toString(),
      );
}
