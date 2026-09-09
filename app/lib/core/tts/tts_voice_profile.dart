enum TtsVoiceMode {
  auto('auto', '自动判断'),
  daily('daily', '日常'),
  gentle('gentle', '温柔'),
  lively('lively', '活泼'),
  cute('cute', '可爱');

  const TtsVoiceMode(this.key, this.label);

  final String key;
  final String label;

  static TtsVoiceMode fromSetting(String? value) {
    for (final mode in values) {
      if (mode.key == value) return mode;
    }
    return auto;
  }
}

class TtsVoiceProfilePolicy {
  const TtsVoiceProfilePolicy._();

  static const Map<String, TtsVoiceMode> _automatic = <String, TtsVoiceMode>{
    'normal': TtsVoiceMode.daily,
    'serious': TtsVoiceMode.daily,
    'confident': TtsVoiceMode.daily,
    'angry': TtsVoiceMode.daily,
    'disgust': TtsVoiceMode.daily,
    'confused': TtsVoiceMode.daily,
    'calm': TtsVoiceMode.gentle,
    'worried': TtsVoiceMode.gentle,
    'crying': TtsVoiceMode.gentle,
    'afraid': TtsVoiceMode.gentle,
    'nervous': TtsVoiceMode.gentle,
    'shy': TtsVoiceMode.gentle,
    'embarrassed': TtsVoiceMode.gentle,
    'affection': TtsVoiceMode.gentle,
    'happy': TtsVoiceMode.lively,
    'excited': TtsVoiceMode.lively,
    'surprised': TtsVoiceMode.lively,
    'playful': TtsVoiceMode.cute,
    'helpless': TtsVoiceMode.cute,
    'flustered': TtsVoiceMode.cute,
  };

  static TtsVoiceMode resolve(
    TtsVoiceMode configured, {
    String emotionKey = '',
    double confidence = 0,
  }) {
    if (configured != TtsVoiceMode.auto) return configured;
    if (confidence < 0.35) {
      return TtsVoiceMode.daily;
    }
    return _automatic[emotionKey] ?? TtsVoiceMode.daily;
  }
}
