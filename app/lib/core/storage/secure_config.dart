import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../ai/chat_api_provider.dart';

class SecureConfig {
  SecureConfig._()
    : _storage = const FlutterSecureStorage(aOptions: AndroidOptions());
  SecureConfig.forTesting(FlutterSecureStorage storage) : _storage = storage;
  static final SecureConfig instance = SecureConfig._();

  static const _apiKeyName = 'deepseek_api_key';
  static const _endpointName = 'deepseek_chat_endpoint';
  static const _chatProviderName = 'chat_api_provider';
  static const _aiWangYouApiKeyName = 'aiwangyou_gemini_api_key';
  static const _aiWangYouEndpointName = 'aiwangyou_final_reply_endpoint';
  static const _aiWangYouModelName = 'aiwangyou_final_reply_model';
  static const defaultEndpoint = 'https://api.deepseek.com/chat/completions';
  static const _visionApiKeyName = 'qwen_vision_api_key';
  static const _visionEndpointName = 'qwen_vision_endpoint';
  static const _visionModelName = 'qwen_vision_model';
  static const defaultVisionEndpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const defaultVisionModel = 'qwen3-vl-plus';
  static const _tavilyApiKeyName = 'tavily_api_key';
  static const _agnesApiKeyName = 'agnes_api_key';
  static const _agnesEndpointName = 'agnes_chat_endpoint';
  static const _agnesModelName = 'agnes_model';
  static const _cedarToyTokenName = 'cedar_toy_token';
  static const _openRouterApiKeyName = 'openrouter_jev_api_key';
  static const _jevEnabledName = 'openrouter_jev_short_judgments_enabled';
  static const _weatherApiKeyName = 'qweather_api_key';
  static const defaultAgnesEndpoint =
      'https://apihub.agnes-ai.com/v1/chat/completions';
  static const defaultAgnesModel = 'agnes-2.5-flash';

  final FlutterSecureStorage _storage;

  /// Explicit allowlist: never enumerate secure storage, which also owns keys,
  /// Cedar tokens and other credentials. Null preserves an unset/default value.
  static const portableKeys = <String>{
    _endpointName,
    _chatProviderName,
    _aiWangYouEndpointName,
    _aiWangYouModelName,
    _visionEndpointName,
    _visionModelName,
    _agnesEndpointName,
    _agnesModelName,
    _jevEnabledName,
  };
  Future<Map<String, String?>> readPortableSettings() async => {
    for (final key in portableKeys) key: await _storage.read(key: key),
  };

  static Map<String, String?> validatePortableSettings(Object? raw) {
    if (raw is! Map ||
        raw.length != portableKeys.length ||
        !raw.keys.toSet().containsAll(portableKeys)) {
      throw const FormatException('存档的非密钥 API 配置清单不完整');
    }
    final values = <String, String?>{};
    for (final key in portableKeys) {
      final value = raw[key];
      if (value != null && (value is! String || value.length > 8192)) {
        throw const FormatException('存档的 API 配置格式无效');
      }
      if (value is String && value.isNotEmpty) {
        if (key.endsWith('_endpoint')) {
          final uri = Uri.tryParse(value);
          if (uri == null ||
              !uri.hasAuthority ||
              !const {'http', 'https'}.contains(uri.scheme) ||
              uri.userInfo.isNotEmpty ||
              uri.queryParameters.keys.any(_credentialParameter)) {
            throw const FormatException('存档 API 地址无效或包含凭据');
          }
        }
        if (key == _chatProviderName &&
            !const {
              'deepseek',
              'aiwangyou_gemini',
              'shuaiapi_gemini',
            }.contains(value)) {
          throw const FormatException('存档的回复模型提供方无效');
        }
        if (key == _jevEnabledName && value != '0' && value != '1') {
          throw const FormatException('存档的 Jev 开关无效');
        }
      }
      values[key] = value as String?;
    }
    return values;
  }

  static bool _credentialParameter(String key) => RegExp(
    r'api.?key|token|secret|password|authorization',
    caseSensitive: false,
  ).hasMatch(key);

  Future<Map<String, String?>> exportPortableSettings() async {
    final values = await readPortableSettings();
    for (final key in portableKeys.where((key) => key.endsWith('_endpoint'))) {
      final value = values[key];
      if (value == null || value.isEmpty) continue;
      final uri = Uri.parse(value);
      if (uri.userInfo.isEmpty && !uri.hasFragment &&
          !uri.queryParameters.keys.any(_credentialParameter)) continue;
      final query = {
        for (final entry in uri.queryParametersAll.entries)
          if (!_credentialParameter(entry.key)) entry.key: entry.value,
      };
      values[key] = Uri(scheme: uri.scheme, host: uri.host,
          port: uri.hasPort ? uri.port : null, path: uri.path,
          queryParameters: query.isEmpty ? null : query).toString();
    }
    return validatePortableSettings(values);
  }

  Future<void> replacePortableSettings(
    Map<String, String?> values, {
    bool restoringLocal = false,
  }) async {
    // Local rollback may contain an endpoint with credentials. It remains local
    // and must be restored byte-for-byte, rather than exported or sanitized.
    if (!restoringLocal) validatePortableSettings(values);
    for (final key in portableKeys) {
      final value = values[key];
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    }
  }

  Future<ChatApiProvider> readChatProvider() async {
    return ChatApiProvider.fromStorage(
      await _storage.read(key: _chatProviderName),
    );
  }

  Future<void> writeChatProvider(ChatApiProvider provider) => _storage.write(
        key: _chatProviderName,
        value: provider.storageValue,
      );

  /// Internal model lane. Jev may pre-classify the two opt-in short routes;
  /// all long judgments, maintenance, Agent and fallback remain DeepSeek.
  Future<String?> readApiKey() => readDeepSeekApiKey();

  Future<String?> readDeepSeekApiKey() => _storage.read(key: _apiKeyName);

  Future<String?> readWeatherApiKey() => _storage.read(key: _weatherApiKeyName);

  Future<void> writeWeatherApiKey(String value) =>
      _writeOptionalSecret(_weatherApiKeyName, value);

  Future<String?> readAiWangYouApiKey() =>
      _storage.read(key: _aiWangYouApiKeyName);

  Future<String?> readFinalReplyApiKey() async =>
      (await readChatProvider()).isGeminiRelay
          ? readAiWangYouApiKey()
          : readDeepSeekApiKey();

  Future<void> writeApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _apiKeyName);
    } else {
      await _storage.write(key: _apiKeyName, value: trimmed);
    }
  }

  Future<void> writeAiWangYouApiKey(String value) =>
      _writeOptionalSecret(_aiWangYouApiKeyName, value);

  /// Internal model lane. See [readApiKey].
  Future<String> readEndpoint() => readDeepSeekEndpoint();

  Future<String> readFinalReplyEndpoint() async =>
      (await readChatProvider()).isGeminiRelay
          ? readAiWangYouEndpoint()
          : readDeepSeekEndpoint();

  Future<String> readFinalReplyModel() async {
    if ((await readChatProvider()).isGeminiRelay) {
      return readAiWangYouModel();
    }
    return '';
  }

  Future<String> readAiWangYouEndpoint() async {
    final value =
        (await _storage.read(key: _aiWangYouEndpointName))?.trim();
    return value == null || value.isEmpty
        ? ChatApiProvider.aiWangYouEndpoint
        : value;
  }

  Future<void> writeAiWangYouEndpoint(String value) =>
      _writeUrl(_aiWangYouEndpointName, value);

  Future<String> readAiWangYouModel() async {
    final value = (await _storage.read(key: _aiWangYouModelName))?.trim();
    return value == null || value.isEmpty
        ? ChatApiProvider.aiWangYouModel
        : value;
  }

  Future<void> writeAiWangYouModel(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _aiWangYouModelName);
    } else {
      await _storage.write(key: _aiWangYouModelName, value: trimmed);
    }
  }

  Future<String> readDeepSeekEndpoint() async {
    final value = (await _storage.read(key: _endpointName))?.trim();
    return value == null || value.isEmpty ? defaultEndpoint : value;
  }

  Future<void> writeEndpoint(String value) async {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('API 地址必须是完整的 http(s) URL');
    }
    await _storage.write(key: _endpointName, value: trimmed);
  }

  Future<String?> readVisionApiKey() =>
      _storage.read(key: _visionApiKeyName);

  Future<void> writeVisionApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _visionApiKeyName);
    } else {
      await _storage.write(key: _visionApiKeyName, value: trimmed);
    }
  }

  Future<String> readVisionEndpoint() async {
    final value = (await _storage.read(key: _visionEndpointName))?.trim();
    return value == null || value.isEmpty ? defaultVisionEndpoint : value;
  }

  Future<void> writeVisionEndpoint(String value) =>
      _writeUrl(_visionEndpointName, value);

  Future<String> readVisionModel() async {
    final value = (await _storage.read(key: _visionModelName))?.trim();
    return value == null || value.isEmpty ? defaultVisionModel : value;
  }

  Future<void> writeVisionModel(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _visionModelName);
    } else {
      await _storage.write(key: _visionModelName, value: trimmed);
    }
  }

  Future<String?> readTavilyApiKey() =>
      _storage.read(key: _tavilyApiKeyName);

  Future<void> writeTavilyApiKey(String value) =>
      _writeOptionalSecret(_tavilyApiKeyName, value);

  Future<String?> readAgnesApiKey() =>
      _storage.read(key: _agnesApiKeyName);

  Future<void> writeAgnesApiKey(String value) =>
      _writeOptionalSecret(_agnesApiKeyName, value);

  Future<String?> readCedarToyToken() =>
      _storage.read(key: _cedarToyTokenName);

  Future<void> writeCedarToyToken(String value) =>
      _writeOptionalSecret(_cedarToyTokenName, value);

  Future<void> clearCedarToyToken() =>
      _storage.delete(key: _cedarToyTokenName);

  /// Short judgment lane only; never reuse the Gemini final-reply key.
  Future<String?> readOpenRouterApiKey() =>
      _storage.read(key: _openRouterApiKeyName);

  Future<void> writeOpenRouterApiKey(String value) =>
      _writeOptionalSecret(_openRouterApiKeyName, value);

  Future<bool> readJevEnabled() async =>
      (await _storage.read(key: _jevEnabledName)) == '1';

  Future<void> writeJevEnabled(bool enabled) => _storage.write(
        key: _jevEnabledName,
        value: enabled ? '1' : '0',
      );

  Future<String> readAgnesEndpoint() async {
    final value = (await _storage.read(key: _agnesEndpointName))?.trim();
    return value == null || value.isEmpty ? defaultAgnesEndpoint : value;
  }

  Future<void> writeAgnesEndpoint(String value) =>
      _writeUrl(_agnesEndpointName, value);

  Future<String> readAgnesModel() async {
    final value = (await _storage.read(key: _agnesModelName))?.trim();
    return value == null || value.isEmpty ? defaultAgnesModel : value;
  }

  Future<void> writeAgnesModel(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _agnesModelName);
    } else {
      await _storage.write(key: _agnesModelName, value: trimmed);
    }
  }

  Future<void> _writeOptionalSecret(String key, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: trimmed);
    }
  }

  Future<void> _writeUrl(String key, String value) async {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('API 地址必须是完整的 http(s) URL');
    }
    await _storage.write(key: key, value: trimmed);
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _apiKeyName);
  }
}
