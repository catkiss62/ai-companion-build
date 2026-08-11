enum DeepSeekModelProfile {
  pro('deepseek-v4-pro', 'V4 Pro'),
  flash('deepseek-v4-flash', 'V4 Flash');

  const DeepSeekModelProfile(this.apiName, this.label);
  final String apiName;
  final String label;

  static DeepSeekModelProfile fromApiName(String? value) {
    return DeepSeekModelProfile.values.firstWhere(
      (e) => e.apiName == value,
      orElse: () => DeepSeekModelProfile.pro,
    );
  }
}

enum ReasoningEffort {
  high('high', 'High'),
  max('max', 'Max');

  const ReasoningEffort(this.apiName, this.label);
  final String apiName;
  final String label;

  static ReasoningEffort fromApiName(String? value) {
    return ReasoningEffort.values.firstWhere(
      (e) => e.apiName == value,
      orElse: () => ReasoningEffort.high,
    );
  }
}
