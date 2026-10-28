import 'dart:convert';

/// One device-local gateway profile. Upstream accounts belong to the gateway.
class ThirdChannelConfig {
  const ThirdChannelConfig({this.enabled = false, this.baseUrl = '', this.apiKey = ''});
  static const model = 'gemini-3.8-flash';
  final bool enabled;
  final String baseUrl, apiKey;
  bool get configured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
  Uri get endpoint {
    final uri = Uri.parse(baseUrl.trim());
    if (!const {'http', 'https'}.contains(uri.scheme) || !uri.hasAuthority ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException('第三通道地址需要完整的 http(s) 地址，不包含凭据或查询参数');
    }
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (!path.endsWith('/chat/completions')) {
      if (path.isEmpty) path = '/v1';
      path += '/chat/completions';
    }
    return uri.replace(path: path);
  }
  Uri get health => endpoint.replace(path: '/health');
  String encode() => jsonEncode({'enabled': enabled, 'base_url': baseUrl.trim(), 'api_key': apiKey.trim()});
  static ThirdChannelConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ThirdChannelConfig();
    final data = jsonDecode(raw) as Map;
    return ThirdChannelConfig(enabled: data['enabled'] == true,
      baseUrl: data['base_url'] as String? ?? '', apiKey: data['api_key'] as String? ?? '');
  }
}
