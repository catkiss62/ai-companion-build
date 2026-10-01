import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Client extends http.BaseClient {
  _Client(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  int closes = 0;
  final requests = <http.BaseRequest>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return respond(request);
  }
  @override
  void close() => closes++;
}

http.StreamedResponse _json(Object value) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(value))), 200,
    headers: {'content-type': 'application/json', 'mcp-session-id': 'session-fixture'});
Map<String, dynamic> _payload(http.BaseRequest request) =>
    jsonDecode((request as http.Request).body) as Map<String, dynamic>;
http.StreamedResponse _setup(http.BaseRequest request) {
  final payload = _payload(request);
  if (payload['method'] == 'notifications/initialized') {
    return http.StreamedResponse(const Stream.empty(), 202);
  }
  return _json({'jsonrpc': '2.0', 'id': payload['id'], 'result': {}});
}
McpHttpClient _transport(_Client client, {Duration timeout = const Duration(seconds: 2)}) =>
    McpHttpClient(endpoint: Uri.parse('https://example.invalid/mcp'),
        client: client, timeout: timeout);

void main() {
  test('SSE ignores notifications and wrong ids, joins data lines, and closes at result', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () { cancelled = true; });
    final client = _Client((request) async {
      if (_payload(request)['method'] != 'tools/list') return _setup(request);
      expect(request.headers['mcp-session-id'], 'session-fixture');
      final id = _payload(request)['id'];
      body.add(utf8.encode(': ping\r\n\r\ndata: {"jsonrpc":"2.0","method":"notifications/progress"}\n\n'
          'data: {"jsonrpc":"2.0","id":999,"result":{}}\n\n'
          'data: {"jsonrpc":"2.0","id":$id,\n'
          'data: "result":{"tools":[{"name":"valid","inputSchema":{}}]}}\n\n'));
      // Deliberately never close: a final matching result must finish the call.
      return http.StreamedResponse(body.stream, 200,
          headers: {'content-type': 'text/event-stream'});
    });
    expect((await _transport(client).listTools()).single.name, 'valid');
    expect(cancelled, isTrue);
    expect(client.closes, 0); // caller-owned client remains usable
    await body.close();
  });

  test('a response for a different request is rejected', () async {
    final client = _Client((request) async => _json({
      'jsonrpc': '2.0', 'id': 900, 'result': {'tools': []},
    }));
    await expectLater(_transport(client).listTools(), throwsA(
        isA<McpHttpException>().having((e) => e.code, 'code', 'invalid_response')));
  });

  test('oversized unbounded body stops at the byte cap and cancels', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () { cancelled = true; });
    body.add(List.filled(1024 * 1024 + 1, 65));
    final client = _Client((_) async => http.StreamedResponse(body.stream, 200));
    await expectLater(_transport(client).listTools(), throwsA(
        isA<McpHttpException>().having((e) => e.code, 'code', 'response_too_large')));
    expect(cancelled, isTrue);
    await body.close();
  });

  test('stalled headers abort the request and cancel late bodies', () async {
    final pending = Completer<http.StreamedResponse>();
    final client = _Client((_) => pending.future);
    await expectLater(_transport(client, timeout: const Duration(milliseconds: 30)).listTools(),
        throwsA(isA<McpHttpException>().having((e) => e.code, 'code', 'network_or_timeout')));
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () { cancelled = true; });
    pending.complete(http.StreamedResponse(body.stream, 200));
    await (client.requests.single as http.AbortableRequest).abortTrigger;
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    await body.close();
  });

  test('trickled SSE does not reset the overall deadline', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () { cancelled = true; });
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      body.add(utf8.encode(': ping\n\n'));
    });
    final client = _Client((_) async => http.StreamedResponse(body.stream, 200,
        headers: {'content-type': 'text/event-stream'}));
    try {
      await expectLater(_transport(client, timeout: const Duration(milliseconds: 70)).listTools(),
          throwsA(isA<McpHttpException>().having((e) => e.code, 'code', 'network_or_timeout')));
      expect(cancelled, isTrue);
      await (client.requests.single as http.AbortableRequest).abortTrigger;
    } finally { timer.cancel(); await body.close(); }
  });

  test('user cancellation aborts a waiting body without closing shared client', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () { cancelled = true; });
    final received = Completer<void>();
    final client = _Client((_) async {
      received.complete();
      return http.StreamedResponse(body.stream, 200);
    });
    final token = GenerationCancellationToken();
    final result = expectLater(_transport(client).listTools(cancellationToken: token),
        throwsA(isA<GenerationCancelledByUserException>()));
    await received.future;
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    await result;
    expect(cancelled, isTrue);
    expect(client.closes, 0);
    await body.close();
  });

  test('HTTP errors cancel unread bodies immediately', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () { cancelled = true; });
    final client = _Client((_) async => http.StreamedResponse(body.stream, 503));
    await expectLater(_transport(client).listTools(), throwsA(
        isA<McpHttpException>().having((e) => e.code, 'code', 'http_503')));
    expect(cancelled, isTrue);
    await body.close();
  });

  test('internally owned clients close after every request, preserving session', () async {
    final clients = <_Client>[];
    final transport = McpHttpClient(endpoint: Uri.parse('https://example.invalid/mcp'),
        clientFactory: () {
          final client = _Client((request) async {
            if (_payload(request)['method'] != 'tools/list') return _setup(request);
            expect(request.headers['mcp-session-id'], 'session-fixture');
            return _json({'jsonrpc':'2.0', 'id':_payload(request)['id'], 'result':{'tools':[]}});
          });
          clients.add(client);
          return client;
        });
    expect(await transport.listTools(), isEmpty);
    expect(await transport.listTools(), isEmpty);
    expect(clients, hasLength(4));
    expect(clients.every((client) => client.closes == 1), isTrue);
  });
}
