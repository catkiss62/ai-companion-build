import 'model_profile.dart';

enum ChatApiProvider {
  deepSeek('deepseek', 'DeepSeek'),
  // Historical validator token:
  // aiWangYouGemini('aiwangyou_gemini', 'Gemini 3.7 Flash（玩游）')
  aiWangYouGemini('aiwangyou_gemini', '双模型（自定义最终回复）');

  const ChatApiProvider(this.storageValue, this.label);

  static const aiWangYouEndpoint =
      'https://wy.aiwangyou.cc/v1/chat/completions';
  static const aiWangYouModel = '[特价]gemini-3.7-flash-0.5';

  final String storageValue;
  final String label;

  bool get isGeminiRelay => this == aiWangYouGemini;

  static ChatApiProvider fromStorage(String? value) {
    // Keep the Gemini final-reply choice across the failed Shuai relay build,
    // but never copy that host's secret into the restored AiWangYou slot.
    if (value == 'shuaiapi_gemini') return ChatApiProvider.aiWangYouGemini;
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

  String effectiveModel(
    DeepSeekModelProfile requested, {
    String? configuredModel,
  }) {
    final custom = configuredModel?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    return isGeminiRelay ? aiWangYouModel : requested.apiName;
  }

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
    String modelName = '',
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
    // The prefilled AiWangYou Gemini model accepts Google's thinking
    // extension through its OpenAI-compatible endpoint. A user may instead
    // select another compatible model; do not send Gemini-only fields to it.
    if (!modelName.toLowerCase().contains('gemini')) {
      return const <String, Object?>{};
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
