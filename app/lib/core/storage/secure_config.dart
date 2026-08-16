import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureConfig {
  SecureConfig._();
  static final SecureConfig instance = SecureConfig._();

  static const _apiKeyName = 'deepseek_api_key';
  static const _endpointName = 'deepseek_chat_endpoint';
  static const defaultEndpoint = 'https://api.deepseek.com/chat/completions';
  static const _visionApiKeyName = 'qwen_vision_api_key';
  static const _visionEndpointName = 'qwen_vision_endpoint';
  static const _visionModelName = 'qwen_vision_model';
  static const defaultVisionEndpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const defaultVisionModel = 'qwen3-vl-plus';

  final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(),
  );

  Future<String?> readApiKey() => _storage.read(key: _apiKeyName);

  Future<void> writeApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _apiKeyName);
    } else {
      await _storage.write(key: _apiKeyName, value: trimmed);
    }
  }

  Future<String> readEndpoint() async {
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

  Future<void> clearApiKey() => _storage.delete(key: _apiKeyName);
}
