import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'generation_cancellation.dart';
import 'third_channel_config.dart';

class ThirdChannelFailure implements Exception {
  const ThirdChannelFailure(this.code, {this.retryable = false});
  final String code;
  final bool retryable;
  @override String toString() => 'third_channel_$code';
}

class ThirdChannelUsage {
  const ThirdChannelUsage(this.input, this.output, this.reasoning);
  final int input, output, reasoning;
  int get total => input + output + reasoning;
  static ThirdChannelUsage parse(Object? raw) {
    if (raw is! Map) throw const ThirdChannelFailure('usage_missing');
    int count(Object? n) {
      if (n is! int || n < 0) throw const ThirdChannelFailure('usage_invalid');
      return n;
    }
    final details = raw['completion_tokens_details'];
    return ThirdChannelUsage(count(raw['prompt_tokens']), count(raw['completion_tokens']),
      count(details is Map ? details['reasoning_tokens'] ?? 0 : 0));
  }
}

class ThirdChannelResponse {
  const ThirdChannelResponse({required this.content, required this.reasoning,
    required this.finishReason, required this.toolCalls, required this.usage});
  final String content, reasoning, finishReason;
  final List<Map<String, Object?>> toolCalls;
  final ThirdChannelUsage usage;
  bool get incomplete => finishReason == 'length' || finishReason == 'content_filter';
  Map<String, Object?> completion() => {'choices': [{'message': {'role': 'assistant',
    'content': content, if (toolCalls.isNotEmpty) 'tool_calls': toolCalls},
    'finish_reason': finishReason}], 'model': ThirdChannelConfig.model,
    'usage': {'prompt_tokens': usage.input, 'completion_tokens': usage.output,
      'completion_tokens_details': {'reasoning_tokens': usage.reasoning}, 'total_tokens': usage.total}};
}

/// A complete private attempt is returned atomically. Nothing from a broken
/// stream escapes into the next attempt, UI, TTS or tool executor.
class ThirdChannelClient {
  ThirdChannelClient({http.Client Function()? clientFactory,
    this.totalTimeout = const Duration(seconds: 120),
    this.healthTimeout = const Duration(milliseconds: 1500),
    this.retryDelay = const Duration(seconds: 2), this.onUsage})
    : _factory = clientFactory ?? http.Client.new;
  final http.Client Function() _factory;
  final Duration totalTimeout, healthTimeout, retryDelay;
  final Future<void> Function(ThirdChannelUsage usage, int attempt, int elapsedMs)? onUsage;
  final Set<http.Client> _active = {};
  bool _closed = false;

  Future<ThirdChannelResponse> complete({required ThirdChannelConfig config,
    required List<Map<String, Object?>> messages, bool stream = true,
    int maxTokens = 6000,
    List<Map<String, Object?>> tools = const [], String? toolChoice,
    Map<String, Object?>? responseFormat, GenerationCancellationToken? cancellation,
    Future<bool> Function()? current}) async {
    final clock = Stopwatch()..start();
    final aborted = Completer<Never>();
    var invalid = false, expired = false, checking = false, finished = false;
    final clients = <http.Client>{};
    void abort(Object error) {
      if (finished || aborted.isCompleted) return;
      aborted.completeError(error);
      for (final client in clients.toList()) { client.close(); }
    }
    Future<void> check() async {
      cancellation?.throwIfCancelled();
      if (_closed || invalid) throw const GenerationSuspendedByRuntimeGateException();
      if (expired) throw const ThirdChannelFailure('timeout');
      if (current != null) {
        var valid = false;
        try { valid = await current(); } catch (_) { /* Failed source checks cannot authorize fallback. */ }
        if (!valid) { invalid = true; throw const GenerationSuspendedByRuntimeGateException(); }
      }
    }
    final abortFuture = aborted.future;
    final deadline = Timer(totalTimeout, () {
      expired = true; abort(const ThirdChannelFailure('timeout'));
    });
    final gate = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (checking || finished) return;
      checking = true;
      try { await check(); } catch (error) { abort(error); } finally { checking = false; }
    });
    if (cancellation != null) {
      unawaited(cancellation.whenCancelled.then((_) => abort(const GenerationCancelledByUserException())));
    }
    Future<T> bounded<T>(Future<T> operation) => Future.any<T>([operation, abortFuture]);
    http.Client open() { final client = _factory(); clients.add(client); _active.add(client); return client; }
    void release(http.Client client) { clients.remove(client); _active.remove(client); client.close(); }
    Future<ThirdChannelResponse> run() async {
      await check();
      if (!config.configured) throw const ThirdChannelFailure('not_configured');
      final probe = open();
      try {
        final health = await probe.get(config.health).timeout(healthTimeout);
        if (health.statusCode != 200 || (jsonDecode(health.body) as Map)['status'] != 'ok') {
          throw const ThirdChannelFailure('health');
        }
      } on ThirdChannelFailure { rethrow; }
      catch (_) { await check(); throw const ThirdChannelFailure('health'); }
      finally { release(probe); }
      for (var attempt = 1; attempt <= 2; attempt++) {
        await check();
        final client = open();
        var received = false;
        try {
          final request = http.Request('POST', config.endpoint)
            ..headers.addAll({'Content-Type': 'application/json', 'Accept': stream ? 'text/event-stream' : 'application/json',
              'Authorization': 'Bearer ${config.apiKey.trim()}'})
            ..body = jsonEncode({'model': ThirdChannelConfig.model, 'messages': messages,
              'stream': stream, 'max_tokens': maxTokens.clamp(1, 65536),
              'reasoning_effort': config.reasoningEffort,
              if (responseFormat != null) 'response_format': responseFormat,
              if (tools.isNotEmpty) 'tools': tools,
              if (tools.isNotEmpty) 'tool_choice': toolChoice ?? 'auto'});
          final response = await client.send(request);
          received = true;
          if (response.statusCode < 200 || response.statusCode >= 300) {
            // Do not persist response text: it can contain account identities.
            final raw = await response.stream.bytesToString();
            var code = 'http_${response.statusCode}';
            try {
              final error = (jsonDecode(raw) as Map)['error'];
              if (error is Map && (error['code'] == 'all_accounts_limited' ||
                  error['gateway_error'] is Map && error['gateway_error']['error_code'] == 'all_accounts_limited')) {
                code = 'all_accounts_limited';
              }
            } catch (_) {}
            throw ThirdChannelFailure(code);
          }
          final collector = _ThirdCollector(structured: responseFormat != null, toolsOffered: tools.isNotEmpty,
            onUsage: (usage) async {
              try { await onUsage?.call(usage, attempt, clock.elapsedMilliseconds); } catch (_) { /* Accounting cannot break a reply. */ }
            });
          if (stream) {
            final lines = <String>[];
            var done = false;
            Future<void> event() async {
              if (lines.isEmpty) return;
              final data = lines.join('\n'); lines.clear();
              if (data.trim() == '[DONE]') { done = true; return; }
              await collector.add(jsonDecode(data));
            }
            await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
              await check();
              if (line.isEmpty) { await event(); if (done) break; }
              else if (line.startsWith('data:')) {
                var value = line.substring(5); if (value.startsWith(' ')) value = value.substring(1);
                lines.add(value);
              }
            }
            // An unfinished data event at EOF is a broken stream, including
            // a half JSON frame. Only a final standalone DONE may omit LF.
            if (!done && lines.join('\n').trim() == '[DONE]') done = true;
            if (!done) throw const ThirdChannelFailure('stream_interrupted', retryable: true);
          } else {
            final raw = await response.stream.bytesToString();
            await collector.add(jsonDecode(raw), streaming: false);
          }
          final result = collector.finish();
          final format = responseFormat?['json_schema'];
          if (format is Map && format['strict'] == true && format['schema'] is Map) {
            _validateSchema(jsonDecode(result.content), format['schema'] as Map);
          }
          await check();
          return result;
        } catch (error) {
          await check();
          final failure = error is ThirdChannelFailure ? error : ThirdChannelFailure(
            received ? 'response_interrupted' : 'connection',
            retryable: error is http.ClientException || error is TimeoutException);
          if (!failure.retryable || attempt == 2) throw failure;
        } finally { release(client); }
        await Future<void>.delayed(retryDelay);
      }
      throw const ThirdChannelFailure('exhausted');
    }
    try { return await bounded(run()); }
    finally {
      finished = true; deadline.cancel(); gate.cancel();
      for (final client in clients.toList()) { release(client); }
    }
  }
  void close() { _closed = true; for (final client in _active.toList()) { client.close(); } }

  // The schema used by vision is deliberately small: validate its primitive,
  // object and array contract locally even if a gateway ignores strict mode.
  static void _validateSchema(Object? value, Map schema) {
    final valid = switch (schema['type']) {
      'object' => value is Map, 'array' => value is List,
      'string' => value is String, 'boolean' => value is bool,
      'number' => value is num && value.isFinite, 'integer' => value is int,
      'null' => value == null, _ => false,
    };
    if (!valid) throw const ThirdChannelFailure('schema_type');
    if (value is Map) {
      final properties = schema['properties'] as Map? ?? const {};
      final required = schema['required'] as List? ?? const [];
      if (required.any((key) => !value.containsKey(key)) ||
          schema['additionalProperties'] == false && value.keys.any((key) => !properties.containsKey(key))) {
        throw const ThirdChannelFailure('schema_fields');
      }
      for (final key in value.keys) {
        if (properties[key] is Map) _validateSchema(value[key], properties[key] as Map);
      }
    } else if (value is List && schema['items'] is Map) {
      for (final item in value) { _validateSchema(item, schema['items'] as Map); }
    }
  }
}

class _ThirdCollector {
  _ThirdCollector({required this.structured, required this.toolsOffered, required this.onUsage});
  final bool structured, toolsOffered;
  final Future<void> Function(ThirdChannelUsage) onUsage;
  final content = StringBuffer(), reasoning = StringBuffer();
  final calls = <int, Map<String, String>>{};
  String finishReason = '';
  ThirdChannelUsage? usage;
  Future<void> add(Object? raw, {bool streaming = true}) async {
    if (raw is! Map || raw['error'] != null) throw const ThirdChannelFailure('error_frame');
    if (raw['usage'] != null) {
      final parsed = ThirdChannelUsage.parse(raw['usage']);
      if (usage == null) { usage = parsed; await onUsage(parsed); }
    }
    final choices = raw['choices'];
    if (choices is! List) throw const ThirdChannelFailure('choices');
    for (final choice in choices.whereType<Map>()) {
      if (choice['index'] != null && choice['index'] != 0) continue;
      final delta = choice[streaming ? 'delta' : 'message'];
      if (delta is Map) {
        if (delta['content'] is String) content.write(delta['content']);
        if (delta['reasoning_content'] is String) reasoning.write(delta['reasoning_content']);
        final fragments = delta['tool_calls'];
        if (fragments is List) for (var ordinal = 0; ordinal < fragments.length; ordinal++) {
          final fragment = fragments[ordinal];
          if (fragment is! Map) throw const ThirdChannelFailure('tool_shape');
          final index = fragment['index'] is int ? fragment['index'] as int : ordinal;
          final call = calls.putIfAbsent(index, () => {'id': '', 'name': '', 'arguments': ''});
          final id = fragment['id'];
          if (id is String && id.isNotEmpty && id != call['id']) call['id'] = '${call['id']}$id';
          final function = fragment['function'];
          if (function is Map) for (final field in ['name', 'arguments']) {
            if (function[field] is String) call[field] = '${call[field]}${function[field]}';
          }
        }
      }
      final finish = choice['finish_reason'];
      if (finish != null) finishReason = finish.toString();
    }
    if (content.length + reasoning.length + calls.values.fold<int>(0, (n, c) => n + c['arguments']!.length) > 1500000) {
      throw const ThirdChannelFailure('response_too_large');
    }
  }
  ThirdChannelResponse finish() {
    if (usage == null) throw const ThirdChannelFailure('usage_missing');
    if (!const {'stop', 'tool_calls', 'length', 'content_filter'}.contains(finishReason)) {
      throw const ThirdChannelFailure('finish_missing');
    }
    if (structured && finishReason != 'stop') throw const ThirdChannelFailure('structured_incomplete');
    final tools = <Map<String, Object?>>[];
    if (finishReason == 'tool_calls') {
      if (!toolsOffered || calls.isEmpty) throw const ThirdChannelFailure('unexpected_tools');
      for (final index in calls.keys.toList()..sort()) {
        final call = calls[index]!;
        if (call['id']!.isEmpty || call['name']!.isEmpty || jsonDecode(call['arguments']!) is! Map) {
          throw const ThirdChannelFailure('tool_incomplete');
        }
        tools.add({'id': call['id'], 'type': 'function', 'function': {'name': call['name'], 'arguments': call['arguments']}});
      }
    } else if (calls.isNotEmpty) { throw const ThirdChannelFailure('tool_finish_mismatch'); }
    if (content.toString().trim().isEmpty && tools.isEmpty &&
        finishReason != 'length' && finishReason != 'content_filter') throw const ThirdChannelFailure('empty');
    if (structured && jsonDecode(content.toString()) is! Map) throw const ThirdChannelFailure('structured_shape');
    return ThirdChannelResponse(content: content.toString(), reasoning: reasoning.toString(),
      finishReason: finishReason, toolCalls: tools, usage: usage!);
  }
}
