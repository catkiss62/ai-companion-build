import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../database/app_database.dart';

/// Stores provider accounting only. Prompt text, model output, credentials and
/// tool parameters are deliberately absent from this diagnostic stream.
class ModelUsageTelemetry {
  const ModelUsageTelemetry._();

  static const settingKey = 'deepseek_usage_telemetry_v1';
  static const maxEvents = 120;

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
      'execution_id': event.executionId,
      'input_tokens': event.inputTokens,
      'output_tokens': event.outputTokens,
      'cache_hit_tokens': event.cacheHitTokens,
      'cache_miss_tokens': event.cacheMissTokens,
      'streaming': event.streaming,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    final bounded = events.length <= maxEvents
        ? events
        : events.sublist(events.length - maxEvents);
    await db.setSetting(settingKey, jsonEncode(bounded));
  }
}
