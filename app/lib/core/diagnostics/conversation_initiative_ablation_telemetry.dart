import 'dart:convert';

import '../database/app_database.dart';
import '../desire/conversation_initiative_policy.dart';
import '../desire/conversation_outcome_verifier.dart';

/// Content-free fingerprint of the prompt responsibilities that were present
/// for one generated turn. Prompt bodies are inspected in memory and are never
/// persisted by this diagnostic.
class PromptResponsibilityShape {
  const PromptResponsibilityShape({
    required this.identity,
    required this.ruleBundle,
    required this.behaviorWorldBook,
    required this.personalitySpectrum,
    required this.humorWorldBook,
    required this.conversationPlan,
    required this.selectedThought,
    required this.dynamicMoe,
    required this.dialogueExpressionPlan,
    required this.visibleInnerVoice,
    required this.finalReminder,
    required this.operationalTruth,
    required this.personalityAnchor,
    required this.intimacyPreflight,
    required this.systemMessageCount,
    required this.systemCharacterBucket,
  });

  final bool identity;
  final bool ruleBundle;
  final bool behaviorWorldBook;
  final bool personalitySpectrum;
  final bool humorWorldBook;
  final bool conversationPlan;
  final bool selectedThought;
  final bool dynamicMoe;
  final bool dialogueExpressionPlan;
  final bool visibleInnerVoice;
  final bool finalReminder;
  final bool operationalTruth;
  final bool personalityAnchor;
  final bool intimacyPreflight;
  final int systemMessageCount;
  final String systemCharacterBucket;

  static const layerKeys = <String>[
    'identity',
    'ruleBundle',
    'behaviorWorldBook',
    'personalitySpectrum',
    'humorWorldBook',
    'conversationPlan',
    'selectedThought',
    'dynamicMoe',
    'dialogueExpressionPlan',
    'visibleInnerVoice',
    'finalReminder',
    'operationalTruth',
    'personalityAnchor',
    'intimacyPreflight',
  ];

  factory PromptResponsibilityShape.fromMessages(
    List<Map<String, Object?>> messages,
  ) {
    final system = messages
        .where((message) => message['role'] == 'system')
        .map((message) => message['content']?.toString() ?? '')
        .toList(growable: false);
    final joined = system.join('\n');
    bool has(String marker) => joined.contains(marker);
    final characters = system.fold<int>(0, (sum, item) => sum + item.length);
    return PromptResponsibilityShape(
      identity: has('女性 AI 伴侣') || has('RUNTIME_IDENTITY'),
      ruleBundle: has('RULE_LAYER') || has('规则层'),
      behaviorWorldBook:
          has('WORLD_BOOK') || has('世界书') || has('REFERENCE_DOCUMENT'),
      personalitySpectrum: has('性格光谱'),
      humorWorldBook: has('造梗能力'),
      conversationPlan: has('CURRENT CONVERSATION MOVE'),
      selectedThought: has('SELECTED_THOUGHT_DATA') &&
          !has('SELECTED_THOUGHT_DATA】暂无'),
      dynamicMoe: has('本轮动态表达倾向'),
      dialogueExpressionPlan: has('本轮对话表达计划'),
      visibleInnerVoice: has('可见思考') || has('reasoning_content'),
      finalReminder: has('本轮最终呈现提醒'),
      operationalTruth: has('真实工具结果') || has('可核验操作'),
      personalityAnchor: has('PERSONALITY_EXECUTION_ANCHOR'),
      intimacyPreflight: has('NSFW 末端静默校验'),
      systemMessageCount: system.length.clamp(0, 1000).toInt(),
      systemCharacterBucket: characterBucket(characters),
    );
  }

  static String characterBucket(int characters) {
    if (characters < 4000) return 'under_4k';
    if (characters < 8000) return '4_8k';
    if (characters < 16000) return '8_16k';
    if (characters < 32000) return '16_32k';
    return '32k_plus';
  }

  Map<String, bool> get layers => <String, bool>{
        'identity': identity,
        'ruleBundle': ruleBundle,
        'behaviorWorldBook': behaviorWorldBook,
        'personalitySpectrum': personalitySpectrum,
        'humorWorldBook': humorWorldBook,
        'conversationPlan': conversationPlan,
        'selectedThought': selectedThought,
        'dynamicMoe': dynamicMoe,
        'dialogueExpressionPlan': dialogueExpressionPlan,
        'visibleInnerVoice': visibleInnerVoice,
        'finalReminder': finalReminder,
        'operationalTruth': operationalTruth,
        'personalityAnchor': personalityAnchor,
        'intimacyPreflight': intimacyPreflight,
      };

  Map<String, Object?> toRedactedJson() => <String, Object?>{
        'layers': layers,
        'systemMessageCount': systemMessageCount,
        'systemCharacterBucket': systemCharacterBucket,
        'promptBodiesIncluded': false,
      };
}

/// Stage-attribution telemetry for Phase 2A.5.
///
/// This first observation package does not remove identity, safety, privacy or
/// user-control layers. It compares the selected plan with the first generated
/// visible answer and the final persisted answer, making later controlled
/// removals evidence-led instead of adding another competing instruction.
class ConversationInitiativeAblationTelemetry {
  const ConversationInitiativeAblationTelemetry._();

  static const settingKey = 'conversation_initiative_ablation_v1';
  static const _reasons = <String>{
    'expressed_match',
    'no_expressed_bid',
    'planned_bid_not_expressed',
    'source_thought_not_expressed',
    'ask_source_mismatch',
  };
  static const _transformations = <String>{
    'none',
    'operation_retry',
    'operation_retry_salvage',
  };
  static const _attributions = <String>{
    'matched',
    'raw_generation_or_prompt',
    'post_generation_changed_to_mismatch',
    'post_generation_recovered',
  };

  static Future<void> record(
    AppDatabase db, {
    required ConversationInitiativePlan plan,
    required ConversationExpressionVerification rawVerification,
    required ConversationExpressionVerification finalVerification,
    required PromptResponsibilityShape promptShape,
    required String transformation,
    DateTime? now,
  }) async {
    try {
      final state = _sanitize(_decode(await db.getSetting(settingKey)));
      final rawReason = _safeReason(rawVerification.reason);
      final finalReason = _safeReason(finalVerification.reason);
      final safeTransformation = _transformations.contains(transformation)
          ? transformation
          : 'none';
      final stage = attribution(rawReason, finalReason);
      final planCounts = Map<String, int>.from(
        state['planCounts']! as Map<String, int>,
      );
      final rawCounts = Map<String, int>.from(
        state['rawReasonCounts']! as Map<String, int>,
      );
      final finalCounts = Map<String, int>.from(
        state['finalReasonCounts']! as Map<String, int>,
      );
      final transformationCounts = Map<String, int>.from(
        state['transformationCounts']! as Map<String, int>,
      );
      final attributionCounts = Map<String, int>.from(
        state['attributionCounts']! as Map<String, int>,
      );
      planCounts[plan.primary.key] = (planCounts[plan.primary.key] ?? 0) + 1;
      rawCounts[rawReason] = (rawCounts[rawReason] ?? 0) + 1;
      finalCounts[finalReason] = (finalCounts[finalReason] ?? 0) + 1;
      transformationCounts[safeTransformation] =
          (transformationCounts[safeTransformation] ?? 0) + 1;
      attributionCounts[stage] = (attributionCounts[stage] ?? 0) + 1;

      final layerCorrelations = _sanitizeLayerCorrelations(
        state['layerCorrelations'],
      );
      final finalMismatch = _isMismatch(finalReason);
      for (final entry in promptShape.layers.entries) {
        final counts = Map<String, int>.from(layerCorrelations[entry.key]!);
        final key = '${entry.value ? 'present' : 'absent'}_'
            '${finalMismatch ? 'mismatch' : 'match'}';
        counts[key] = (counts[key] ?? 0) + 1;
        layerCorrelations[entry.key] = counts;
      }

      final recent = <Map<String, Object?>>[
        ...(state['recent']! as List).whereType<Map>().map(
              (item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
        <String, Object?>{
          'at': (now ?? DateTime.now()).millisecondsSinceEpoch,
          'plan': plan.primary.key,
          'plannedSpeechAct': plan.speechAct.key,
          'rawReason': rawReason,
          'rawSpeechAct': rawVerification.expressedSpeechAct,
          'finalReason': finalReason,
          'finalSpeechAct': finalVerification.expressedSpeechAct,
          'transformation': safeTransformation,
          'attribution': stage,
          'verifierChanged': rawReason != finalReason ||
              rawVerification.expressedSpeechAct !=
                  finalVerification.expressedSpeechAct,
          'promptShape': promptShape.toRedactedJson(),
        },
      ];
      state
        ..['planCounts'] = planCounts
        ..['rawReasonCounts'] = rawCounts
        ..['finalReasonCounts'] = finalCounts
        ..['transformationCounts'] = transformationCounts
        ..['attributionCounts'] = attributionCounts
        ..['layerCorrelations'] = layerCorrelations
        ..['recent'] = recent.reversed.take(24).toList().reversed.toList()
        ..['turnCount'] = ((state['turnCount'] as int?) ?? 0) + 1
        ..['lastAttribution'] = stage
        ..['lastAt'] = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await db.setSetting(settingKey, jsonEncode(state));
    } catch (_) {
      // A committed answer remains valid if observation persistence fails.
    }
  }

  static String attribution(String rawReason, String finalReason) {
    final rawMismatch = _isMismatch(_safeReason(rawReason));
    final finalMismatch = _isMismatch(_safeReason(finalReason));
    if (!rawMismatch && !finalMismatch) return 'matched';
    if (rawMismatch && finalMismatch) return 'raw_generation_or_prompt';
    if (!rawMismatch && finalMismatch) {
      return 'post_generation_changed_to_mismatch';
    }
    return 'post_generation_recovered';
  }

  static Future<Map<String, Object?>> snapshot(AppDatabase db) async {
    try {
      return _sanitize(_decode(await db.getSetting(settingKey)));
    } catch (_) {
      return _empty();
    }
  }

  static bool _isMismatch(String reason) =>
      reason != 'expressed_match' && reason != 'no_expressed_bid';

  static String _safeReason(String value) =>
      _reasons.contains(value) ? value : 'no_expressed_bid';

  static Map<String, Object?> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _empty();
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return _empty();
    }
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> raw) {
    Map<String, int> safeCounts(Object? value, Iterable<String> keys) => {
          for (final key in keys)
            key: value is Map
                ? ((value[key] as num?)?.toInt() ?? 0)
                    .clamp(0, 1000000000)
                    .toInt()
                : 0,
        };
    final planKeys = ConversationInitiativeMode.values.map((item) => item.key);
    final recent = <Map<String, Object?>>[];
    final rawRecent = raw['recent'];
    if (rawRecent is List) {
      for (final item in rawRecent.whereType<Map>()) {
        final rawReason = _safeReason(item['rawReason']?.toString() ?? '');
        final finalReason =
            _safeReason(item['finalReason']?.toString() ?? '');
        final transformation = item['transformation']?.toString() ?? '';
        final stage = attribution(rawReason, finalReason);
        final shape = item['promptShape'];
        recent.add(<String, Object?>{
          'at': ((item['at'] as num?)?.toInt() ?? 0)
              .clamp(0, 4102444800000)
              .toInt(),
          'plan': planKeys.contains(item['plan'])
              ? item['plan'].toString()
              : 'stay_with_user_topic',
          'plannedSpeechAct': _safeSpeechAct(
            item['plannedSpeechAct']?.toString() ?? '',
          ),
          'rawReason': rawReason,
          'rawSpeechAct':
              _safeSpeechAct(item['rawSpeechAct']?.toString() ?? ''),
          'finalReason': finalReason,
          'finalSpeechAct':
              _safeSpeechAct(item['finalSpeechAct']?.toString() ?? ''),
          'transformation':
              _transformations.contains(transformation) ? transformation : 'none',
          'attribution': stage,
          'verifierChanged': item['verifierChanged'] == true,
          'promptShape': _sanitizePromptShape(shape),
        });
      }
    }
    final lastAttribution = raw['lastAttribution']?.toString() ?? '';
    return <String, Object?>{
      'turnCount': ((raw['turnCount'] as num?)?.toInt() ?? 0)
          .clamp(0, 1000000000)
          .toInt(),
      'planCounts': safeCounts(raw['planCounts'], planKeys),
      'rawReasonCounts': safeCounts(raw['rawReasonCounts'], _reasons),
      'finalReasonCounts': safeCounts(raw['finalReasonCounts'], _reasons),
      'transformationCounts':
          safeCounts(raw['transformationCounts'], _transformations),
      'attributionCounts':
          safeCounts(raw['attributionCounts'], _attributions),
      'layerCorrelations': _sanitizeLayerCorrelations(
        raw['layerCorrelations'],
      ),
      'recent': recent.reversed.take(24).toList().reversed.toList(),
      'lastAttribution': _attributions.contains(lastAttribution)
          ? lastAttribution
          : 'matched',
      'lastAt': ((raw['lastAt'] as num?)?.toInt() ?? 0)
          .clamp(0, 4102444800000)
          .toInt(),
      'promptBodiesIncluded': false,
      'messageBodiesIncluded': false,
      'thoughtBodiesIncluded': false,
      'modelJsonIncluded': false,
      'safetyOrIdentityLayersRemoved': false,
    };
  }

  static Map<String, Map<String, int>> _sanitizeLayerCorrelations(
    Object? raw,
  ) {
    const keys = <String>{
      'present_match',
      'present_mismatch',
      'absent_match',
      'absent_mismatch',
    };
    return <String, Map<String, int>>{
      for (final layer in PromptResponsibilityShape.layerKeys)
        layer: <String, int>{
          for (final key in keys)
            key: raw is Map && raw[layer] is Map
                ? ((((raw[layer] as Map)[key] as num?)?.toInt() ?? 0)
                    .clamp(0, 1000000000)
                    .toInt())
                : 0,
        },
    };
  }

  static Map<String, Object?> _sanitizePromptShape(Object? raw) {
    final map = raw is Map ? raw : const {};
    final layerRaw = map['layers'];
    return <String, Object?>{
      'layers': <String, bool>{
        for (final layer in PromptResponsibilityShape.layerKeys)
          layer: layerRaw is Map && layerRaw[layer] == true,
      },
      'systemMessageCount': ((map['systemMessageCount'] as num?)?.toInt() ?? 0)
          .clamp(0, 1000)
          .toInt(),
      'systemCharacterBucket': const {
        'under_4k',
        '4_8k',
        '8_16k',
        '16_32k',
        '32k_plus',
      }.contains(map['systemCharacterBucket'])
          ? map['systemCharacterBucket'].toString()
          : 'under_4k',
      'promptBodiesIncluded': false,
    };
  }

  static String _safeSpeechAct(String value) {
    for (final item in ConversationSpeechAct.values) {
      if (item.key == value) return value;
    }
    return ConversationSpeechAct.react.key;
  }

  static Map<String, Object?> _empty() => _sanitize(const {});
}
