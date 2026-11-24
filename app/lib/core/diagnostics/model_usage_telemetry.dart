import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../database/app_database.dart';

/// Stores provider accounting only. Prompt text, model output, credentials and
/// tool parameters are deliberately absent from this diagnostic stream.
class ModelUsageTelemetry {
  const ModelUsageTelemetry._();

  static const settingKey = 'deepseek_usage_telemetry_v1';
  static const maxEvents = 120;

  /// Gateway-specific visible-output and reasoning counts are disjoint.
  /// Other providers' completion conventions and prices are not applied here.
  static Map<String, Object?> thirdChannelAudit(String raw) {
    final lanes = <String, Map<String, int>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) for (final event in decoded.whereType<Map>()) {
        if (event['provider'] != 'third_channel') continue;
        final lane = event['lane']?.toString() ?? 'unclassified';
        final values = lanes.putIfAbsent(lane, () => {'calls': 0, 'inputTokens': 0,
          'visibleOutputTokens': 0, 'reasoningTokens': 0, 'totalTokens': 0});
        int count(String key) => (event[key] as num?)?.toInt() ?? 0;
        final input = count('input_tokens'), output = count('output_tokens'), reasoning = count('reasoning_tokens');
        values['calls'] = values['calls']! + 1;
        values['inputTokens'] = values['inputTokens']! + input;
        values['visibleOutputTokens'] = values['visibleOutputTokens']! + output;
        values['reasoningTokens'] = values['reasoningTokens']! + reasoning;
        values['totalTokens'] = values['totalTokens']! + input + output + reasoning;
      }
    } catch (_) { /* Best-effort diagnostics. Missing usage is never a zero-cost event. */ }
    return {'byLane': lanes, 'accounting': 'input_plus_visible_output_plus_reasoning',
      'priceEstimated': false, 'missingUsageIsZero': false};
  }

  /// DeepSeek-only samples; unlabelled/missing accounting is not zero hit rate.
  static Map<String, Object?> cacheAudit(String raw) {
    final groups = <String, Map<String, Object?>>{};
    var legacy = 0;
    var otherProvider = 0;
    var unavailable = 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final event in decoded.whereType<Map>()) {
          final provider = event['provider']?.toString() ?? 'unknown';
          if (provider == 'unknown') { legacy++; continue; }
          if (provider != 'deepseek') { otherProvider++; continue; }
          if (event['cache_usage_available'] != true) { unavailable++; continue; }
          int value(String key) => (event[key] as num?)?.toInt() ?? 0;
          final input = value('input_tokens');
          final hit = value('cache_hit_tokens');
          final miss = value('cache_miss_tokens');
          if (input <= 0 || hit < 0 || miss < 0 || hit + miss != input) {
            unavailable++; continue;
          }
          final lane = event['lane']?.toString() ?? 'unclassified';
          final model = event['model_hash']?.toString() ?? '';
          final endpoint = event['endpoint_hash']?.toString() ?? '';
          final group = groups.putIfAbsent('$lane|$model|$endpoint', () => {
            'lane': lane, 'modelHash': model, 'endpointHash': endpoint,
            'calls': 0, 'inputTokens': 0, 'cacheHitTokens': 0,
            'cacheMissTokens': 0, 'usageLatencyMsTotal': 0, 'timedCalls': 0,
          });
          void add(String key, int amount) => group[key] = (group[key] as int) + amount;
          add('calls', 1); add('inputTokens', input);
          add('cacheHitTokens', hit); add('cacheMissTokens', miss);
          final latency = (event['usage_latency_ms'] as num?)?.toInt() ?? -1;
          if (latency >= 0) { add('usageLatencyMsTotal', latency); add('timedCalls', 1); }
        }
      }
    } catch (_) { /* Best-effort body-free diagnostics. */ }
    for (final group in groups.values) {
      group['hitRatio'] = (group['cacheHitTokens'] as int) / (group['inputTokens'] as int);
      final count = group['timedCalls'] as int;
      group['meanUsageLatencyMs'] = count == 0 ? null : (group['usageLatencyMsTotal'] as int) / count;
    }
    return {
      'groups': groups.values.toList(growable: false),
      'legacyUnlabelledCalls': legacy,
      'otherProviderCallsExcluded': otherProvider,
      'cacheAccountingUnavailableCalls': unavailable,
      'latencyMeaning': 'request_start_to_usage_report_not_first_token',
    };
  }

  /// Per-job planning costs from the bounded telemetry window. Cold starts
  /// and follow-up requests stay separate; absent provider usage stays absent.
  static List<Map<String, Object?>> planningTasks(String raw) {
    final tasks = <String, List<Map>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      for (final event in decoded.whereType<Map>()) {
        final lane = event['lane'];
        if (event['provider'] != 'deepseek' ||
            (lane != 'agent_tool_planning' && lane != 'commission_research_planning')) continue;
        final id = event['execution_id'];
        if (id is! String || id.isEmpty) continue;
        tasks.putIfAbsent('$id|$lane', () => []).add(event);
      }
    } on FormatException { return []; }
    return tasks.values.toList().reversed.take(12).map((events) {
      Map<String, Object?> totals(List<Map> calls) {
        var input = 0, output = 0, reasoning = 0, hits = 0, metered = 0, covered = 0;
        for (final event in calls) {
          int n(String key) => (event[key] as num?)?.toInt() ?? 0;
          input += n('input_tokens'); output += n('output_tokens'); reasoning += n('reasoning_tokens');
          if (event['cache_usage_available'] == true && n('input_tokens') > 0 &&
              n('cache_hit_tokens') >= 0 && n('cache_miss_tokens') >= 0 &&
              n('cache_hit_tokens') + n('cache_miss_tokens') == n('input_tokens')) {
            metered++; hits += n('cache_hit_tokens'); covered += n('input_tokens');
          }
        }
        return {'callsWithUsage':calls.length, 'inputTokens':input,'outputTokens':output,
          'reasoningTokens':reasoning, 'callsWithCacheUsage':metered,
          'hitTokens':metered == 0 ? null : hits,'missTokens':metered == 0 ? null : covered-hits,
          'hitRatio':covered == 0 ? null : hits/covered};
      }
      return <String,Object?>{'executionId':events.first['execution_id'],'lane':events.first['lane'],
        'firstObserved':totals(events.take(1).toList()), 'laterObserved':totals(events.skip(1).toList()),
        'totalObserved':totals(events)};
    }).toList();
  }

  static Future<void> record(
    AppDatabase db,
    DeepSeekUsageEvent event,
  ) async {
    final raw = await db.getSetting(settingKey) ?? '';
    final events = <Object?>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) events.addAll(decoded.whereType<Map>());
    } catch (_) {}
    events.add(<String, Object?>{
      'lane': event.lane,
      'provider': event.provider,
      'model_hash': event.modelHash,
      'endpoint_hash': event.endpointHash,
      'usage_latency_ms': event.usageLatencyMs,
      'cache_usage_available': event.cacheUsageAvailable,
      'execution_id': event.executionId,
      'input_tokens': event.inputTokens,
      'output_tokens': event.outputTokens,
      'reasoning_tokens': event.reasoningTokens,
      if (event.provider == 'third_channel')
        'total_tokens': event.inputTokens + event.outputTokens + event.reasoningTokens,
      'cache_hit_tokens': event.cacheHitTokens,
      'cache_miss_tokens': event.cacheMissTokens,
      'streaming': event.streaming,
      'prompt_shape': <String, Object?>{
        'version': DeepSeekPromptShape.version,
        'messages': event.promptShape.messages
            .map((segment) => <String, Object?>{
                  'index': segment.index,
                  'role': segment.role,
                  'characters': segment.characters,
                  'hash': segment.hash,
                  'request_hash': segment.requestHash,
                })
            .toList(growable: false),
        'tools': <String, Object?>{
          'count': event.promptShape.toolCount,
          'characters': event.promptShape.toolCharacters,
          'hash': event.promptShape.toolHash,
        },
      },
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    final bounded = events.length <= maxEvents
        ? events
        : events.sublist(events.length - maxEvents);
    await db.setSetting(settingKey, jsonEncode(bounded));
  }
}
