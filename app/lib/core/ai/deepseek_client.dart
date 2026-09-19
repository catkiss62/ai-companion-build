import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'chat_api_provider.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';

class DeepSeekToolCallDelta {
  const DeepSeekToolCallDelta({
    required this.index,
    this.id = '',
    this.name = '',
    this.argumentsFragment = '',
  });

  final int index;
  final String id;
  final String name;
  final String argumentsFragment;
}

class DeepSeekToolCall {
  const DeepSeekToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;

  Map<String, Object?> toAssistantMap() => <String, Object?>{
        'id': id,
        'type': 'function',
        'function': <String, Object?>{
          'name': name,
          'arguments': arguments,
        },
      };
}

class DeepSeekDelta {
  const DeepSeekDelta({
    this.reasoning = '',
    this.content = '',
    this.done = false,
    this.finishReason,
    this.toolCallDeltas = const <DeepSeekToolCallDelta>[],
  });

  final String reasoning;
  final String content;
  final bool done;
  final String? finishReason;
  final List<DeepSeekToolCallDelta> toolCallDeltas;
}

class DeepSeekUsageEvent {
  const DeepSeekUsageEvent({
    required this.lane,
    required this.executionId,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheHitTokens,
    required this.cacheMissTokens,
    required this.streaming,
    required this.promptShape,
  });

  final String lane;
  final String executionId;
  final int inputTokens;
  final int outputTokens;
  final int cacheHitTokens;
  final int cacheMissTokens;
  final bool streaming;
  final DeepSeekPromptShape promptShape;
}

/// Body-free prompt layout telemetry. Hashes make repeated stable segments
/// comparable without persisting prompt text, model output or tool fields.
class DeepSeekPromptShape {
  const DeepSeekPromptShape({
    required this.messages,
    required this.toolCount,
    required this.toolCharacters,
    required this.toolHash,
  });

  static const int version = 1;

  final List<DeepSeekPromptSegmentShape> messages;
  final int toolCount;
  final int toolCharacters;
  final String toolHash;
}

class DeepSeekPromptSegmentShape {
  const DeepSeekPromptSegmentShape({
    required this.index,
    required this.role,
    required this.characters,
    required this.hash,
  });

  final int index;
  final String role;
  final int characters;
  final String hash;
}

class DeepSeekClient {
  DeepSeekClient({
    http.Client? client,
    http.Client Function()? streamClientFactory,
    http.Client Function()? jsonClientFactory,
    Future<bool> Function()? abortWhen,
    Future<void> Function(DeepSeekUsageEvent event)? onUsage,
  })  : _client = client ?? http.Client(),
        _streamClientFactory = streamClientFactory ?? http.Client.new,
        _jsonClientFactory = jsonClientFactory ?? http.Client.new,
        _abortWhen = abortWhen,
        _onUsage = onUsage;

  static const String defaultEndpoint = 'https://api.deepseek.com/chat/completions';

  final http.Client _client;
  final http.Client Function() _streamClientFactory;
  final http.Client Function() _jsonClientFactory;
  final Future<bool> Function()? _abortWhen;
  final Future<void> Function(DeepSeekUsageEvent event)? _onUsage;
  final Set<http.Client> _streamClients = <http.Client>{};

  Stream<DeepSeekDelta> streamChat({
    required String apiKey,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> messages,
    String endpoint = defaultEndpoint,
    bool thinking = true,
    int? maxTokens,
    List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
    String? toolChoice,
    GenerationCancellationToken? cancellationToken,
    Duration requestTimeout = const Duration(seconds: 120),
    String usageLane = 'unclassified',
    String usageExecutionId = '',
  }) async* {
    final provider = ChatApiProvider.fromEndpoint(endpoint);
    final canonicalTools = _canonicalTools(tools);
    final promptShape = _promptShape(messages, canonicalTools);
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer ${apiKey.trim()}',
      })
      ..body = jsonEncode({
        'model': provider.effectiveModel(model),
        'messages': messages,
        ...provider.thinkingRequestFields(
          thinking: thinking,
          effort: effort,
        ),
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (canonicalTools.isNotEmpty) 'tools': canonicalTools,
        if (canonicalTools.isNotEmpty) 'tool_choice': toolChoice ?? 'auto',
        'stream': true,
        // DeepSeek documents this OpenAI-compatible accounting option. The
        // third-party Gemini relay is kept byte-for-byte compatible with its
        // established request shape; if it volunteers usage we still record
        // it, but diagnostics must never make the final reply fail.
        if (!provider.isGeminiRelay)
          'stream_options': const <String, Object?>{'include_usage': true},
      });

    // One client per stream lets a user cancellation close only this model
    // request. JSON maintenance calls and a later chat turn remain unaffected.
    final streamClient = _streamClientFactory();
    _streamClients.add(streamClient);
    var runtimeGateAborted = false;
    var gateCheckRunning = false;
    Timer? runtimeGateTimer;
    if (cancellationToken != null) {
      unawaited(cancellationToken.whenCancelled.then((_) {
        streamClient.close();
      }));
    }
    final abortWhen = _abortWhen;
    if (abortWhen != null) {
      Future<void> checkRuntimeGate() async {
        if (gateCheckRunning || runtimeGateAborted) return;
        gateCheckRunning = true;
        try {
          if (await abortWhen()) {
            runtimeGateAborted = true;
            streamClient.close();
          }
        } catch (_) {
          // A diagnostic gate check must never break an otherwise valid call.
        } finally {
          gateCheckRunning = false;
        }
      }

      runtimeGateTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(checkRuntimeGate()),
      );
      unawaited(checkRuntimeGate());
    }

    try {
      cancellationToken?.throwIfCancelled();
      final response = await streamClient
          .send(request)
          .timeout(requestTimeout);
      cancellationToken?.throwIfCancelled();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw DeepSeekException(response.statusCode, _extractError(body));
      }

      final lines = response.stream
          .timeout(requestTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final rawLine in lines) {
        cancellationToken?.throwIfCancelled();
        final line = rawLine.trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') {
          yield const DeepSeekDelta(done: true);
          break;
        }
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final usage = _usageEvent(
          json['usage'],
          lane: usageLane,
          executionId: usageExecutionId,
          streaming: true,
          promptShape: promptShape,
        );
        if (usage != null) {
          try {
            await _onUsage?.call(usage);
          } catch (_) {
            // Accounting is diagnostic-only and must never fail a reply.
          }
        }
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final first = choices.first as Map<String, dynamic>;
        final delta =
            (first['delta'] as Map?)?.cast<String, dynamic>() ?? const {};
        final reasoning = delta['reasoning_content'] as String? ?? '';
        final content = delta['content'] as String? ?? '';
        final finishReason = first['finish_reason'] as String?;
        final toolCallDeltas = <DeepSeekToolCallDelta>[];
        final rawToolCalls = delta['tool_calls'];
        if (rawToolCalls is List) {
          for (final rawCall in rawToolCalls.whereType<Map>()) {
            final call = rawCall.cast<String, dynamic>();
            final function =
                (call['function'] as Map?)?.cast<String, dynamic>() ?? const {};
            toolCallDeltas.add(DeepSeekToolCallDelta(
              index: (call['index'] as num?)?.toInt() ?? 0,
              id: call['id'] as String? ?? '',
              name: function['name'] as String? ?? '',
              argumentsFragment: function['arguments'] as String? ?? '',
            ));
          }
        }
        if (reasoning.isNotEmpty ||
            content.isNotEmpty ||
            toolCallDeltas.isNotEmpty ||
            finishReason != null) {
          yield DeepSeekDelta(
            reasoning: reasoning,
            content: content,
            finishReason: finishReason,
            toolCallDeltas: toolCallDeltas,
          );
        }
      }
    } catch (_) {
      if (cancellationToken?.isCancelled ?? false) {
        throw const GenerationCancelledByUserException();
      }
      if (runtimeGateAborted) {
        throw const GenerationSuspendedByRuntimeGateException();
      }
      rethrow;
    } finally {
      runtimeGateTimer?.cancel();
      _streamClients.remove(streamClient);
      streamClient.close();
    }
  }

  Future<Map<String, dynamic>> jsonCompletion({
    required String apiKey,
    required DeepSeekModelProfile model,
    required List<Map<String, Object?>> messages,
    String endpoint = defaultEndpoint,
    bool thinking = false,
    ReasoningEffort effort = ReasoningEffort.high,
    int maxTokens = 1400,
    GenerationCancellationToken? cancellationToken,
    Duration requestTimeout = const Duration(seconds: 120),
    String usageLane = 'unclassified',
    String usageExecutionId = '',
  }) async {
    final provider = ChatApiProvider.fromEndpoint(endpoint);
    final promptShape = _promptShape(
      messages,
      const <Map<String, Object?>>[],
    );
    final abortWhen = _abortWhen;
    final ownsClient = cancellationToken != null || abortWhen != null;
    final requestClient = ownsClient ? _jsonClientFactory() : _client;
    var runtimeGateAborted = false;
    var gateCheckRunning = false;
    Timer? runtimeGateTimer;
    if (cancellationToken != null) {
      unawaited(cancellationToken.whenCancelled.then((_) {
        requestClient.close();
      }));
    }
    if (abortWhen != null) {
      Future<void> checkRuntimeGate() async {
        if (gateCheckRunning || runtimeGateAborted) return;
        gateCheckRunning = true;
        try {
          if (await abortWhen()) {
            runtimeGateAborted = true;
            requestClient.close();
          }
        } catch (_) {
          // Gate probing is best effort; the provider timeout still applies.
        } finally {
          gateCheckRunning = false;
        }
      }

      runtimeGateTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(checkRuntimeGate()),
      );
      unawaited(checkRuntimeGate());
    }
    try {
      cancellationToken?.throwIfCancelled();
      final response = await requestClient
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode({
              'model': provider.effectiveModel(model),
              'messages': messages,
              ...provider.thinkingRequestFields(
                thinking: thinking,
                effort: effort,
              ),
              'max_tokens': maxTokens,
              'response_format': {'type': 'json_object'},
              'stream': false,
            }),
          )
          .timeout(requestTimeout);
      cancellationToken?.throwIfCancelled();
      if (runtimeGateAborted) {
        throw const GenerationSuspendedByRuntimeGateException();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DeepSeekException(
          response.statusCode,
          _extractError(response.body),
        );
      }
      Map<String, dynamic> root;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) throw const FormatException();
        root = decoded.cast<String, dynamic>();
      } on FormatException {
        throw const MalformedJsonCompletionException();
      }
      final choices = root['choices'];
      final usage = _usageEvent(
        root['usage'],
        lane: usageLane,
        executionId: usageExecutionId,
        streaming: false,
        promptShape: promptShape,
      );
      if (usage != null) {
        try {
          await _onUsage?.call(usage);
        } catch (_) {
          // Accounting is diagnostic-only and must never fail a reply.
        }
      }
      if (choices is! List || choices.isEmpty) {
        throw const MalformedJsonCompletionException();
      }
      final firstRaw = choices.first;
      if (firstRaw is! Map) {
        throw const MalformedJsonCompletionException();
      }
      final first = firstRaw.cast<String, dynamic>();
      final messageRaw = first['message'];
      if (messageRaw is! Map) {
        throw const MalformedJsonCompletionException();
      }
      final message = messageRaw.cast<String, dynamic>();
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const EmptyJsonCompletionException();
      }
      try {
        final decoded = jsonDecode(content.trim());
        if (decoded is! Map) throw const FormatException();
        return decoded.cast<String, dynamic>();
      } on FormatException {
        throw const MalformedJsonCompletionException();
      }
    } catch (_) {
      if (cancellationToken?.isCancelled ?? false) {
        throw const GenerationCancelledByUserException();
      }
      if (runtimeGateAborted) {
        throw const GenerationSuspendedByRuntimeGateException();
      }
      rethrow;
    } finally {
      runtimeGateTimer?.cancel();
      if (ownsClient) requestClient.close();
    }
  }

  String _extractError(String body) {
    try {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      final error = parsed['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {
      // Return raw body below.
    }
    return body.length > 500 ? body.substring(0, 500) : body;
  }

  static DeepSeekUsageEvent? _usageEvent(
    Object? raw, {
    required String lane,
    required String executionId,
    required bool streaming,
    required DeepSeekPromptShape promptShape,
  }) {
    if (raw is! Map) return null;
    int value(String key) => (raw[key] as num?)?.toInt() ?? 0;
    final prompt = value('prompt_tokens');
    final completion = value('completion_tokens');
    final hit = value('prompt_cache_hit_tokens');
    final miss = value('prompt_cache_miss_tokens');
    if (prompt == 0 && completion == 0 && hit == 0 && miss == 0) return null;
    return DeepSeekUsageEvent(
      lane: lane.trim().isEmpty ? 'unclassified' : lane.trim(),
      executionId: executionId.trim(),
      inputTokens: prompt,
      outputTokens: completion,
      cacheHitTokens: hit,
      cacheMissTokens: miss,
      streaming: streaming,
      promptShape: promptShape,
    );
  }

  static List<Map<String, Object?>> _canonicalTools(
    List<Map<String, Object?>> tools,
  ) =>
      tools
          .map((tool) => _canonicalValue(tool) as Map<String, Object?>)
          .toList(growable: false);

  static DeepSeekPromptShape _promptShape(
    List<Map<String, Object?>> messages,
    List<Map<String, Object?>> tools,
  ) {
    final segments = <DeepSeekPromptSegmentShape>[];
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      final encoded = _shapeValue(message['content']);
      segments.add(DeepSeekPromptSegmentShape(
        index: index,
        role: message['role']?.toString().trim() ?? '',
        characters: encoded.runes.length,
        hash: _shortHash(encoded),
      ));
    }
    final encodedTools = tools.isEmpty ? '' : jsonEncode(tools);
    return DeepSeekPromptShape(
      messages: List.unmodifiable(segments),
      toolCount: tools.length,
      toolCharacters: encodedTools.runes.length,
      toolHash: encodedTools.isEmpty ? '' : _shortHash(encodedTools),
    );
  }

  static String _shapeValue(Object? value) => value is String
      ? value
      : jsonEncode(_canonicalValue(value));

  static Object? _canonicalValue(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return <String, Object?>{
        for (final entry in entries)
          entry.key: _canonicalValue(entry.value),
      };
    }
    if (value is List) {
      return value.map(_canonicalValue).toList(growable: false);
    }
    return value;
  }

  static String _shortHash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 12);

  void close() {
    for (final streamClient in _streamClients.toList(growable: false)) {
      streamClient.close();
    }
    _streamClients.clear();
    _client.close();
  }
}

/// A successful HTTP response that never produced the requested JSON body.
/// Keep this deliberately body-free: callers
/// may persist the exception category, so neither reasoning nor prompt data may
/// be carried by the error.
class EmptyJsonCompletionException implements Exception {
  const EmptyJsonCompletionException();

  @override
  String toString() => 'empty_json_completion_content';
}

class MalformedJsonCompletionException implements Exception {
  const MalformedJsonCompletionException();

  @override
  String toString() => 'malformed_json_completion_content';
}

class DeepSeekException implements Exception {
  const DeepSeekException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => '聊天 API $statusCode: $message';
}
