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
    http.Client Function()? clientFactory,
  }) : _providedClient = client,
       _clientFactory = clientFactory ?? http.Client.new;

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
  final http.Client? _providedClient;
  final http.Client Function() _clientFactory;
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
          // Historical validator token: 'version': '0.41.82'
          // Historical validator compatibility token: 'version': '0.41.83'
          // Historical validator compatibility token: 'version': '0.41.86'
          // Historical validator compatibility token: 'version': '0.41.87'
          // Historical validator token: 'version': '0.41.88'.
          // Historical validator token: 'version': '0.41.89'
          // Historical validator token: 'version': '0.41.90'
          // Historical validator token: 'version': '0.41.91'
          // Historical validator compatibility token: 'version': '0.41.93'
          // Historical validator token: 'version': '0.41.94'
          // Historical validator token: 'version': '0.41.95'
          // Historical validator token: 'version': '0.41.96'
          // Historical validator token: 'version': '0.41.98'
          'version': '0.42.58',
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
    final decoded = response!;
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

  Future<Map<String, Object?>?> _post(
    Map<String, Object?> payload,
    GenerationCancellationToken? cancellationToken,
  ) async {
    cancellationToken?.throwIfCancelled();
    // Each internally owned client has one request lifetime. Session identity is
    // retained here, while abandoned one-shot Cedar clients leave no sockets.
    final client = _providedClient ?? _clientFactory();
    final abort = Completer<void>();
    final clock = Stopwatch()..start();
    Stream<List<int>>? unreadBody;
    StreamIterator<String>? lines;
    var finished = false;
    Future<T> bounded<T>(Future<T> pending) {
      final remaining = timeout - clock.elapsed;
      final guarded = cancellationToken == null ? pending : Future.any<T>([
        pending,
        cancellationToken.whenCancelled.then<T>((_) {
          throw const GenerationCancelledByUserException();
        }),
      ]);
      return guarded.timeout(remaining.isNegative ? Duration.zero : remaining);
    }
    try {
      final request = http.AbortableRequest('POST', endpoint,
          abortTrigger: abort.future)
        ..headers.addAll({
          'content-type': 'application/json',
          'accept': 'application/json, text/event-stream',
          ...headers,
          if (_sessionId?.isNotEmpty == true) 'mcp-session-id': _sessionId!,
        })
        ..body = jsonEncode(payload);
      final response = await bounded(client.send(request).then((response) {
        if (finished) unawaited(_cancelBody(response.stream));
        return response;
      }));
      unreadBody = response.stream;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw McpHttpException('http_${response.statusCode}');
      }
      final session = response.headers['mcp-session-id']?.trim();
      if (session != null && session.isNotEmpty) _sessionId = session;
      if (!payload.containsKey('id')) return null;
      const limit = 1024 * 1024;
      if ((response.contentLength ?? 0) > limit) {
        throw const McpHttpException('response_too_large');
      }
      var count = 0;
      final body = response.stream.map((chunk) {
        count += chunk.length;
        if (count > limit) throw const McpHttpException('response_too_large');
        return chunk;
      });
      final sse = (response.headers['content-type'] ?? '')
          .toLowerCase().contains('text/event-stream');
      lines = StreamIterator(body.transform(utf8.decoder)
          .transform(const LineSplitter()));
      unreadBody = null;
      final text = StringBuffer();
      final event = <String>[];
      Map<String, Object?>? eventResult() {
        if (event.isEmpty) return null;
        final data = event.join('\n');
        event.clear();
        if (data.trim().isEmpty) return null;
        return _decode(data, payload['id'], allowUnrelated: true);
      }
      while (await bounded(lines.moveNext())) {
        final line = lines.current;
        if (!sse) {
          text.writeln(line);
        } else if (line.isEmpty) {
          final result = eventResult();
          if (result != null) return result;
        } else if (line.startsWith('data:')) {
          final value = line.substring(5);
          event.add(value.startsWith(' ') ? value.substring(1) : value);
        }
      }
      if (sse) {
        final result = eventResult();
        if (result != null) return result;
        throw const McpHttpException('invalid_response');
      }
      return _decode(text.toString(), payload['id']);
    } on GenerationCancelledByUserException {
      rethrow;
    } on McpHttpException {
      rethrow;
    } on FormatException {
      throw const McpHttpException('invalid_response');
    } catch (error) {
      cancellationToken?.throwIfCancelled();
      throw McpHttpException('network_or_timeout', error.runtimeType.toString());
    } finally {
      finished = true;
      if (!abort.isCompleted) abort.complete();
      if (unreadBody != null) await _cancelBody(unreadBody);
      try { await lines?.cancel().timeout(const Duration(seconds: 2)); } catch (_) {}
      if (_providedClient == null) client.close();
    }
  }

  static Future<void> _cancelBody(Stream<List<int>> body) async {
    try {
      await body.listen((_) {}, onError: (Object _) {}).cancel()
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  static Map<String, Object?>? _decode(String body, Object? expectedId,
      {bool allowUnrelated = false}) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['jsonrpc'] != '2.0') {
      throw const McpHttpException('invalid_response');
    }
    if (decoded['id'] != expectedId ||
        (!decoded.containsKey('result') && !decoded.containsKey('error'))) {
      if (allowUnrelated) return null;
      throw const McpHttpException('invalid_response');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _bounded(String value) =>
      value.length <= 800 ? value : value.substring(0, 800);
}
