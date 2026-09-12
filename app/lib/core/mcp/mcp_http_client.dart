import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai/generation_cancellation.dart';
import 'mcp_protocol.dart';

export 'mcp_protocol.dart';

class McpHttpException implements Exception {
  const McpHttpException(this.code, [this.detail = '']);
  final String code;
  final String detail;

  @override
  String toString() => detail.isEmpty ? code : '$code:$detail';
}

/// Small, stateful MCP Streamable-HTTP client. It deliberately transports
/// tool outcomes only; it never invokes a language model.
class McpHttpClient {
  McpHttpClient({
    required this.endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
    this.headers = const <String, String>{},
  }) : client = client ?? http.Client();

  factory McpHttpClient.fromConfig(
    McpServerConfig config, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 25),
  }) =>
      McpHttpClient(
        endpoint: config.endpoint,
        client: client,
        timeout: timeout,
        headers: config.headers,
      );

  static const protocolVersion = '2024-11-05';

  final Uri endpoint;
  final http.Client client;
  final Duration timeout;
  final Map<String, String> headers;
  String? _sessionId;
  var _nextId = 1;
  var _initialized = false;

  Future<McpToolOutcome> callTool(
    String name,
    Map<String, Object?> arguments, {
    GenerationCancellationToken? cancellationToken,
  }) async {
    await _initialize(cancellationToken);
    final result = await _request(
      'tools/call',
      <String, Object?>{'name': name, 'arguments': arguments},
      cancellationToken,
    );
    if (result is! Map) {
      throw const McpHttpException('invalid_response');
    }
    final rawContent = result['content'];
    final content = rawContent is List
        ? rawContent
            .whereType<Map>()
            .map((item) => McpContentBlock.fromJson(item))
            .toList(growable: false)
        : const <McpContentBlock>[];
    final structured = result['structuredContent'];
    return McpToolOutcome(
      content: content,
      isError: result['isError'] == true,
      structuredContent: structured,
    );
  }

  Future<List<McpToolDescriptor>> listTools({
    GenerationCancellationToken? cancellationToken,
  }) async {
    await _initialize(cancellationToken);
    final result = await _request(
      'tools/list',
      const <String, Object?>{},
      cancellationToken,
    );
    if (result is! Map || result['tools'] is! List) {
      return const <McpToolDescriptor>[];
    }
    return (result['tools'] as List)
        .whereType<Map>()
        .map((tool) => McpToolDescriptor.fromJson(tool))
        .where((tool) => tool.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _initialize(
    GenerationCancellationToken? cancellationToken,
  ) async {
    if (_initialized) return;
    await _request(
      'initialize',
      <String, Object?>{
        'protocolVersion': protocolVersion,
        'capabilities': const <String, Object?>{},
        'clientInfo': const <String, Object?>{
          'name': 'ai-companion',
          'version': '0.41.68',
        },
      },
      cancellationToken,
    );
    await _notify('notifications/initialized', const <String, Object?>{},
        cancellationToken);
    _initialized = true;
  }

  Future<Object?> _request(
    String method,
    Map<String, Object?> params,
    GenerationCancellationToken? cancellationToken,
  ) async {
    final id = _nextId++;
    final response = await _post(
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      },
      cancellationToken,
    );
    final decoded = _decode(response.body);
    if (decoded['error'] != null) {
      throw McpHttpException('remote_error', _bounded(jsonEncode(decoded['error'])));
    }
    return decoded['result'];
  }

  Future<void> _notify(
    String method,
    Map<String, Object?> params,
    GenerationCancellationToken? cancellationToken,
  ) async {
    await _post(
      <String, Object?>{
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
      },
      cancellationToken,
    );
  }

  Future<http.Response> _post(
    Map<String, Object?> payload,
    GenerationCancellationToken? cancellationToken,
  ) async {
    cancellationToken?.throwIfCancelled();
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json, text/event-stream',
      ...this.headers,
      if (_sessionId?.isNotEmpty == true) 'mcp-session-id': _sessionId!,
    };
    try {
      final pending = client
          .post(endpoint, headers: headers, body: jsonEncode(payload))
          .timeout(timeout);
      final response = cancellationToken == null
          ? await pending
          : await Future.any<http.Response>([
              pending,
              cancellationToken.whenCancelled.then<http.Response>((_) {
                client.close();
                throw const GenerationCancelledByUserException();
              }),
            ]);
      final session = response.headers['mcp-session-id']?.trim();
      if (session != null && session.isNotEmpty) _sessionId = session;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw McpHttpException('http_${response.statusCode}', _bounded(response.body));
      }
      if (utf8.encode(response.body).length > 1024 * 1024) {
        throw const McpHttpException('response_too_large');
      }
      return response;
    } on GenerationCancelledByUserException {
      rethrow;
    } on McpHttpException {
      rethrow;
    } on TimeoutException {
      throw const McpHttpException('network_or_timeout');
    } catch (error) {
      throw McpHttpException('network_or_timeout', error.runtimeType.toString());
    }
  }

  static Map<String, Object?> _decode(String body) {
    final trimmed = body.trim();
    final jsonText = (trimmed.startsWith('data:') || trimmed.contains('\ndata:'))
        ? trimmed
            .split('\n')
            .where((line) => line.startsWith('data:'))
            .map((line) => line.substring(5).trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '{}')
        : trimmed;
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) throw const McpHttpException('invalid_response');
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _bounded(String value) =>
      value.length <= 800 ? value : value.substring(0, 800);
}
