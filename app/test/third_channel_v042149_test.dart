import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_route.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/ai/routed_vision_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_config.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/diagnostics/model_usage_telemetry.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_final_reply_retry.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_generator.dart';

const usage = {'prompt_tokens': 11, 'completion_tokens': 3,
  'completion_tokens_details': {'reasoning_tokens': 7}, 'total_tokens': 21};
String frame(Map<String, Object?> delta, {String? finish, bool accounting = false}) =>
  'data:${jsonEncode({'choices': [{'index': 0, 'delta': delta, 'finish_reason': finish}], if (accounting) 'usage': usage})}\n\n';
String complete(String text) => '${frame({'reasoning_content': '内部思考'})}${frame({'content': text})}${frame({}, finish: 'stop', accounting: true)}data: [DONE]\n\n';
http.Response observed(String text) => http.Response(jsonEncode({'choices': [{'message': {
  'content': jsonEncode({'summary': text})}, 'finish_reason': 'stop'}]}), 200,
  headers: {'content-type': 'application/json; charset=utf-8'});
class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late SecureConfig secure;
  final servers = <HttpServer>[];
  setUp(() { HttpOverrides.global = _RealHttp(); FlutterSecureStorage.setMockInitialValues({}); secure = SecureConfig.forTesting(const FlutterSecureStorage()); });
  tearDown(() async { for (final server in servers) { await server.close(force: true); } servers.clear(); });
  Future<ThirdChannelConfig> gateway(Future<void> Function(HttpRequest, int) post) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0); servers.add(server);
    var calls = 0;
    server.listen((request) async {
      try {
        if (request.uri.path == '/health') {
          expect(request.headers.value('authorization'), isNull);
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"status":"ok","version":"fixture"}');
        } else {
          expect(request.uri.path, '/v1/chat/completions');
          expect(request.headers.value('authorization'), 'Bearer synthetic-third');
          request.response.headers.set('content-type', 'text/event-stream; charset=utf-8');
          await post(request, ++calls);
        }
      } finally { await request.response.close(); }
    });
    return ThirdChannelConfig(enabled: true, baseUrl: 'http://127.0.0.1:${server.port}/v1', apiKey: 'synthetic-third');
  }

  test('actual HTTP SSE preserves split UTF8, comments, optional data space and separate reasoning', () async {
    final config = await gateway((request, _) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['model'], ThirdChannelConfig.model); expect(body['stream'], true);
      final bytes = utf8.encode(': ping\n\n${complete('你好，小鲸鱼')}');
      for (final byte in bytes) { request.response.add([byte]); await request.response.flush(); }
    });
    final records = <ThirdChannelUsage>[];
    final client = ThirdChannelClient(onUsage: (u, _, __) async => records.add(u));
    try {
      final result = await client.complete(config: config, messages: [{'role': 'user', 'content': 'fixture'}]);
      expect(result.content, '你好，小鲸鱼'); expect(result.reasoning, '内部思考');
      expect(records.single.output, 3); expect(records.single.reasoning, 7); expect(records.single.total, 21);
    } finally { client.close(); }
  });
  test('tool calls accumulate interleaved indices, JSON arguments and legal DONE terminal', () async {
    final config = await gateway((request, _) async {
      request.response.write(frame({'tool_calls': [
        {'index': 1, 'id': 'call-b', 'function': {'name': 'second', 'arguments': '{"b":'}},
        {'index': 0, 'id': 'call-a', 'function': {'name': 'first', 'arguments': '{"a":'}}]}));
      request.response.write(': ping\n\n');
      request.response.write(frame({'tool_calls': [
        {'index': 0, 'function': {'arguments': '1}'}}, {'index': 1, 'function': {'arguments': '2}'}}]}));
      request.response.write('${frame({}, finish: 'tool_calls', accounting: true)}data:[DONE]\n\n');
    });
    final client = ThirdChannelClient();
    try {
      final result = await client.complete(config: config, messages: [], tools: [{'type': 'function'}]);
      expect(result.content, isEmpty); expect(result.toolCalls.map((c) => c['id']), ['call-a', 'call-b']);
      expect(jsonDecode((result.toolCalls.first['function'] as Map)['arguments'] as String), {'a': 1});
    } finally { client.close(); }
  });
  test('EOF drafts never join the resent complete reply; model aliases do not affect routing', () async {
    var posts = 0;
    final config = await gateway((request, attempt) async {
      posts++;
      request.response.write(attempt == 1 ? frame({'content': '丢弃的半句'}) : complete('独立的新回答'));
    });
    final client = ThirdChannelClient(retryDelay: Duration.zero);
    try {
      final result = await client.complete(config: config, messages: []);
      expect(result.content, '独立的新回答'); expect(posts, 2);
    } finally { client.close(); }
  });
  for (final mode in ['missing_usage', 'quota', 'error_frame']) {
    test('$mode immediately fails without paid client retries', () async {
      var posts = 0;
      final config = await gateway((request, _) async {
        posts++;
        if (mode == 'quota') {
          request.response.statusCode = 503;
          request.response.write(jsonEncode({'error': {'code': 'all_accounts_limited'}}));
        } else if (mode == 'error_frame') {
          request.response.write('data:{"error":{"code":"fixture"}}\n\n');
        } else {
          request.response.write('${frame({'content': 'Please switch to another model.'}, finish: 'stop')}data:[DONE]\n\n');
        }
      });
      final client = ThirdChannelClient(retryDelay: Duration.zero);
      try { await expectLater(client.complete(config: config, messages: []), throwsA(isA<ThirdChannelFailure>())); expect(posts, 1); }
      finally { client.close(); }
    });
  }
  test('ordinary discussion of upstream warning phrases remains valid when protocol is complete', () async {
    final config = await gateway((request, _) async => request.response.write(complete('解释 switch to 和 no longer available 的含义。')));
    final client = ThirdChannelClient();
    try { expect((await client.complete(config: config, messages: [])).content, contains('switch to')); }
    finally { client.close(); }
  });
  test('connection failure and interrupted stream share one resend allowance', () async {
    var posts = 0;
    final client = ThirdChannelClient(retryDelay: Duration.zero, clientFactory: () => MockClient((request) async {
      if (request.url.path == '/health') return http.Response('{"status":"ok"}', 200);
      posts++;
      if (posts == 1) throw http.ClientException('synthetic connection failure');
      return http.Response(frame({'content': 'still incomplete'}), 200);
    }));
    try {
      await expectLater(client.complete(config: const ThirdChannelConfig(baseUrl: 'http://fixture.invalid/v1', apiKey: 'fixture'), messages: []), throwsA(isA<ThirdChannelFailure>()));
      expect(posts, 2);
    } finally { client.close(); }
  });
  test('third diagnostic accounting excludes other providers and never counts reasoning twice', () {
    final audit = ModelUsageTelemetry.thirdChannelAudit(jsonEncode([
      {'provider': 'third_channel', 'lane': 'final_reply', 'input_tokens': 11, 'output_tokens': 3, 'reasoning_tokens': 7, 'total_tokens': 21},
      {'provider': 'deepseek', 'lane': 'final_reply', 'input_tokens': 99, 'output_tokens': 40, 'reasoning_tokens': 10},
    ]));
    final lane = (audit['byLane'] as Map)['final_reply'] as Map;
    expect(lane, {'calls': 1, 'inputTokens': 11, 'visibleOutputTokens': 3, 'reasoningTokens': 7, 'totalTokens': 21});
    expect(audit['priceEstimated'], false);
  });
  test('proactive terminal filtering is not retried through the old second/first loop', () async {
    final route = FinalReplyRoute(secondChannelEnabled: true);
    var calls = 0, fallback = 0;
    final result = await ProactiveFinalReplyRetry.generate<String>(route: route, secondChannelConfigured: true,
      canContinue: () async => true, request: ({required bool secondChannel}) async {
        calls++; route.thirdChannelIncomplete = true; return '被截断的候选';
      }, validateSecondChannel: (_) => throw StateError('must not submit'),
      onFallback: (_, __) async { fallback++; });
    expect(result, isNull); expect(calls, 1); expect(fallback, 0);
  });
  for (final finish in ['length', 'content_filter']) {
    test('$finish returns an incomplete body once, structured output fails', () async {
      var posts = 0;
      final config = await gateway((request, _) async {
        posts++; request.response.write('${frame({'content': '{"summary":"片段"}'}, finish: finish, accounting: true)}data:[DONE]\n\n');
      });
      final client = ThirdChannelClient(retryDelay: Duration.zero);
      try {
        expect((await client.complete(config: config, messages: [])).incomplete, true); expect(posts, 1);
        await expectLater(client.complete(config: config, messages: [], responseFormat: {'type': 'json_schema'}), throwsA(isA<ThirdChannelFailure>()));
        expect(posts, 2);
      } finally { client.close(); }
    });
  }
  test('user cancellation aborts the current socket without another attempt', () async {
    final entered = Completer<void>(), release = Completer<void>(); var posts = 0;
    final config = await gateway((request, _) async {
      posts++; request.response.write(frame({'content': '私有草稿'})); await request.response.flush();
      entered.complete(); await release.future;
    });
    final client = ThirdChannelClient(), token = GenerationCancellationToken();
    try {
      final future = client.complete(config: config, messages: [], cancellation: token);
      final assertion = expectLater(future, throwsA(isA<GenerationCancelledByUserException>()));
      await entered.future; token.cancel(); await assertion; expect(posts, 1);
    } finally { release.complete(); client.close(); }
  });
  test('heartbeats and retry waits do not reset one total deadline', () async {
    var posts = 0;
    final client = ThirdChannelClient(totalTimeout: const Duration(milliseconds: 80),
      retryDelay: const Duration(milliseconds: 200), clientFactory: () => MockClient((request) async {
        if (request.url.path == '/health') return http.Response('{"status":"ok"}', 200);
        posts++; return http.Response(frame({'content': 'EOF'}), 200);
      }));
    try {
      await expectLater(client.complete(config: const ThirdChannelConfig(baseUrl: 'http://fixture.invalid', apiKey: 'fixture'), messages: []),
        throwsA(isA<ThirdChannelFailure>().having((e) => e.code, 'code', 'timeout')));
      expect(posts, 1);
    } finally { client.close(); }
  });

  group('shared production routes', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
      await secure.writeApiKey('synthetic-first'); await secure.writeEndpoint('http://first.invalid/chat');
      await secure.writeVisionApiKey('synthetic-qwen'); await secure.writeVisionEndpoint('http://qwen.invalid/chat');
    });
    tearDown(() async => db.closeForTesting());
    test('visible body tries third before selected first, keeps thought separate and records the third token contract', () async {
      final config = await gateway((request, _) async => request.response.write(complete('第三正文')));
      await secure.writeThirdChannel(config);
      var legacy = 0; final events = <DeepSeekUsageEvent>[];
      final client = DeepSeekClient(secureConfig: secure, onUsage: (e) async => events.add(e),
        streamClientFactory: () => MockClient((_) async { legacy++; return http.Response('', 500); }));
      try {
        final route = FinalReplyRoute(secondChannelEnabled: false);
        final deltas = await client.streamChat(apiKey: 'synthetic-first', model: DeepSeekModelProfile.flash,
          effort: ReasoningEffort.high, messages: [{'role': 'user', 'content': 'test'}], finalReplyRoute: route).toList();
        expect(deltas.single.content, '第三正文'); expect(legacy, 0); expect(route.usedThirdChannel, true);
        expect(events.single.provider, 'third_channel'); expect(events.single.reasoningTokens, 7);
      } finally { client.close(); }
    });
    test('QQ third failure preserves second retry then first fallback, with no third replay', () async {
      var thirdPosts = 0;
      final config = await gateway((request, _) async { thirdPosts++; request.response.statusCode = 429; request.response.write('{}'); });
      await secure.writeThirdChannel(config); await secure.writeAiWangYouApiKey('synthetic-second');
      await secure.writeAiWangYouEndpoint('http://second.invalid/chat');
      var second = 0, first = 0;
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        if (request.url.host == 'second.invalid') { second++; return http.Response('{}', 503); }
        first++; return http.Response.bytes(utf8.encode(complete('第一兜底')), 200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'});
      }));
      try {
        final text = await QqReplyGenerator(client: client, secure: secure, current: () async => true).generate(
          channel: 'second', firstModel: DeepSeekModelProfile.flash, firstEffort: ReasoningEffort.high,
          secondEffort: ReasoningEffort.high, messages: [{'role': 'user', 'content': 'fixture'}]);
        expect(text, '第一兜底'); expect(thirdPosts, 1); expect(second, 2); expect(first, 1);
      } finally { client.close(); }
    });
    for (final qwenEnabled in [true, false]) {
      test('App Qwen switch $qwenEnabled chooses the base chain and Qwen failure uses first', () async {
        await db.setSetting(RoutedVisionClient.qwenEnabledKey, qwenEnabled ? '1' : '0');
        final hosts = <String>[];
        final vision = RoutedVisionClient(secure: secure, db: db, firstModel: () async => DeepSeekModelProfile.flash,
          clientFactory: () => MockClient((request) async {
            hosts.add(request.url.host); final body = jsonDecode(request.body) as Map;
            if (request.url.host == 'qwen.invalid') return http.Response('{}', 401);
            expect(body['thinking'], {'type': 'disabled'}); expect(body['model'], 'deepseek-v4-flash');
            expect(request.headers['Authorization'], 'Bearer synthetic-first'); return observed('第一视觉');
          }));
        try {
          expect((await vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: 'unused', imageBytes: Uint8List.fromList([1, 2, 3]))).summary, '第一视觉');
          expect(hosts, qwenEnabled ? ['qwen.invalid', 'first.invalid'] : ['first.invalid']);
        } finally { vision.close(); }
      });
    }
    test('QQ image bypasses Qwen independently of the App switch', () async {
      final hosts = <String>[];
      final vision = RoutedVisionClient(secure: secure, db: db, qq: true, firstModel: () async => DeepSeekModelProfile.flash,
        clientFactory: () => MockClient((request) async { hosts.add(request.url.host); return observed('QQ第一视觉'); }));
      try {
        await vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: '', imageBytes: Uint8List.fromList([1]));
        expect(hosts, ['first.invalid']);
      } finally { vision.close(); }
    });
    for (final scope in ['qwen_on', 'qwen_off', 'qq']) {
      test('third image failure uses the $scope base chain without a second text-provider request', () async {
        await db.setSetting(RoutedVisionClient.qwenEnabledKey, scope == 'qwen_off' ? '0' : '1');
        await secure.writeThirdChannel(const ThirdChannelConfig(enabled: true, baseUrl: 'http://gateway.invalid/v1', apiKey: 'third'));
        var posts = 0; final hosts = <String>[];
        final vision = RoutedVisionClient(secure: secure, db: db, qq: scope == 'qq',
          firstModel: () async => DeepSeekModelProfile.flash,
          thirdFactory: () => ThirdChannelClient(clientFactory: () => MockClient((request) async {
            if (request.url.path == '/health') return http.Response('{"status":"ok"}', 200);
            posts++; return http.Response('{"error":{"code":"all_accounts_limited"}}', 503);
          })), clientFactory: () => MockClient((request) async { hosts.add(request.url.host); return observed('基础视觉'); }));
        try {
          expect((await vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: '', imageBytes: Uint8List.fromList([1]))).summary, '基础视觉');
          expect(posts, 1); expect(hosts, [scope == 'qwen_on' ? 'qwen.invalid' : 'first.invalid']);
        } finally { vision.close(); }
      });
    }
    test('a gateway ignoring strict schema cannot silently lose album or match fields', () async {
      await secure.writeThirdChannel(const ThirdChannelConfig(enabled: true, baseUrl: 'http://gateway.invalid/v1', apiKey: 'third'));
      var fallback = 0;
      final vision = RoutedVisionClient(secure: secure, db: db,
        thirdFactory: () => ThirdChannelClient(clientFactory: () => MockClient((request) async {
          if (request.url.path == '/health') return http.Response('{"status":"ok"}', 200);
          return http.Response(jsonEncode({'usage': usage, 'choices': [{'finish_reason': 'stop',
            'message': {'content': '{"summary":"incomplete schema"}'}}]}), 200);
        })), clientFactory: () => MockClient((_) async { fallback++; return observed('完整基础观察'); }));
      try {
        expect((await vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: '', imageBytes: Uint8List.fromList([1]))).summary, '完整基础观察');
        expect(fallback, 1);
      } finally { vision.close(); }
    });
    test('third vision combines the exact image with full strict schema and needs no Qwen key', () async {
      await secure.writeVisionApiKey(''); var legacy = 0;
      final config = await gateway((request, _) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['stream'], false); expect(body['max_tokens'], 4096);
        final format = body['response_format'] as Map;
        expect(format['type'], 'json_schema');
        final props = ((format['json_schema'] as Map)['schema'] as Map)['properties'] as Map;
        expect(props.keys, containsAll(['summary', 'album', 'request_match']));
        expect(jsonEncode(body['messages']), contains('data:image/png;base64,AQID'));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'model': 'gemini-3.8-flash-tiered', 'usage': usage,
          'choices': [{'finish_reason': 'stop', 'message': {'content': jsonEncode({'summary': '第三视觉',
            'album': {'save': true, 'category': 'anime', 'tags': ['anime'], 'reason': 'fixture',
              'aesthetic_tags': ['test'], 'confidence': 0.9, 'adult_content': false},
            'request_match': {'matches': true, 'confidence': 0.95, 'reason': 'fixture'}})}}]}));
      });
      await secure.writeThirdChannel(config);
      final vision = RoutedVisionClient(secure: secure, db: db,
        clientFactory: () => MockClient((_) async { legacy++; return observed('不应使用'); }));
      try {
        final observation = await vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: '',
          imageBytes: Uint8List.fromList([1, 2, 3]), assessForAlbum: true, requestedSubject: 'fixture');
        expect(observation.summary, '第三视觉'); expect(observation.albumSave, true);
        expect(observation.requestMatchConfidence, 0.95); expect(legacy, 0);
      } finally { vision.close(); }
    });
    test('lost source prevents any vision fallback request', () async {
      var valid = true, legacy = 0;
      final config = await gateway((request, _) async { valid = false; request.response.statusCode = 429; request.response.write('{}'); });
      await secure.writeThirdChannel(config);
      final vision = RoutedVisionClient(secure: secure, db: db, current: () async => valid,
        clientFactory: () => MockClient((_) async { legacy++; return observed('不应调用'); }));
      try {
        await expectLater(vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: '', imageBytes: Uint8List.fromList([1])),
          throwsA(isA<GenerationSuspendedByRuntimeGateException>())); expect(legacy, 0);
      } finally { vision.close(); }
    });
    test('completed restore with work allowed cannot authorize a fallback from the old vision request', () async {
      await secure.writeThirdChannel(const ThirdChannelConfig(enabled: true, baseUrl: 'http://gateway.invalid/v1', apiKey: 'third'));
      var legacy = 0;
      final vision = RoutedVisionClient(secure: secure, db: db,
        thirdFactory: () => ThirdChannelClient(clientFactory: () => MockClient((request) async {
          if (request.url.path == '/health') return http.Response('{"status":"ok"}', 200);
          await (await db.database).rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', ['runtime_state_epoch_v1', 'new-restored-epoch']);
          expect(await db.brainWorkAllowed(), true);
          return http.Response('{}', 503);
        })), clientFactory: () => MockClient((_) async { legacy++; return observed('不应调用'); }));
      try {
        await expectLater(vision.observeBytes(apiKey: '', endpoint: 'http://unused.invalid', model: '', imageBytes: Uint8List.fromList([1])),
          throwsA(isA<GenerationSuspendedByRuntimeGateException>())); expect(legacy, 0);
      } finally { vision.close(); }
    });
  });
}
