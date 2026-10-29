/// Transport facts only. Never contains URLs, headers, accounts or model text.
class ThirdChannelEvent {
  const ThirdChannelEvent({required this.at, required this.stage,
    required this.outcome, required this.code, required this.elapsedMs,
    required this.healthElapsedMs, required this.attempts,
    required this.healthHttpStatus, required this.modelHttpStatus,
    required this.healthTimeoutMs, this.transport = 'none'});
  final int at, elapsedMs, healthElapsedMs, attempts;
  final int healthHttpStatus, modelHttpStatus, healthTimeoutMs;
  final String stage, outcome, code, transport;

  static const knownCodes = {'', 'unknown', 'not_configured', 'invalid_url',
    'health_timeout', 'health_dns', 'health_tls', 'health_connection',
    'health_response', 'health_unknown', 'timeout', 'connection',
    'response_interrupted', 'all_accounts_limited', 'usage_missing',
    'usage_invalid', 'stream_interrupted', 'schema_type', 'schema_fields',
    'error_frame', 'choices', 'tool_shape', 'response_too_large',
    'finish_missing', 'structured_incomplete', 'unexpected_tools',
    'tool_incomplete', 'tool_finish_mismatch', 'empty', 'structured_shape',
    'exhausted', 'length', 'content_filter', 'user_cancelled', 'not_current'};
  static String safeCode(Object? value) {
    if (value is! String) return 'unknown';
    return knownCodes.contains(value) ||
      RegExp(r'^(health_)?http_[1-5][0-9]{2}$').hasMatch(value) ? value : 'unknown';
  }
  Map<String, Object?> toJson() => {
    'at': at, 'stage': stage, 'outcome': outcome, 'code': safeCode(code),
    'elapsed_ms': elapsedMs, 'health_elapsed_ms': healthElapsedMs,
    'attempts': attempts, 'health_http_status': healthHttpStatus,
    'model_http_status': modelHttpStatus, 'health_timeout_ms': healthTimeoutMs,
    'transport': transport,
  };
}
