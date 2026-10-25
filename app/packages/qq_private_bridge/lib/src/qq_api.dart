import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// No credentials, response bodies or remote text in user-visible errors.
class QqApiException implements Exception {
  QqApiException(this.code, {this.uncertain = false});
  final String code;
  final bool uncertain;
  @override
  String toString() => 'QQ: $code';
}

class QqApi {
  QqApi({required this.appId, required this.secret, HttpClient? client,
    this.apiBase = 'https://api.bot.qq.com',
    this.tokenBase = 'https://bots.qq.com'}): _client = client ?? HttpClient();
  final String appId;
  final String secret;
  final String apiBase;
  final String tokenBase;
  final HttpClient _client;
  String? _token;
  DateTime _expires = DateTime(2000);
  Future<String>? _refreshing;
  bool _closed = false;

  Future<String> token() {
    if (_token != null && DateTime.now().isBefore(_expires)) return Future.value(_token!);
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh() async {
    final data = await request('POST', '$tokenBase/app/getAppAccessToken',
      body: {'appId': appId, 'clientSecret': secret});
    final value = data['access_token'];
    if (value is! String || value.isEmpty) throw QqApiException('token_missing');
    final seconds = int.tryParse('${data['expires_in']}') ?? 0;
    if (seconds < 10) throw QqApiException('token_expired');
    _token = value;
    _expires = DateTime.now().add(Duration(seconds: seconds > 120 ? seconds - 60 : seconds ~/ 2));
    return value;
  }

  void invalidateToken() { _token = null; }

  Future<Map<String, dynamic>> authenticated(String method, String path,
      {Map<String, Object?>? body, bool sending = false}) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await request(method, '$apiBase$path', body: body, accessToken: await token(), sending: sending);
      } on QqApiException catch (e) {
        // An explicit HTTP 401 rejected the operation: refresh once. Never
        // blindly retry a send whose network result is unknown.
        if (e.code != 'http_401' || attempt != 0) rethrow;
        invalidateToken();
      }
    }
  }

  Future<String> gatewayUrl() async {
    final data = await authenticated('GET', '/gateway/bot');
    final value = data['url'];
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || uri.scheme != 'wss' || uri.userInfo.isNotEmpty ||
        !(uri.host == 'qq.com' || uri.host.endsWith('.qq.com'))) throw QqApiException('gateway_invalid');
    return value as String;
  }

  Future<void> send(String owner, String messageId, String text, int sequence) async {
    if (owner.isEmpty || messageId.isEmpty || text.isEmpty) throw QqApiException('invalid_target');
    final data = await authenticated('POST', '/v2/users/${Uri.encodeComponent(owner)}/messages', sending: true,
      body: {'msg_type': 0, 'content': text, 'msg_id': messageId, 'msg_seq': sequence});
    if (data['id'] is! String || (data['id'] as String).isEmpty) {
      throw QqApiException('send_receipt_missing', uncertain: true);
    }
  }

  Future<Map<String, dynamic>> request(String method, String url,
      {Map<String, Object?>? body, String? accessToken, bool sending = false}) async {
    if (_closed) throw QqApiException('stopped');
    HttpClientRequest? outgoing;
    try {
      return await (() async {
        outgoing = await _client.openUrl(method, Uri.parse(url));
        outgoing!.headers.set(HttpHeaders.userAgentHeader, 'AICompanion-QQPrivate/0.1');
        outgoing!.headers.contentType = ContentType.json;
        if (accessToken != null) {
          outgoing!.headers.set(HttpHeaders.authorizationHeader, 'QQBot $accessToken');
          outgoing!.headers.set('X-Union-Appid', appId);
        }
        if (body != null) outgoing!.write(jsonEncode(body));
        final response = await outgoing!.close();
        final bytes = <int>[];
        await for (final part in response) {
          bytes.addAll(part);
          if (bytes.length > 256 * 1024) throw QqApiException('response_too_large', uncertain: sending);
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw QqApiException('http_${response.statusCode}', uncertain: sending && response.statusCode >= 500);
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map<String, dynamic>) throw QqApiException('response_invalid', uncertain: sending);
        if (data['code'] != null && data['code'] != 0) {
          final code = '${data['code']}';
          throw QqApiException(RegExp(r'^\d{1,12}$').hasMatch(code) ? 'api_$code' : 'api_error');
        }
        return data;
      })().timeout(const Duration(seconds: 20), onTimeout: () {
        outgoing?.abort();
        throw QqApiException('timeout', uncertain: sending);
      });
    } on QqApiException { rethrow;
    } catch (_) { throw QqApiException(_closed ? 'stopped' : 'network', uncertain: sending); }
  }

  void close() { _closed = true; _client.close(force: true); }
}
