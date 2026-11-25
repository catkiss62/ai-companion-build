import '../ai/deepseek_client.dart';

/// Presentation data for one execution. Never includes document bodies or prompts.
class WorkTurnDetails {
  final _clock = Stopwatch()..start();
  int? endedAt;
  void finish() {
    _clock.stop();
    endedAt ??= DateTime.now().millisecondsSinceEpoch;
  }

  String executionId = '';
  int rounds = 0;
  String? researchEnd;
  final receipts = <Map<String, Object?>>[];
  final usage = <String, Map<String, int>>{};

  void beginTool(String tool, String target) {
    receipts.add({'tool': tool, 'target': target, 'state': 'pending'});
  }

  void finishTool(Map<String, Object?> result) {
    final receipt = receipts.last;
    receipt['state'] = result.containsKey('error') ? 'failed' : 'done';
    for (final key in ['error', 'saved', 'file', 'repository', 'display', 'artifact', 'title']) {
      if (result[key] is String) receipt[key] = result[key];
    }
    if (result['matches'] case final List excerpts)
      receipt['excerpts'] = excerpts.length;
    if (result['repositories'] case final List rows) {
      receipt['matches'] = rows.length;
    }
  }

  bool addUsage(DeepSeekUsageEvent event) {
    if (executionId.isEmpty || event.executionId != executionId) return false;
    final bucket = usage.putIfAbsent(event.lane, () => {});
    void add(String key, int value) => bucket[key] = (bucket[key] ?? 0) + value;
    add('reports', 1);
    add('input', event.inputTokens);
    add('output', event.outputTokens);
    if (event.provider == 'third_channel')
      add('reasoning', event.reasoningTokens);
    if (event.cacheUsageAvailable) {
      add('hit', event.cacheHitTokens);
      add('miss', event.cacheMissTokens);
    }
    return true;
  }

  Map<String, Object?> snapshot() => {
    if (endedAt != null) 'endedAt': endedAt,
    if (endedAt != null) 'elapsedMs': _clock.elapsedMilliseconds,
    'planningRounds': rounds,
    if (researchEnd != null) 'researchEnd': researchEnd,
    'receipts': receipts,
    'usage': usage,
  };
}
