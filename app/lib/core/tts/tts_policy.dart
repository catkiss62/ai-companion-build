enum ProactiveTtsPolicy {
  silent('silent', '仅文字通知'),
  whenOverlayOpened('when_overlay_opened', '打开悬浮聊天时朗读'),
  immediate('immediate', '主动消息立即朗读');

  const ProactiveTtsPolicy(this.settingValue, this.label);

  final String settingValue;
  final String label;

  static ProactiveTtsPolicy fromSetting(String? value) {
    return ProactiveTtsPolicy.values.firstWhere(
      (e) => e.settingValue == value,
      orElse: () => ProactiveTtsPolicy.silent,
    );
  }
}
