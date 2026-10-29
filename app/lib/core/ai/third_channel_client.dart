import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'third_channel_event.dart';
import 'package:http/http.dart' as http;
import 'generation_cancellation.dart';
import 'third_channel_config.dart';
import 'third_channel_transport.dart';

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
  ThirdChannelClient({http.Client Function()? clientFactory, ThirdChannelTransportPool? transportPool,
    this.totalTimeout = const Duration(seconds: 120),
    this.healthTimeout = const Duration(seconds: 15),
    this.retryDelay = const Duration(seconds: 2), this.onUsage})
    : _pool = transportPool ?? (clientFactory == null ? ThirdChannelTransportPool.shared
        : ThirdChannelTransportPool(clientFactory: clientFactory)),
      _ownsPool = transportPool == null && clientFactory != null;
  final ThirdChannelTransportPool _pool;
  final bool _ownsPool;
  final Duration totalTimeout, healthTimeout, retryDelay;
  final Future<void> Function(ThirdChannelUsage usage, int attempt, int elapsedMs)? onUsage;
  final Set<void Function()> _aborters = {};
  static int _sequence = 0;
  bool _closed = false;

  Future<ThirdChannelResponse> complete({required ThirdChannelConfig config,
    required List<Map<String, Object?>> messages, bool stream = true,
    int maxTokens = 6000,
    List<Map<String, Object?>> tools = const [], String? toolChoice,
    Map<String, Object?>? responseFormat, GenerationCancellationToken? cancellation,
    Future<bool> Function()? current,
    void Function(ThirdChannelEvent)? onDiagnostic}) async {
    final clock = Stopwatch()..start();
    final requestId = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(++_sequence).toRadixString(36)}';
    var stage = 'configuration', transport = 'none';
    var healthElapsedMs = 0, healthHttpStatus = 0, modelHttpStatus = 0, attempts = 0;
    var modelElapsedMs = 0, headersElapsedMs = 0, firstEventElapsedMs = 0, firstContentElapsedMs = 0, requestBytes = 0;
    Stopwatch? activeModelClock;
    var transportReused = false, tailAborted = false;
    Object? diagnosticFailure;
    ThirdChannelResponse? accepted;
    final aborted = Completer<Never>();
    var invalid = false, expired = false, checking = false, finished = false;
    final signals = <Completer<void>>{};
    ThirdChannelTransportLease? lease;
    void abort(Object error) {
      if (finished || aborted.isCompleted) return;
      aborted.completeError(error);
      for (final signal in signals) { if (!signal.isCompleted) signal.complete(); }
    }
    Future<void> check() async {
      cancellation?.throwIfCancelled();
      if (_closed || invalid || finished) throw const GenerationSuspendedByRuntimeGateException();
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
    void stop() => abort(const GenerationSuspendedByRuntimeGateException());
    _aborters.add(stop);
    Future<ThirdChannelResponse> run() async {
      await check();
      if (!config.configured) throw const ThirdChannelFailure('not_configured');
      Uri healthUri;
      try { healthUri = config.health; }
      catch (_) { throw const ThirdChannelFailure('invalid_url'); }
      final acquired = await _pool.acquire(config);
      if (finished) { acquired.release(); throw const GenerationSuspendedByRuntimeGateException(); }
      lease = acquired;
      await check();
      transportReused = lease!.reused;
      final client = lease!.client;
      stage = 'health';
      final probeAbort = Completer<void>(); signals.add(probeAbort);
      final healthClock = Stopwatch()..start();
      try {
        Future<http.Response> probe() async {
          final request = http.AbortableRequest('GET', healthUri, abortTrigger: probeAbort.future)
            ..headers['X-Request-ID'] = '$requestId-h';
          return http.Response.fromStream(await client.send(request));
        }
        final health = await probe().timeout(healthTimeout);
        healthHttpStatus = health.statusCode;
        if (health.statusCode != 200) throw ThirdChannelFailure('health_http_${health.statusCode}');
        Object? body;
        try { body = jsonDecode(health.body); }
        catch (_) { throw const ThirdChannelFailure('health_response'); }
        if (body is! Map || body['status'] != 'ok') throw const ThirdChannelFailure('health_response');
      } on ThirdChannelFailure { rethrow; }
      catch (error) {
        await check();
        transport = _transportKind(error);
        throw ThirdChannelFailure('health_$transport');
      } finally {
        healthElapsedMs = healthClock.elapsedMilliseconds;
        signals.remove(probeAbort);
        if (!probeAbort.isCompleted) probeAbort.complete();
      }
      for (var attempt = 1; attempt <= 2; attempt++) {
        await check();
        stage = 'model'; attempts = attempt; transport = 'none'; modelHttpStatus = 0;
        final modelClock = Stopwatch()..start();
        activeModelClock = modelClock;
        headersElapsedMs = 0; firstEventElapsedMs = 0; firstContentElapsedMs = 0;
        final modelAbort = Completer<void>(); signals.add(modelAbort);
        var received = false;
        try {
          final request = http.AbortableRequest('POST', config.endpoint, abortTrigger: modelAbort.future)
            ..headers.addAll({'Content-Type': 'application/json', 'Accept': stream ? 'text/event-stream' : 'application/json',
              'X-Request-ID': '$requestId-$attempt',
              'Authorization': 'Bearer ${config.apiKey.trim()}'})
            ..body = jsonEncode({'model': ThirdChannelConfig.model, 'messages': messages,
              'stream': stream, 'max_tokens': maxTokens.clamp(1, 65536),
              'reasoning_effort': config.reasoningEffort,
              if (responseFormat != null) 'response_format': responseFormat,
              if (tools.isNotEmpty) 'tools': tools,
              if (tools.isNotEmpty) 'tool_choice': toolChoice ?? 'auto'});
          requestBytes = request.bodyBytes.length;
          final response = await client.send(request);
          received = true;
          headersElapsedMs = clock.elapsedMilliseconds;
          modelHttpStatus = response.statusCode;
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
            Timer? tail;
            var tailTimedOut = false;
            final tailEnded = Completer<bool>();
            final iterator = StreamIterator(response.stream.transform(utf8.decoder).transform(const LineSplitter()));
            Future<void> event() async {
              if (lines.isEmpty) return;
              final data = lines.join('\n'); lines.clear();
              if (data.trim() == '[DONE]') {
                done = true;
                // Drain the HTTP response so IOClient may reuse its socket.
                // A gateway leaving the response open must not add a long wait.
                final remaining = totalTimeout - clock.elapsed - const Duration(milliseconds: 20);
                final grace = remaining < const Duration(seconds: 2)
                    ? (remaining.isNegative ? Duration.zero : remaining) : const Duration(seconds: 2);
                tail = Timer(grace, () {
                  tailTimedOut = true; tailAborted = true;
                  tailEnded.complete(false);
                  if (!modelAbort.isCompleted) modelAbort.complete();
                });
                return;
              }
              if (firstEventElapsedMs == 0) firstEventElapsedMs = clock.elapsedMilliseconds;
              final raw = jsonDecode(data);
              if (firstContentElapsedMs == 0 && raw is Map && raw['choices'] is List &&
                  (raw['choices'] as List).whereType<Map>().any((choice) =>
                    choice['delta'] is Map && choice['delta']['content'] is String &&
                    (choice['delta']['content'] as String).isNotEmpty)) {
                firstContentElapsedMs = clock.elapsedMilliseconds;
              }
              await collector.add(raw);
            }
            try {
              while (true) {
                final next = iterator.moveNext();
                final hasNext = done ? await Future.any<bool>([next, tailEnded.future]) : await next;
                if (!hasNext) break;
                final line = iterator.current;
                await check();
                if (done) continue;
                if (line.isEmpty) { await event(); }
                else if (line.startsWith('data:')) {
                  var value = line.substring(5); if (value.startsWith(' ')) value = value.substring(1);
                  lines.add(value);
                }
              }
            } on http.RequestAbortedException {
              await check();
              if (!done || !tailTimedOut) rethrow;
            } finally {
              tail?.cancel();
              // Some HTTP response streams await an unfinished chunked body
              // while canceling. That cleanup must not delay a complete reply.
              unawaited(iterator.cancel().catchError((Object _) {}));
            }
            // An unfinished data event at EOF is a broken stream, including
            // a half JSON frame. Only a final standalone DONE may omit LF.
            if (!done && lines.join('\n').trim() == '[DONE]') done = true;
            if (!done) throw const ThirdChannelFailure('stream_interrupted', retryable: true);
          } else {
            final raw = await response.stream.bytesToString();
            firstEventElapsedMs = clock.elapsedMilliseconds;
            firstContentElapsedMs = clock.elapsedMilliseconds;
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
          if (error is! ThirdChannelFailure) transport = _transportKind(error);
          final failure = error is ThirdChannelFailure ? error : ThirdChannelFailure(
            received ? 'response_interrupted' : 'connection',
            retryable: error is http.ClientException || error is TimeoutException);
          if (!failure.retryable || attempt == 2) throw failure;
        } finally {
          modelElapsedMs += modelClock.elapsedMilliseconds;
          activeModelClock = null;
          signals.remove(modelAbort);
          if (!modelAbort.isCompleted) modelAbort.complete();
        }
        await Future<void>.delayed(retryDelay);
      }
      throw const ThirdChannelFailure('exhausted');
    }
    try { final result = await bounded(run()); accepted = result; return result; }
    catch (error) { diagnosticFailure = error; rethrow; }
    finally {
      finished = true; deadline.cancel(); gate.cancel(); clock.stop();
      _aborters.remove(stop);
      for (final signal in signals) { if (!signal.isCompleted) signal.complete(); }
      signals.clear();
      final error = diagnosticFailure;
      final outcome = error is GenerationCancelledByUserException ? 'cancelled'
        : error is GenerationSuspendedByRuntimeGateException ? 'suspended'
        : error != null ? 'failed' : accepted?.incomplete == true ? 'incomplete' : 'success';
      final code = error is ThirdChannelFailure ? error.code
        : outcome == 'cancelled' ? 'user_cancelled' : outcome == 'suspended' ? 'not_current'
        : error != null ? 'unknown' : accepted?.incomplete == true ? accepted!.finishReason : '';
      if (outcome == 'failed' || tailAborted) lease?.invalidate();
      lease?.release();
      if (code == 'timeout' || code == 'health_timeout') transport = 'timeout';
      try {
        onDiagnostic?.call(ThirdChannelEvent(at: DateTime.now().millisecondsSinceEpoch,
          stage: stage, outcome: outcome, code: code, elapsedMs: clock.elapsedMilliseconds,
          healthElapsedMs: stage == 'health' ? clock.elapsedMilliseconds : healthElapsedMs,
          attempts: attempts, healthHttpStatus: healthHttpStatus, modelHttpStatus: modelHttpStatus,
          healthTimeoutMs: healthTimeout.inMilliseconds, transport: transport,
          requestId: requestId, effort: config.reasoningEffort, streaming: stream,
          modelElapsedMs: modelElapsedMs + (activeModelClock?.elapsedMilliseconds ?? 0), headersElapsedMs: headersElapsedMs,
          firstEventElapsedMs: firstEventElapsedMs, firstContentElapsedMs: firstContentElapsedMs, requestBytes: requestBytes,
          transportReused: transportReused, tailAborted: tailAborted));
      } catch (_) { /* Optional diagnostics cannot alter transport or fallback. */ }
    }
  }
  static String _transportKind(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is TlsException) return 'tls';
    if (error is SocketException) {
      final text = error.message.toLowerCase();
      if (const ['failed host lookup', 'name or service not known', 'nodename nor servname',
          'temporary failure in name resolution', 'no address associated', 'unable to resolve host']
          .any(text.contains)) return 'dns';
      return 'connection';
    }
    if (error is http.ClientException) return 'connection';
    return 'unknown';
  }
  void close() {
    _closed = true;
    for (final abort in _aborters.toList()) { abort(); }
    if (_ownsPool) _pool.close();
  }

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
