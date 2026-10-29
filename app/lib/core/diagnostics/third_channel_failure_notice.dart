import '../ai/third_channel_event.dart';

/// Local UI status only: never included in model messages, speech or memory.
class ThirdChannelFailureNotice {
  static const settingKey = 'chat_persistent_gemini_fallback_notice';
  static const dismissedAtKey = 'third_channel_notice_dismissed_at_v1';
  static const prefix = '第三通道调用失败';

  static String category(String raw) {
    final code = ThirdChannelEvent.safeCode(raw);
    final http = RegExp(r'^(health_)?http_([1-5][0-9]{2})$').firstMatch(code);
    if (http != null) {
      return '${http.group(1) == null ? '模型接口' : '健康检查'} HTTP ${http.group(2)}';
    }
    return switch (code) {
      'health_timeout' => '健康检查超时',
      'health_dns' => '域名解析失败',
      'health_tls' => '安全连接失败',
      'health_connection' || 'connection' => '无法连接网关',
      'health_response' => '健康检查返回异常',
      'timeout' => '请求超时',
      'not_configured' => '连接配置不完整',
      'invalid_url' => '地址格式错误',
      'all_accounts_limited' => '网关账号暂不可用',
      _ => '网关响应异常',
    };
  }

  static String message(String code, {String? fallback}) =>
      '$prefix（${category(code)}），${fallback == null ? '将按原规则使用后续通道' : '本轮已改用$fallback'}。'
      '可在设置中手动关闭第三通道，避免后续等待。';

  static bool shouldPersist(String notice) =>
      notice.contains(prefix) || notice.contains('本轮已由 DeepSeek 兜底');
}
