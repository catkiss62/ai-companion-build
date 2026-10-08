import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/diagnostics/model_usage_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('audit separates relay, legacy, missing usage, models and endpoints', () {
    Map<String, Object?> event({String provider = 'deepseek', String model = 'm1', String endpoint = 'e1', bool available = true, int hit = 60, int miss = 40}) => {
      'provider': provider, 'lane': 'final_reply', 'model_hash': model,
      'endpoint_hash': endpoint, 'input_tokens': 100, 'cache_hit_tokens': hit,
      'cache_miss_tokens': miss, 'cache_usage_available': available, 'usage_latency_ms': 200,
    };
    final audit = ModelUsageTelemetry.cacheAudit(jsonEncode([
      event(), event(hit: 20, miss: 80), event(model: 'm2'), event(endpoint: 'e2'),
      event(provider: 'aiwangyou_gemini'), event(provider: 'unknown'),
      event(available: false), event(hit: 30, miss: 0),
    ]));
    final groups = audit['groups'] as List;
    expect(groups, hasLength(3));
    expect(groups.first['calls'], 2);
    expect(groups.first['inputTokens'], 200);
    expect(groups.first['cacheMissTokens'], 120);
    expect(groups.first['hitRatio'], .4);
    expect(groups.first['meanUsageLatencyMs'], 200);
    expect(audit['otherProviderCallsExcluded'], 1);
    expect(audit['legacyUnlabelledCalls'], 1);
    expect(audit['cacheAccountingUnavailableCalls'], 2);
  });
  test('stream audit observes full tool messages without changing transmitted messages', () async {
    final usage = <DeepSeekUsageEvent>[];
    final sent = <Map<String, dynamic>>[];
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('data: {"choices":[],"usage":{"prompt_tokens":100,"completion_tokens":2,"prompt_cache_hit_tokens":60,"prompt_cache_miss_tokens":40}}\n\ndata: [DONE]\n\n', 200);
      }), onUsage: (event) async { usage.add(event); },
    );
    addTearDown(client.close);
    for (final target in ['flower', 'weather']) {
      final messages = <Map<String, Object?>>[
        {'role': 'system', 'content': 'stable'},
        {'role': 'assistant', 'content': '', 'tool_calls': [{'id': 'call1', 'type': 'function', 'function': {'name': 'search', 'arguments': jsonEncode({'q': target})}}]},
      ];
      await client.streamChat(apiKey: 'test', model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.low, messages: messages).drain<void>();
      expect(sent.last['messages'], messages);
      expect(sent.last.containsKey('provider'), isFalse);
      expect(sent.last.containsKey('usage_latency_ms'), isFalse);
    }
    expect(usage.first.provider, 'deepseek');
    expect(usage.first.cacheUsageAvailable, isTrue);
    expect(usage.first.usageLatencyMs, greaterThanOrEqualTo(0));
    expect(usage.first.modelHash, hasLength(12));
    expect(usage.first.promptShape.messages[1].hash, usage.last.promptShape.messages[1].hash);
    expect(usage.first.promptShape.messages[1].requestHash, isNot(usage.last.promptShape.messages[1].requestHash));
    expect(usage.first.promptShape.messages.first.requestHash, usage.last.promptShape.messages.first.requestHash);
  });
  test('JSON and relay usage are labelled without inventing unavailable cache numbers', () async {
    final usage = <DeepSeekUsageEvent>[];
    final client = DeepSeekClient(client: MockClient((request) async {
      return http.Response(jsonEncode({'choices': [{'message': {'content': '{"ok":true}'}}],
        'usage': {'prompt_tokens': 100, 'completion_tokens': 2}}), 200);
    }), onUsage: (event) async { usage.add(event); });
    addTearDown(client.close);
    await client.jsonCompletion(apiKey: 'test', model: DeepSeekModelProfile.flash,
      requestProvider: ChatApiProvider.aiWangYouGemini,
      endpoint: ChatApiProvider.aiWangYouEndpoint,
      messages: const [{'role': 'user', 'content': 'private value'}]);
    expect(usage.single.provider, 'aiwangyou_gemini');
    expect(usage.single.cacheUsageAvailable, isFalse);
    expect(usage.single.usageLatencyMs, greaterThanOrEqualTo(0));
  });
}
