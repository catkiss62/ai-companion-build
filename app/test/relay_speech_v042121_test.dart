import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/relay_text_tail_guard.dart';
import 'package:ai_companion_localfirst/core/ai/speech_performance_plan.dart';
import 'package:ai_companion_localfirst/core/tts/spoken_text_index.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:http/http.dart' as http;

class _OpenClient extends http.BaseClient {
  final source = StreamController<List<int>>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => http.StreamedResponse(source.stream, 200);
  @override
  void close() { closed = true; }
  void add(String line) => source.add(utf8.encode('$line\n\n'));
}

String event({String? content, String? finish, Object? tools, int count = 1}) =>
  'data: ${jsonEncode({'choices': List.generate(count, (i) => {
    'index': i, 'delta': {if (content != null) 'content': content,
      if (tools != null) 'tool_calls': tools}, 'finish_reason': finish})})}';

void main() {
  const grace = Duration(milliseconds: 15);
  for (final kind in ['relay-final', 'deepseek', 'relay-internal']) {
    test('real client enables bounded completion only for $kind', () async {
      final transport = _OpenClient();
      final usage = <DeepSeekUsageEvent>[];
      final client = DeepSeekClient(streamClientFactory: () => transport,
        onUsage: (event) async { usage.add(event); });
      final result = client.streamChat(apiKey: 'test', model: DeepSeekModelProfile.flash,
        effort: ReasoningEffort.low, messages: const [{'role': 'user', 'content': '测试'}],
        requestProvider: kind == 'deepseek' ? ChatApiProvider.deepSeek : ChatApiProvider.aiWangYouGemini,
        usageLane: kind == 'relay-internal' ? 'agent_tool_planning' : 'final_reply',
        relayTailGrace: grace).toList();
      transport.add(event(content: '完整正文', finish: 'stop'));
      transport.add('data: {"choices":[],"usage":{"prompt_tokens":21,"completion_tokens":3}}');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (kind != 'relay-final') {
        expect(transport.closed, isFalse); transport.add('data: [DONE]');
      }
      final deltas = await result.timeout(const Duration(seconds: 1));
      expect(deltas.map((d) => d.content).join(), '完整正文');
      expect(usage.single.inputTokens, 21);
      expect(deltas.last.streamEndReason, kind == 'relay-final' ? 'relay_tail_deadline' : 'done');
      await transport.source.close(); client.close();
    });
  }
  test('terminal same-frame text survives and trailing usage precedes bounded close', () async {
    final source = StreamController<String>();
    var deadlines = 0;
    final result = RelayTextTailGuard(grace: grace).bind(source.stream,
      onDeadline: () => deadlines++).toList();
    final text = event(content: '完整回复', finish: 'stop');
    source.add(text);
    source.add('data: {"choices":[],"usage":{"prompt_tokens":12}}');
    final lines = await result.timeout(const Duration(seconds: 1));
    expect(lines.first, text);
    expect(lines[1], contains('usage'));
    expect(lines.last, 'data: [DONE]');
    expect(deadlines, 1);
    await source.close();
  });
  for (final mode in ['no-stop', 'length', 'tools', 'multi', 'machine']) {
    test('$mode is never promoted to a completed text stream', () async {
      final source = StreamController<String>();
      var deadlines = 0;
      final result = RelayTextTailGuard(grace: grace).bind(source.stream,
        onDeadline: () => deadlines++).toList();
      if (mode == 'tools') source.add(event(tools: [{'index': 0}]));
      source.add(event(content: mode == 'machine' ? '{"tool_calls":[]}' : '正文',
        count: mode == 'multi' ? 2 : 1,
        finish: mode == 'no-stop' ? null : mode == 'length' ? 'length' : 'stop'));
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(deadlines, 0);
      await source.close();
      expect(await result, isNot(contains('data: [DONE]')));
    });
  }
  test('unexpected body after stop disables shortcut without losing content', () async {
    final source = StreamController<String>();
    var deadlines = 0;
    final result = RelayTextTailGuard(grace: grace).bind(source.stream,
      onDeadline: () => deadlines++).toList();
    source.add(event(content: '前半', finish: 'stop'));
    source.add(event(content: '后半'));
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(deadlines, 0);
    source.add('data: [DONE]'); await source.close();
    final lines = await result;
    expect(lines[1], contains('后半'));
    expect(lines.where((s) => s == 'data: [DONE]'), hasLength(1));
  });
  test('keepalives and repeated stop cannot extend terminal deadline', () async {
    final source = StreamController<String>();
    var deadlines = 0;
    final result = RelayTextTailGuard(grace: grace).bind(source.stream,
      onDeadline: () => deadlines++).toList();
    source.add(event(content: '正文', finish: 'stop'));
    final keepalive = Timer.periodic(const Duration(milliseconds: 2), (_) {
      source.add(': ping'); source.add(event(finish: 'stop'));
    });
    await result.timeout(const Duration(seconds: 1));
    keepalive.cancel(); expect(deadlines, 1); await source.close();
  });
  test('consumer cancellation cancels pending deadline', () async {
    final source = StreamController<String>();
    var deadlines = 0;
    final sub = RelayTextTailGuard(grace: grace).bind(source.stream,
      onDeadline: () => deadlines++).listen((_) {});
    source.add(event(content: '正文', finish: 'stop'));
    await Future<void>.delayed(Duration.zero); await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(deadlines, 0); await source.close();
  });
  test('normal DONE or EOF does not purchase the grace window', () async {
    for (final ending in [<String>['data: [DONE]'], <String>[]]) {
      var deadlines = 0;
      final lines = await RelayTextTailGuard(grace: grace).bind(Stream.fromIterable([
        event(content: '正文', finish: 'stop'), ...ending]), onDeadline: () => deadlines++).toList();
      expect(deadlines, 0); expect(lines.length, 1 + ending.length);
    }
  });

  test('short turning sentence has two candidate meanings, no return questions', () {
    final spans = SpeechPerformancePlan.candidates('才、才不是刻意等你的呢，不过看到你回来还是挺开心的');
    expect(spans, hasLength(2));
    expect(spans.first.start, 0);
    expect(spans.last.end, SpokenTextIndex.normalize(spans.map((s) => s.text).join()).length);
    expect(SpeechPerformancePlan.deliveries, contains('hold'));
  });
  test('long speech covers its final words with a bounded semantic budget', () {
    for (final text in [List.filled(40, '这是长回复里的一段完整说明。').join(), List.filled(500, '长').join()]) {
      final spans = SpeechPerformancePlan.candidates(text);
      expect(spans.length, inInclusiveRange(2, 8));
      expect(spans.last.end, SpokenTextIndex.normalize(text).length);
      for (var i = 1; i < spans.length; i++) expect(spans[i].start, spans[i-1].end);
    }
  });
  test('optional missing decisions skip one cue, never manufacture a neutral emotion', () {
    final spans = SpeechPerformancePlan.candidates('前半句，后半句');
    final decoded = SpeechPerformancePlan.decode(spans, {
      'speech0_delivery': 'hold', 'speech0_emotion': 'keep',
      'speech1_delivery': 'unknown', 'speech1_emotion': 'sad',
    }, {'sad'});
    expect(decoded, hasLength(1)); expect(decoded.single['emotion'], '');
    expect(decoded.single['delivery'], 'hold');
  });
  test('speech movement stays within calibrated channels and returns locally', () {
    final frames = SpeechPerformancePlan.frames('avert', {'ParamAngleY2': {'min': -3, 'max': 3}});
    expect(frames.first['parameters'], {'ParamAngleY2': -3.0});
    expect(frames.last['parameters'], isEmpty);
    expect(SpeechPerformancePlan.frames('hold', {}), isEmpty);
    expect(jsonEncode(frames), isNot(contains('ParamMouthOpenY')));
    expect(SpokenTextIndex.fingerprint('你好，ABC。'), SpokenTextIndex.fingerprint('你好abc'));
  });
}
