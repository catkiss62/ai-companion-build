/// Provider/read failures are not semantic judgements about a public page.
/// Codes are safe to persist; raw HTTP responses and exceptions never are.
abstract final class WebReadFailure {
  static bool retryable(String code) => const {
    'deepseek_failure','invalid_items','empty_items',
    'agnes_timeout','agnes_network','agnes_output_incomplete','agnes_response_format',
    'agnes_summary_format','agnes_merge_format','agnes_summary_failed',
    'tavily_extract_timeout','tavily_extract_network_or_parse',
  }.contains(code) || RegExp(r'^(?:agnes|tavily_extract)_http_(?:408|429|5\d\d)$').hasMatch(code);
  static bool failedRead(String code) => code=='deepseek_not_configured' || retryable(code) || RegExp(
    r'^(?:agnes|tavily_extract)_(?:not_configured|http_\d{3}|invalid_response|empty)$').hasMatch(code);
}
