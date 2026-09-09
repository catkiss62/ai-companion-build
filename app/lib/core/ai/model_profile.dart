class DeepSeekModelProfile {
  const DeepSeekModelProfile._(
    this.apiName,
    this.label, {
    this.isCustom = false,
  });

  static const pro = DeepSeekModelProfile._('deepseek-v4-pro', 'V4 Pro');
  static const flash = DeepSeekModelProfile._('deepseek-v4-flash', 'V4 Flash');
  static const custom = DeepSeekModelProfile._(
    '__custom__',
    '自定义',
    isCustom: true,
  );

  static const values = <DeepSeekModelProfile>[pro, flash, custom];

  final String apiName;
  final String label;
  final bool isCustom;

  static DeepSeekModelProfile fromApiName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || normalized == custom.apiName) return flash;
    for (final profile in const <DeepSeekModelProfile>[pro, flash]) {
      if (profile.apiName == normalized) return profile;
    }
    return DeepSeekModelProfile._(
      normalized,
      normalized,
      isCustom: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeepSeekModelProfile && other.apiName == apiName;

  @override
  int get hashCode => apiName.hashCode;
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
