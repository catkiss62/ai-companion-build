import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_config.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_event.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_transport.dart';
import 'package:ai_companion_localfirst/core/diagnostics/third_channel_diagnostics.dart';
import 'package:ai_companion_localfirst/core/diagnostics/third_channel_test_status.dart';

const config = ThirdChannelConfig(baseUrl: 'https://fixture.invalid', apiKey: 'synthetic');
http.Response reply({bool usage = true}) => http.Response(jsonEncode({
  'choices': [{'message': {'content': '完成'}, 'finish_reason': 'stop'}],
  if (usage) 'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
}), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('short test and enabled reply share endpoint auth network despite different effort', () async {
    var created = 0, health = 0;
    final efforts = <String>[], events = <ThirdChannelEvent>[];
    final pool = ThirdChannelTransportPool(clientFactory: () {
      created++;
      return MockClient((r) async {
        if (r.method == 'GET') { health++; return http.Response('{"status":"ok"}', 200); }
        efforts.add((jsonDecode(r.body) as Map)['reasoning_effort'] as String);
        return reply();
      });
    });
    final a = ThirdChannelClient(transportPool: pool), b = ThirdChannelClient(transportPool: pool);
    try {
      await a.complete(config: config, messages: [], stream: false, onDiagnostic: events.add);
      a.close();
      await b.complete(config: const ThirdChannelConfig(enabled: true,
        baseUrl: 'https://fixture.invalid/v1/', apiKey: 'synthetic', effort: 'low'),
        messages: [], stream: false, onDiagnostic: events.add);
      expect(created, 1); expect(health, 1); expect(efforts, ['high', 'low']);
      expect(events.first.healthCached, false); expect(events.last.healthCached, true);
      expect(events.last.healthElapsedMs, 0); expect(events.last.healthHttpStatus, 0);
      expect(events.last.transportReused, true);
    } finally { a.close(); b.close(); pool.close(); }
  });

  test('health cache expires at 60 seconds and a cache read never extends it', () async {
    var now = Duration.zero;
    final pool = ThirdChannelTransportPool(elapsed: () => now,
      clientFactory: () => MockClient((_) async => reply()));
    try {
      final a = await pool.acquire(config);
      expect(a.recentHealth, false); a.markHealthy(); a.release();
      now = const Duration(seconds: 59);
      final b = await pool.acquire(config); expect(b.recentHealth, true); b.release();
      now = const Duration(seconds: 60);
      final c = await pool.acquire(config); expect(c.recentHealth, false); c.release();
      now = const Duration(seconds: -1);
      final d = await pool.acquire(config); expect(d.recentHealth, false); d.release();
    } finally { pool.close(); }
  });

  for (final change in ['key', 'endpoint', 'network', 'unknown-network']) {
    test('$change retires reachability and a late old lease cannot repopulate it', () async {
      var network = 'wifi', unknown = false;
      final pool = ThirdChannelTransportPool(networkIdentity: () async {
        if (unknown) throw StateError('unavailable'); return network;
      }, clientFactory: () => MockClient((_) async => reply()));
      try {
        final a = await pool.acquire(config); a.markHealthy();
        var next = config;
        if (change == 'key') next = const ThirdChannelConfig(baseUrl: 'https://fixture.invalid', apiKey: 'changed');
        if (change == 'endpoint') next = const ThirdChannelConfig(baseUrl: 'https://other.invalid', apiKey: 'synthetic');
        if (change == 'network') network = 'mobile';
        if (change == 'unknown-network') unknown = true;
        final b = await pool.acquire(next);
        expect(b.reused, false); expect(b.recentHealth, false);
        a.markHealthy(); expect(a.recentHealth, false); a.release();
        expect(b.recentHealth, false); b.release();
      } finally { pool.close(); }
    });
  }

  test('HTTP 200 without usage still fails and invalidates cached health before the next reply', () async {
    var health = 0, posts = 0;
    final events = <ThirdChannelEvent>[];
    final pool = ThirdChannelTransportPool(clientFactory: () => MockClient((r) async {
      if (r.method == 'GET') { health++; return http.Response('{"status":"ok"}', 200); }
      return reply(usage: ++posts != 2);
    }));
    final client = ThirdChannelClient(transportPool: pool);
    Future<ThirdChannelResponse> send() => client.complete(config: config,
      messages: [], stream: false, onDiagnostic: events.add);
    try {
      await send();
      await expectLater(send(), throwsA(isA<ThirdChannelFailure>().having((e) => e.code, 'code', 'usage_missing')));
      await send();
      expect(health, 2); expect(posts, 3); expect(events[1].healthCached, true);
      expect(events[2].healthCached, false); expect(events[2].transportReused, false);
    } finally { client.close(); pool.close(); }
  });

  test('cache expiry runs health again while the total deadline remains 120 seconds', () async {
    var now = Duration.zero, health = 0;
    final pool = ThirdChannelTransportPool(elapsed: () => now, clientFactory: () => MockClient((r) async {
      if (r.method == 'GET') { health++; return http.Response('{"status":"ok"}', 200); }
      return reply();
    }));
    final client = ThirdChannelClient(transportPool: pool);
    try {
      expect(client.totalTimeout, const Duration(seconds: 120));
      await client.complete(config: config, messages: [], stream: false);
      now = const Duration(seconds: 60);
      await client.complete(config: config, messages: [], stream: false);
      expect(health, 2);
    } finally { client.close(); pool.close(); }
  });

  test('test status distinguishes unsaved inputs, disabled routing and short success without leaking secrets', () {
    const saved = ThirdChannelConfig(enabled: true, baseUrl: 'https://saved.invalid', apiKey: 'PRIVATE');
    expect(ThirdChannelTestStatus.scope(config, saved), contains('与已保存配置不同'));
    expect(ThirdChannelTestStatus.scope(config, config), contains('开关关闭'));
    expect(ThirdChannelTestStatus.scope(saved, saved), '本次使用已保存配置。');
    const event = ThirdChannelEvent(at: 0, stage: 'model', outcome: 'failed', code: 'usage_missing',
      elapsedMs: 82000, healthElapsedMs: 0, attempts: 1, healthHttpStatus: 0, modelHttpStatus: 200,
      healthTimeoutMs: 15000, modelElapsedMs: 81000, headersElapsedMs: 80000, healthCached: true);
    final text = '${ThirdChannelTestStatus.scope(config, saved)}${ThirdChannelTestStatus.timing(event)}'
      '${ThirdChannelTestStatus.failure(event)}';
    expect(text, contains('60秒内')); expect(text, contains('82.0秒')); expect(text, contains('模型请求'));
    expect(text, isNot(contains('PRIVATE'))); expect(text, isNot(contains('saved.invalid')));
    expect(ThirdChannelDiagnostics.sanitize(event.toJson())['health_cached'], true);
    expect(ThirdChannelDiagnostics.sanitize({'health_cached': 'PRIVATE'})['health_cached'], false);
  });
}
