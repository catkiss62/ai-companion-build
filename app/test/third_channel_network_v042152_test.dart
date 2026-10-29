import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_config.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_event.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/diagnostics/third_channel_diagnostics.dart';

class _RealHttp extends HttpOverrides {}

const _config = ThirdChannelConfig(enabled: true, baseUrl: 'https://fixture.invalid/v1', apiKey: 'synthetic');
String _sse() => 'data: ${jsonEncode({'model': 'gemini-3.8-flash-tiered',
  'choices': [{'delta': {'content': '完整成功'}, 'finish_reason': 'stop'}],
  'usage': {'prompt_tokens': 10, 'completion_tokens': 2,
    'completion_tokens_details': {'reasoning_tokens': 3}}})}\n\ndata: [DONE]\n\n';
http.Response _ok() => http.Response(_sse(), 200);
Matcher _code(String value) => isA<ThirdChannelFailure>().having((e) => e.code, 'code', value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  const bridge = MethodChannel('ai_companion/system');
  setUp(() { HttpOverrides.global = _RealHttp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(bridge, (call) async => call.method == 'runtimeProcessEpoch' ? 'fixture152' : null);
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(bridge, null));

  test('15-second health limit remains inside the unchanged 120-second request budget', () {
    final client = ThirdChannelClient();
    expect(client.healthTimeout, const Duration(seconds: 15));
    expect(client.totalTimeout, const Duration(seconds: 120)); client.close();
  });
  for (final url in ['https://fixture.invalid/v1', 'https://fixture.invalid/v1/chat/completions']) {
    test('public gateway base or full endpoint has one model path and a root health path: $url', () {
      final config = ThirdChannelConfig(baseUrl: url);
      expect(config.endpoint.path, '/v1/chat/completions'); expect(config.health.path, '/health');
    });
  }
  test('real HTTP 2.8-second health response succeeds and immediately proceeds to one model request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var posts = 0;
    server.listen((request) async {
      try {
        if (request.uri.path == '/health') {
          expect(request.headers.value('authorization'), isNull);
          await Future<void>.delayed(const Duration(milliseconds: 2800));
          request.response.write('{"status":"ok"}');
        } else {
          expect(request.uri.path, '/v1/chat/completions'); posts++;
          request.response.headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8');
          request.response.write(_sse());
        }
      } finally { await request.response.close(); }
    });
    final client = ThirdChannelClient(); final events = <ThirdChannelEvent>[];
    try {
      final result = await client.complete(config: ThirdChannelConfig(baseUrl: 'http://127.0.0.1:${server.port}/v1', apiKey: 'synthetic'),
        messages: [], onDiagnostic: events.add);
      expect(result.content, '完整成功'); expect(posts, 1);
      expect(events.single.healthElapsedMs, greaterThanOrEqualTo(2600));
      expect(events.single.outcome, 'success'); expect(events.single.healthHttpStatus, 200);
      expect(events.single.attempts, 1);
    } finally { client.close(); await server.close(force: true); }
  });

  for (final scenario in ['health_timeout', 'total_timeout', 'cancel', 'source_changed']) {
    test('$scenario during health never sends a model request or waits for the delayed response', () async {
      final entered = Completer<void>(), release = Completer<http.Response>();
      final token = GenerationCancellationToken(); var current = true, posts = 0;
      final events = <ThirdChannelEvent>[];
      final client = ThirdChannelClient(
        healthTimeout: scenario == 'health_timeout' ? const Duration(milliseconds: 60) : const Duration(seconds: 15),
        totalTimeout: scenario == 'total_timeout' ? const Duration(milliseconds: 60) : const Duration(seconds: 120),
        clientFactory: () => MockClient((request) async {
          if (request.url.path == '/health') { if (!entered.isCompleted) entered.complete(); return release.future; }
          posts++; return _ok();
        }));
      final operation = client.complete(config: _config, messages: [], cancellation: token,
        current: () async => current, onDiagnostic: events.add);
      final expected = scenario == 'cancel' ? isA<GenerationCancelledByUserException>()
        : scenario == 'source_changed' ? isA<GenerationSuspendedByRuntimeGateException>()
        : _code(scenario == 'health_timeout' ? 'health_timeout' : 'timeout');
      final observed = expectLater(operation, throwsA(expected));
      try {
        await entered.future;
        if (scenario == 'cancel') token.cancel();
        if (scenario == 'source_changed') current = false;
        await observed.timeout(const Duration(seconds: 3));
        expect(posts, 0); expect(events, hasLength(1)); expect(events.single.stage, 'health');
        expect(events.single.outcome, scenario == 'cancel' ? 'cancelled' : scenario == 'source_changed' ? 'suspended' : 'failed');
        release.complete(http.Response('{"status":"ok"}', 200));
        await Future<void>.delayed(Duration.zero); expect(posts, 0);
      } finally {
        client.close(); if (!release.isCompleted) release.complete(http.Response('{}', 200)); await observed;
      }
    });
  }
  final failures = <String, Object>{
    'health_dns': const SocketException('Failed host lookup: PRIVATE-HOST.invalid'),
    'health_tls': const HandshakeException('PRIVATE-TLS-DETAIL'),
    'health_connection': const SocketException('Connection refused PRIVATE-HOST'),
  };
  for (final entry in failures.entries) {
    test('${entry.key} preserves a safe category without raw transport details', () async {
      final events = <ThirdChannelEvent>[];
      final client = ThirdChannelClient(clientFactory: () => MockClient((_) async => throw entry.value));
      try {
        await expectLater(client.complete(config: _config, messages: [], onDiagnostic: events.add), throwsA(_code(entry.key)));
        final raw = jsonEncode(events.single.toJson()); expect(raw, isNot(contains('PRIVATE')));
        expect(events.single.code, entry.key); expect(events.single.attempts, 0);
      } finally { client.close(); }
    });
  }
  for (final body in ['<html>PRIVATE-RESPONSE</html>', '[]', '{"status":"starting"}']) {
    test('malformed or unhealthy health body is distinguished from a timeout: $body', () async {
      final events = <ThirdChannelEvent>[]; var posts = 0;
      final client = ThirdChannelClient(clientFactory: () => MockClient((request) async {
        if (request.url.path == '/health') return http.Response(body, 200); posts++; return _ok();
      }));
      try {
        await expectLater(client.complete(config: _config, messages: [], onDiagnostic: events.add), throwsA(_code('health_response')));
        expect(posts, 0); expect(events.single.healthHttpStatus, 200);
        expect(jsonEncode(events.single.toJson()), isNot(contains('PRIVATE')));
      } finally { client.close(); }
    });
  }
  for (final health in [true, false]) {
    test('HTTP 503 is attributed to ${health ? 'health' : 'model'} and does not add paid retries', () async {
      final events = <ThirdChannelEvent>[]; var posts = 0;
      final client = ThirdChannelClient(clientFactory: () => MockClient((request) async {
        if (request.url.path == '/health') return http.Response(health ? 'PRIVATE-ERROR' : '{"status":"ok"}', health ? 503 : 200);
        posts++; return http.Response('PRIVATE-ERROR', 503);
      }));
      try {
        await expectLater(client.complete(config: _config, messages: [], onDiagnostic: events.add), throwsA(_code(health ? 'health_http_503' : 'http_503')));
        expect(posts, health ? 0 : 1); expect(events.single.stage, health ? 'health' : 'model');
        expect(jsonEncode(events.single.toJson()), isNot(contains('PRIVATE')));
      } finally { client.close(); }
    });
  }
  test('a broken diagnostic observer cannot discard a valid completed reply', () async {
    final client = ThirdChannelClient(clientFactory: () => MockClient((request) async =>
      request.url.path == '/health' ? http.Response('{"status":"ok"}', 200) : _ok()));
    try {
      final result = await client.complete(config: _config, messages: [], onDiagnostic: (_) => throw StateError('diagnostic only'));
      expect(result.content, '完整成功');
    } finally { client.close(); }
  });

  ThirdChannelEvent event(int at) => ThirdChannelEvent(at: at, stage: 'health', outcome: 'failed',
    code: 'health_timeout', elapsedMs: 15000, healthElapsedMs: 15000, attempts: 0,
    healthHttpStatus: 0, modelHttpStatus: 0, healthTimeoutMs: 15000, transport: 'timeout');
  test('diagnostic storage retains only bounded whitelisted facts including after import-style malformed data', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      await db.setSetting(ThirdChannelDiagnostics.settingKey, jsonEncode([{
        'at': 1, 'code': 'PRIVATE-ERROR', 'lane': 'PRIVATE-ACCOUNT', 'url': 'https://PRIVATE.invalid', 'body': 'PRIVATE-TEXT'}]));
      final sink = (await ThirdChannelDiagnostics.capture(db, lane: 'connection_test'))!;
      for (var i = 1; i <= 45; i++) { sink.record(event(i + 1)); } await sink.flush();
      final report = await ThirdChannelDiagnostics.read(db);
      final rows = report['events'] as List; expect(rows, hasLength(40));
      expect((rows.first as Map)['at'], 7); expect((rows.last as Map)['at'], 46);
      final clean = ThirdChannelDiagnostics.decode(jsonEncode([{'code': 'PRIVATE-ERROR', 'url': 'PRIVATE-URL', 'body': 'PRIVATE-TEXT'}]));
      expect(jsonEncode(clean), isNot(contains('PRIVATE')));
      expect(jsonEncode(report), isNot(contains('PRIVATE')));
    } finally { await db.closeForTesting(); }
  });
  test('a late diagnostic sink captured before restore cannot append to the restored brain', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      final sink = (await ThirdChannelDiagnostics.capture(db, lane: 'final_reply'))!;
      await db.setSetting('runtime_state_epoch_v1', 'restored-152'); sink.record(event(1)); await sink.flush();
      expect(await db.getSetting(ThirdChannelDiagnostics.settingKey), isNull);
    } finally { await db.closeForTesting(); }
  });
}
