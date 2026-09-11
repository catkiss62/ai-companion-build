import 'model_profile.dart';

enum ChatApiProvider {
  deepSeek('deepseek', 'DeepSeek'),
  aiWangYouGemini('aiwangyou_gemini', '玩游中转（Gemini）');

  const ChatApiProvider(this.storageValue, this.label);

  static const aiWangYouEndpoint =
      'https://wy.aiwangyou.cc/v1/chat/completions';
  static const aiWangYouModel = '[特价]gemini-3.7-flash-0.5';

  final String storageValue;
  final String label;

  bool get isGeminiRelay => this == aiWangYouGemini;

  static ChatApiProvider fromStorage(String? value) {
    return ChatApiProvider.values.firstWhere(
      (provider) => provider.storageValue == value,
      orElse: () => ChatApiProvider.deepSeek,
    );
  }

  static ChatApiProvider fromEndpoint(String endpoint) {
    final uri = Uri.tryParse(endpoint.trim());
    final relay = Uri.parse(aiWangYouEndpoint);
    if (uri != null &&
        uri.scheme == relay.scheme &&
        uri.host.toLowerCase() == relay.host &&
        uri.path.replaceAll(RegExp(r'/+$'), '') == relay.path) {
      return ChatApiProvider.aiWangYouGemini;
    }
    return ChatApiProvider.deepSeek;
  }

  String effectiveModel(DeepSeekModelProfile requested) =>
      isGeminiRelay ? aiWangYouModel : requested.apiName;

  ReasoningEffort normalizeEffort(ReasoningEffort effort) {
    if (isGeminiRelay) {
      return effort == ReasoningEffort.max ? ReasoningEffort.high : effort;
    }
    return effort == ReasoningEffort.medium ? ReasoningEffort.high : effort;
  }

  List<ReasoningEffort> get reasoningEfforts => isGeminiRelay
      ? const <ReasoningEffort>[
          ReasoningEffort.low,
          ReasoningEffort.medium,
          ReasoningEffort.high,
        ]
      : const <ReasoningEffort>[
          ReasoningEffort.low,
          ReasoningEffort.high,
          ReasoningEffort.max,
        ];

  Map<String, Object?> thinkingRequestFields({
    required bool thinking,
    required ReasoningEffort effort,
  }) {
    final normalized = normalizeEffort(effort);
    if (!isGeminiRelay) {
      return <String, Object?>{
        'thinking': <String, String>{
          'type': thinking ? 'enabled' : 'disabled',
        },
        if (thinking) 'reasoning_effort': normalized.apiName,
      };
    }
    return <String, Object?>{
      'extra_body': <String, Object?>{
        'google': <String, Object?>{
          'thinking_config': <String, Object?>{
            // Gemini 3 cannot fully disable thinking. Background JSON and
            // classifier calls use low effort without exposing summaries;
            // visible chat requests use the selected level and stream the
            // provider's official thought summary as reasoning_content.
            'thinking_level': thinking ? normalized.apiName : 'low',
            'include_thoughts': thinking,
          },
        },
      },
    };
  }
}
