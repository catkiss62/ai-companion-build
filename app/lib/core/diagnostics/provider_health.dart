import '../models/public_web_candidate.dart';

class ProviderHealthEvent {
  const ProviderHealthEvent({
    required this.lane,
    required this.context,
    required this.primaryProvider,
    required this.primaryOutcome,
    this.primaryErrorCategory = 'none',
    this.fallbackProvider = 'none',
    this.fallbackEligible = false,
    this.fallbackAttempted = false,
    this.fallbackOutcome = 'not_attempted',
    this.fallbackErrorCategory = 'none',
    this.finalProvider = 'none',
    required this.finalOutcome,
    this.resultCount = 0,
    this.latencyBucket = 'unknown',
    this.createdAt,
  });

  final String lane;
  final String context;
  final String primaryProvider;
  final String primaryOutcome;
  final String primaryErrorCategory;
  final String fallbackProvider;
  final bool fallbackEligible;
  final bool fallbackAttempted;
  final String fallbackOutcome;
  final String fallbackErrorCategory;
  final String finalProvider;
  final String finalOutcome;
  final int resultCount;
  final String latencyBucket;
  final DateTime? createdAt;
}

class ProviderHealth {
  const ProviderHealth._();

  static const lanes = <String>{'search', 'compaction', 'vision', 'album'};
  static const contexts = <String>{
    'autonomous',
    'user_turn',
    'chat_image',
    'album_discovery',
    'user_image_album',
  };
  static const providers = <String>{
    'none',
    'tavily',
    'wikimedia',
    'agnes',
    'qwen_vision',
    'local_album',
  };
  static const outcomes = <String>{
    'success',
    'failed',
    'no_result',
    'not_called',
    'not_configured',
    'not_attempted',
    'gate_blocked',
    'cancelled',
    'ownership_lost',
    'saved',
    'ai_rejected',
    'adult_rejected',
    'exact_duplicate',
    'visual_duplicate',
    'duplicate_source',
    'unsafe_source',
  };
  static const errorCategories = <String>{
    'none',
    'missing_key',
    'authorization',
    'rate_limited',
    'timeout',
    'network',
    'client_http',
    'server_http',
    'invalid_response',
    'empty_result',
    'content_filter',
    'download',
    'image_processing',
    'image_binding',
    'chat_busy',
    'ownership_changed',
    'local_write',
    'cancelled',
    'other',
  };
  static const latencyBuckets = <String>{
    'unknown',
    'under_1s',
    '1_to_5s',
    '5_to_15s',
    '15_to_45s',
    '45_to_120s',
    'over_120s',
  };

  static String safeLane(String value) =>
      lanes.contains(value) ? value : 'album';
  static String safeContext(String value) =>
      contexts.contains(value) ? value : 'autonomous';
  static String safeProvider(String value) =>
      providers.contains(value) ? value : 'none';
  static String safeOutcome(String value) =>
      outcomes.contains(value) ? value : 'failed';
  static String safeErrorCategory(String value) =>
      errorCategories.contains(value) ? value : 'other';
  static String safeLatencyBucket(String value) =>
      latencyBuckets.contains(value) ? value : 'unknown';

  static String latencyBucket(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    if (ms < 1000) return 'under_1s';
    if (ms < 5000) return '1_to_5s';
    if (ms < 15000) return '5_to_15s';
    if (ms < 45000) return '15_to_45s';
    if (ms < 120000) return '45_to_120s';
    return 'over_120s';
  }

  /// Converts a provider/local exception into a fixed category. The returned
  /// value is safe for diagnostics; the original text must never be stored in
  /// provider_health_events or exported in the report.
  static String errorCategory(Object? error) {
    final text = error?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return 'none';
    if (text.contains('api key') ||
        text.contains('api_key') ||
        text.contains('unconfigured') ||
        text.contains('未配置') ||
        text.contains('填写千问')) {
      return 'missing_key';
    }
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthorized') ||
        text.contains('forbidden')) {
      return 'authorization';
    }
    if (text.contains('429') || text.contains('rate limit')) {
      return 'rate_limited';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'timeout';
    }
    if (text.contains('cancel')) return 'cancelled';
    if (text.contains('另一处聊天窗口')) return 'chat_busy';
    if (text.contains('active brain') ||
        text.contains('设备转移') ||
        text.contains('ownership')) {
      return 'ownership_changed';
    }
    if (text.contains('adult') ||
        text.contains('nsfw') ||
        text.contains('content filter')) {
      return 'content_filter';
    }
    if (text.contains('download') || text.contains('下载')) return 'download';
    if (text.contains('album_image_binding_mismatch')) return 'image_binding';
    if (text.contains('decode') ||
        text.contains('format') ||
        text.contains('invalid_response') ||
        text.contains('parse_failure') ||
        text.contains('choices') ||
        text.contains('summary') ||
        text.contains('图片为空') ||
        text.contains('不是图片')) {
      return 'invalid_response';
    }
    final status = RegExp(r'(?:http_|http |api |status(?:code)?[=: ]+)(\d{3})')
        .firstMatch(text);
    final code = int.tryParse(status?.group(1) ?? '');
    if (code != null && code >= 500) return 'server_http';
    if (code != null && code >= 400) return 'client_http';
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('handshake')) {
      return 'network';
    }
    if (text.contains('no_result') ||
        text.contains('empty') ||
        text.contains('没有结果')) {
      return 'empty_result';
    }
    if (text.contains('file') || text.contains('path')) {
      return 'image_processing';
    }
    if (text.contains('sqlite') || text.contains('database')) {
      return 'local_write';
    }
    return 'other';
  }

  static ProviderHealthEvent webSearchEvent({
    required PublicWebProviderResult result,
    required String context,
    required Duration elapsed,
  }) {
    final primaryFailure = result.primaryFailureReason;
    final primaryOutcome = primaryFailure.isEmpty
        ? 'success'
        : errorCategory(primaryFailure) == 'empty_result'
            ? 'no_result'
            : 'failed';
    final fallbackOutcome = !result.fallbackAttempted
        ? 'not_attempted'
        : result.fallbackSucceeded
            ? 'success'
            : errorCategory(result.fallbackFailureReason) == 'empty_result'
                ? 'no_result'
                : 'failed';
    final finalOutcome = result.candidates.isNotEmpty
        ? 'success'
        : result.succeeded
            ? 'no_result'
            : 'failed';
    return ProviderHealthEvent(
      lane: 'search',
      context: context,
      primaryProvider: result.primaryProvider.isEmpty
          ? providerKey(result.provider)
          : safeProvider(result.primaryProvider),
      primaryOutcome: primaryOutcome,
      primaryErrorCategory: errorCategory(primaryFailure),
      fallbackProvider: result.fallbackProvider.isEmpty
          ? 'none'
          : safeProvider(result.fallbackProvider),
      fallbackEligible: result.fallbackEligible,
      fallbackAttempted: result.fallbackAttempted,
      fallbackOutcome: fallbackOutcome,
      fallbackErrorCategory: errorCategory(result.fallbackFailureReason),
      finalProvider: result.candidates.isEmpty
          ? 'none'
          : providerKey(result.provider),
      finalOutcome: finalOutcome,
      resultCount: result.candidates.length,
      latencyBucket: latencyBucket(elapsed),
    );
  }

  static ProviderHealthEvent webCompactionEvent({
    required PublicWebProviderResult result,
    required String context,
    required Duration elapsed,
  }) {
    final outcome = !result.compactionEnabled
        ? 'not_called'
        : !result.compactionConfigured
            ? 'not_configured'
            : !result.compactionAttempted
                ? 'not_called'
                : result.compactionSucceeded
                    ? 'success'
                    : 'failed';
    return ProviderHealthEvent(
      lane: 'compaction',
      context: context,
      primaryProvider: 'agnes',
      primaryOutcome: outcome,
      primaryErrorCategory:
          ProviderHealth.errorCategory(result.compactionFailureReason),
      finalProvider: result.compactionSucceeded ? 'agnes' : 'none',
      finalOutcome: outcome,
      resultCount: result.compactionOutputCount,
      latencyBucket: latencyBucket(elapsed),
    );
  }

  static String providerKey(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('wikimedia')) return 'wikimedia';
    if (normalized.contains('tavily')) return 'tavily';
    if (normalized.contains('agnes')) return 'agnes';
    if (normalized.contains('qwen')) return 'qwen_vision';
    return 'none';
  }
}
