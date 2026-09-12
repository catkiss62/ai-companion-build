import 'dart:convert';

import '../ai/generation_cancellation.dart';
import 'mcp_http_client.dart';

class CedarToyClient {
  CedarToyClient({
    required this.token,
    McpHttpClient? transport,
  }) : transport = transport ??
            McpHttpClient(endpoint: endpointForToken(token));

  static const baseUrl = 'https://toy.cedarstar.org/';
  static final RegExp _tokenPattern = RegExp(r'ctai_v1_[A-Za-z0-9_-]+');
  static final RegExp _wholeTokenPattern =
      RegExp(r'^ctai_v1_[A-Za-z0-9_-]+$');

  final String token;
  final McpHttpClient transport;

  static Uri endpointForToken(String token) {
    final clean = token.trim();
    if (!_wholeTokenPattern.hasMatch(clean)) {
      throw const FormatException('invalid_cedar_toy_token');
    }
    return Uri.parse('$baseUrl$clean');
  }

  Future<McpToolOutcome> listGames({
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'list_games',
        const <String, Object?>{},
        cancellationToken: cancellationToken,
      );

  Future<McpToolOutcome> getGuide(
    String game, {
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'get_guide',
        <String, Object?>{'game': game},
        cancellationToken: cancellationToken,
      );

  Future<McpToolOutcome> play(
    String game,
    String action,
    Map<String, Object?> params, {
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'play',
        <String, Object?>{
          'game': game,
          'action': action,
          'params': params,
        },
        cancellationToken: cancellationToken,
      );

  Future<McpToolOutcome> generateBindingToken({
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'account',
        const <String, Object?>{'action': 'generate_binding_token'},
        cancellationToken: cancellationToken,
      );

  static Future<String> loginOrRegister({
    required String username,
    required String password,
    bool loginOnly = false,
    GenerationCancellationToken? cancellationToken,
  }) async {
    final transport = McpHttpClient(endpoint: Uri.parse(baseUrl));
    final outcome = await transport.callTool(
      'account',
      <String, Object?>{
        'action': loginOnly ? 'login' : 'login_or_register',
        'username': username.trim(),
        'password': password,
      },
      cancellationToken: cancellationToken,
    );
    if (outcome.isError) throw const McpHttpException('account_failed');
    final match = _tokenPattern.firstMatch(outcome.text);
    if (match == null) throw const McpHttpException('token_missing');
    return match.group(0)!;
  }

  static String redactSecrets(String raw) {
    var result = raw.replaceAll(_tokenPattern, '[CEDAR_TOKEN]');
    result = result.replaceAllMapped(
      RegExp(
        r'(password\s*[=:]\s*)[^\s,;}&]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    try {
      final decoded = jsonDecode(result);
      result = jsonEncode(_redactJson(decoded));
    } catch (_) {}
    return result.length <= 12000 ? result : '${result.substring(0, 12000)}…';
  }

  static Object? _redactJson(Object? value) {
    if (value is List) return value.map(_redactJson).toList(growable: false);
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString();
        return MapEntry(
          name,
          RegExp(r'(password|token|secret|credential|binding)', caseSensitive: false)
                  .hasMatch(name)
              ? '[REDACTED]'
              : _redactJson(item),
        );
      });
    }
    return value;
  }
}
