import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../database/app_database.dart';

/// Stores provider accounting only. Prompt text, model output, credentials and
/// tool parameters are deliberately absent from this diagnostic stream.
class ModelUsageTelemetry {
  const ModelUsageTelemetry._();

  static const settingKey = 'deepseek_usage_telemetry_v1';
  static const maxEvents = 120;

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
