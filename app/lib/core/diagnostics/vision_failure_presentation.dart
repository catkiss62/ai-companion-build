import 'provider_health.dart';

/// System UI copy only. These messages are never inserted as the companion's
/// reply and therefore cannot become a canned conversational fallback.
class VisionFailurePresentation {
  const VisionFailurePresentation._();

  static String message(Object error) {
    return switch (ProviderHealth.errorCategory(error)) {
      'missing_key' => '图片识别未开始：请先在“AI 与陪伴设置”填写千问视觉 API Key。',
      'authorization' =>
        '图片识别失败：千问视觉拒绝了当前凭据（401/403）。请检查 Key 是否有效、是否属于当前接口，以及账号是否已开通该模型。',
      'rate_limited' => '图片识别失败：千问视觉当前限流或额度不足，请稍后重试并检查账户额度。',
      'timeout' => '图片识别超时：图片仍保留，可稍后点“重试”。',
      'network' => '图片识别失败：当前无法连接千问视觉服务，图片仍保留。',
      'invalid_response' => '图片识别失败：服务返回了无法读取的结果，图片仍保留。',
      _ => '图片识别失败：图片仍保留，可在检查视觉配置后重试。',
    };
  }
}
