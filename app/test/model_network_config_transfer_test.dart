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
