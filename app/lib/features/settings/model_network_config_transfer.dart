import 'dart:convert';

import '../../core/ai/chat_api_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/perception/weather_context.dart';
import '../../core/storage/secure_config.dart';

/// The settings owned by the Model & Network page only. No chat, Cedar token,
/// media, memories or other device state enters this portable JSON file.
class ModelNetworkConfigTransfer {
  const ModelNetworkConfigTransfer(this.db, this.secure);

  final AppDatabase db;
  final SecureConfig secure;

  static const settingKeys = <String>[
    'model', 'deepseek_model', 'reasoning_effort',
    'public_web_discovery_enabled', 'public_web_extra_sources',
    'agnes_web_compaction_enabled', 'weather_api_host', 'weather_city',
    'weather_enabled',
  ];
  static const secureKeys = <String>[
    'chat_provider', 'deepseek_api_key', 'deepseek_endpoint',
    'final_api_key', 'final_endpoint', 'final_model',
    'vision_api_key', 'vision_endpoint', 'vision_model',
    'tavily_api_key', 'agnes_api_key', 'agnes_endpoint', 'agnes_model',
    'jev_api_key', 'jev_enabled', 'weather_api_key',
  ];

  Future<Map<String, String>> _readSecure() async => <String, String>{
    'chat_provider': (await secure.readChatProvider()).storageValue,
    'deepseek_api_key': await secure.readDeepSeekApiKey() ?? '',
    'deepseek_endpoint': await secure.readDeepSeekEndpoint(),
    'final_api_key': await secure.readAiWangYouApiKey() ?? '',
    'final_endpoint': await secure.readAiWangYouEndpoint(),
    'final_model': await secure.readAiWangYouModel(),
    'vision_api_key': await secure.readVisionApiKey() ?? '',
    'vision_endpoint': await secure.readVisionEndpoint(),
    'vision_model': await secure.readVisionModel(),
    'tavily_api_key': await secure.readTavilyApiKey() ?? '',
    'agnes_api_key': await secure.readAgnesApiKey() ?? '',
    'agnes_endpoint': await secure.readAgnesEndpoint(),
    'agnes_model': await secure.readAgnesModel(),
    'jev_api_key': await secure.readOpenRouterApiKey() ?? '',
    'jev_enabled': (await secure.readJevEnabled()) ? '1' : '0',
    'weather_api_key': await secure.readWeatherApiKey() ?? '',
  };

  Future<Map<String, String>> _readSettings() async => <String, String>{
    for (final key in settingKeys) key: await db.getSetting(key) ?? '',
  };

  Future<String> exportSaved() async {
    await db.ensureReady();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(<String, Object?>{
      'schema': 'ai_companion_model_network_settings',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'contains_api_keys': true,
      'secure': await _readSecure(),
      'settings': await _readSettings(),
    });
  }

  static Map<String, String> _validatedMap(Object? raw, List<String> keys) {
    if (raw is! Map || raw.length != keys.length ||
        raw.keys.any((key) => key is! String || !keys.contains(key))) {
      throw const FormatException('文件中的设置项目不完整或包含未知项目');
    }
    final values = <String, String>{};
    for (final key in keys) {
      final value = raw[key];
      if (value is! String || value.length > 16000) {
        throw FormatException('设置 $key 格式无效');
      }
      values[key] = value;
    }
    return values;
  }

  static ({Map<String, String> secure, Map<String, String> settings}) parse(
      String text) {
    if (text.length > 200000) {
      throw const FormatException('配置文件过大');
    }
    final data = jsonDecode(text);
    if (data is! Map ||
        data['schema'] != 'ai_companion_model_network_settings' ||
        data['version'] != 1) {
      throw const FormatException('这不是受支持的模型与联网配置文件');
    }
    final credentials = _validatedMap(data['secure'], secureKeys);
    final settings = _validatedMap(data['settings'], settingKeys);
    if (!ChatApiProvider.values.any((provider) =>
        provider.storageValue == credentials['chat_provider'])) {
      throw const FormatException('最终回复提供商无效');
    }
    for (final key in const <String>[
      'deepseek_endpoint', 'final_endpoint', 'vision_endpoint',
      'agnes_endpoint',
    ]) {
      final uri = Uri.tryParse(credentials[key]!);
      if (uri == null || !uri.hasAuthority ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw FormatException('$key 地址无效');
      }
    }
    for (final key in const <String>[
      'jev_enabled', 'public_web_discovery_enabled',
      'agnes_web_compaction_enabled', 'weather_enabled',
    ]) {
      final value = credentials[key] ?? settings[key];
      // Older installations may not have stored default-on switches yet.
      if (value != '' && value != '0' && value != '1') {
        throw FormatException('$key 开关值无效');
      }
    }
    final effort = settings['reasoning_effort']!;
    if (effort.isNotEmpty &&
        !const <String>['low', 'medium', 'high', 'max'].contains(effort)) {
      throw const FormatException('推理档位无效');
    }
    if (settings['weather_enabled'] == '1' &&
        (WeatherContext.parseApiHost(settings['weather_api_host']!) == null ||
            settings['weather_city']!.trim().isEmpty ||
            credentials['weather_api_key']!.trim().isEmpty)) {
      throw const FormatException('已开启天气，但 Host、城市或 Key 不完整');
    }
    return (secure: credentials, settings: settings);
  }

  Future<void> _writeSecure(Map<String, String> values) async {
    await secure.writeApiKey(values['deepseek_api_key']!);
    await secure.writeEndpoint(values['deepseek_endpoint']!);
    await secure.writeAiWangYouApiKey(values['final_api_key']!);
    await secure.writeAiWangYouEndpoint(values['final_endpoint']!);
    await secure.writeAiWangYouModel(values['final_model']!);
    await secure.writeVisionApiKey(values['vision_api_key']!);
    await secure.writeVisionEndpoint(values['vision_endpoint']!);
    await secure.writeVisionModel(values['vision_model']!);
    await secure.writeTavilyApiKey(values['tavily_api_key']!);
    await secure.writeAgnesApiKey(values['agnes_api_key']!);
    await secure.writeAgnesEndpoint(values['agnes_endpoint']!);
    await secure.writeAgnesModel(values['agnes_model']!);
    await secure.writeOpenRouterApiKey(values['jev_api_key']!);
    await secure.writeJevEnabled(values['jev_enabled'] == '1');
    await secure.writeWeatherApiKey(values['weather_api_key']!);
    await secure.writeChatProvider(
      ChatApiProvider.fromStorage(values['chat_provider']),
    );
  }

  Future<void> importSaved(String text) async {
    final incoming = parse(text); // Validate the whole file before any write.
    await db.ensureReady();
    final oldSecure = await _readSecure();
    final oldSettings = await _readSettings();
    try {
      await _writeSecure(incoming.secure);
      if (!await db.setSettingsAtomically(incoming.settings)) {
        throw StateError('设置事务没有提交');
      }
    } catch (error) {
      try {
        await _writeSecure(oldSecure);
        await db.setSettingsAtomically(oldSettings);
      } catch (rollbackError) {
        throw StateError('导入失败且旧设置未能完全恢复：$error；$rollbackError');
      }
      rethrow;
    }
  }
}
