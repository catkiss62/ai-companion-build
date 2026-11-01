import '../ai/third_channel_config.dart';
import '../ai/third_channel_event.dart';

/// Short tests prove only their own response. Never include credentials or URLs.
class ThirdChannelTestStatus {
  static String scope(ThirdChannelConfig tested, ThirdChannelConfig saved) =>
      tested.encode() != saved.encode()
          ? '本次使用输入框配置，与已保存配置不同；正文仍使用已保存配置。'
          : saved.enabled
              ? '本次使用已保存配置。'
              : '配置已保存，但第三通道开关关闭，正文不会使用。';

  static String timing(ThirdChannelEvent? event) {
    if (event == null) return '';
    String seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)}秒';
    final health = event.healthCached ? '探活沿用60秒内成功记录' : '探活${seconds(event.healthElapsedMs)}';
    return '$health，模型${seconds(event.modelElapsedMs)}，'
        '${event.headersElapsedMs > 0 ? '首响应距开始${seconds(event.headersElapsedMs)}，' : ''}'
        '${event.firstContentElapsedMs > 0 ? '首正文距开始${seconds(event.firstContentElapsedMs)}，' : ''}'
        '总计${seconds(event.elapsedMs)}。';
  }

  static String failure(ThirdChannelEvent? event) {
    final stage = switch (event?.stage) {
      'health' => '网关探活', 'model' => '模型请求', _ => '配置检查',
    };
    return '第三通道短请求测试失败：$stage（${ThirdChannelEvent.safeCode(event?.code)}）。';
  }
}
