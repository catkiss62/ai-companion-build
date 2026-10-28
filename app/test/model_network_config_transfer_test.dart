import 'dart:convert';

import 'package:ai_companion_localfirst/features/settings/model_network_config_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> validPayload() => {
    'schema': 'ai_companion_model_network_settings',
    'version': 1,
    'secure': {
      for (final key in ModelNetworkConfigTransfer.secureKeys) key: '',
      'chat_provider': 'deepseek',
      'work_connection': '{"mode":"follow"}',
      'deepseek_endpoint': 'https://example.test/v1/chat/completions',
      'final_endpoint': 'https://example.test/final',
      'vision_endpoint': 'https://example.test/vision',
      'agnes_endpoint': 'https://example.test/agnes',
      'jev_enabled': '1',
    },
    'settings': {
      for (final key in ModelNetworkConfigTransfer.settingKeys) key: '',
      'weather_enabled': '0',
    },
  };

  test('page export shape preserves API credentials and only page-owned keys', () {
    final payload = validPayload();
    (payload['secure'] as Map<String, String>)['jev_api_key'] = 'secret';
    final decoded = ModelNetworkConfigTransfer.parse(jsonEncode(payload));
    expect(decoded.secure['jev_api_key'], 'secret');
    expect(decoded.settings.keys, containsAll(ModelNetworkConfigTransfer.settingKeys));
    expect(decoded.secure, isNot(contains('cedar_toy_token')));
    expect(decoded.settings['creative_work_model'], 'deepseek-flash');
    expect(decoded.settings['creative_work_effort'], 'max');
  });

  test('legacy model files retain the maximum work default', () {
    final payload = validPayload();
    (payload['secure'] as Map).remove('work_connection');
    (payload['secure'] as Map).remove('third_connection');
    (payload['settings'] as Map).remove('app_qwen_vision_enabled_v1');
    (payload['settings'] as Map).remove('deepseek_reasoning_effort');
    (payload['settings'] as Map).remove('creative_work_model');
    (payload['settings'] as Map).remove('creative_work_effort');
    final decoded = ModelNetworkConfigTransfer.parse(jsonEncode(payload));
    expect(decoded.settings['creative_work_model'], 'deepseek-flash');
    expect(decoded.settings['creative_work_effort'], 'max');
    expect(jsonDecode(decoded.secure['work_connection']!), {'mode': 'follow'});
    expect(jsonDecode(decoded.secure['third_connection']!)['enabled'], false);
    expect(decoded.settings['app_qwen_vision_enabled_v1'], '1');
  });

  test('truncated or unrelated files cannot partially overwrite configuration', () {
    final payload = validPayload();
    (payload['secure'] as Map<String, String>).remove('jev_api_key');
    expect(() => ModelNetworkConfigTransfer.parse(jsonEncode(payload)),
        throwsFormatException);
    expect(() => ModelNetworkConfigTransfer.parse('{"schema":"backup"}'),
        throwsFormatException);
  });
}
