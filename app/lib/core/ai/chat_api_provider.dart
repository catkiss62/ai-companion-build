import 'model_profile.dart';

enum ChatApiProvider {
  deepSeek('deepseek', 'DeepSeek'),
  shuaiApiGemini('shuaiapi_gemini', '帅 API（Gemini）');

  const ChatApiProvider(this.storageValue, this.label);

  static const shuaiApiEndpoint =
      'https://api.shuaiapi.com/v1/chat/completions';
  static const shuaiApiModel = 'gemini-3.7-flash';

  final String storageValue;
  final String label;

  bool get isGeminiRelay => this == shuaiApiGemini;

  static ChatApiProvider fromStorage(String? value) {
    // Keep the user's provider choice across the relay migration, but do not
    // reuse the retired relay's secret for the new host.
    if (value == 'aiwangyou_gemini') return ChatApiProvider.shuaiApiGemini;
    return ChatApiProvider.values.firstWhere(
      (provider) => provider.storageValue == value,
      orElse: () => ChatApiProvider.deepSeek,
    );
  }

  static ChatApiProvider fromEndpoint(String endpoint) {
    final uri = Uri.tryParse(endpoint.trim());
    final relay = Uri.parse(shuaiApiEndpoint);
    if (uri != null &&
        uri.scheme == relay.scheme &&
        uri.host.toLowerCase() == relay.host &&
        uri.path.replaceAll(RegExp(r'/+$'), '') == relay.path) {
      return ChatApiProvider.shuaiApiGemini;
    }
    return ChatApiProvider.deepSeek;
  }

  String effectiveModel(DeepSeekModelProfile requested) =>
      isGeminiRelay ? shuaiApiModel : requested.apiName;

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
      // `extra_body` is an OpenAI SDK argument that merges its contents into
      // the outgoing JSON. This client builds JSON directly, so the Google
      // extension must be placed at the actual wire body's top level.
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
    };
  }
}
