import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model_profile.dart';

class DeepSeekDelta {
  const DeepSeekDelta({
    this.reasoning = '',
    this.content = '',
    this.done = false,
    this.finishReason,
  });

  final String reasoning;
  final String content;
  final bool done;
  final String? finishReason;
}

class DeepSeekClient {
  DeepSeekClient({http.Client? client}) : _client = client ?? http.Client();

  static const String defaultEndpoint = 'https://api.deepseek.com/chat/completions';

  final http.Client _client;

  Stream<DeepSeekDelta> streamChat({
    required String apiKey,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> messages,
    String endpoint = defaultEndpoint,
    bool thinking = true,
    int? maxTokens,
  }) async* {
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer ${apiKey.trim()}',
      })
      ..body = jsonEncode({
        'model': model.apiName,
        'messages': messages,
        'thinking': {'type': thinking ? 'enabled' : 'disabled'},
        if (thinking) 'reasoning_effort': effort.apiName,
        if (maxTokens != null) 'max_tokens': maxTokens,
        'stream': true,
      });

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw DeepSeekException(response.statusCode, _extractError(body));
    }

    final lines = response.stream
        .timeout(const Duration(seconds: 120))
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || !line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') {
        yield const DeepSeekDelta(done: true);
        break;
      }
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final first = choices.first as Map<String, dynamic>;
      final delta = (first['delta'] as Map?)?.cast<String, dynamic>() ?? const {};
      final reasoning = delta['reasoning_content'] as String? ?? '';
      final content = delta['content'] as String? ?? '';
      final finishReason = first['finish_reason'] as String?;
      if (reasoning.isNotEmpty || content.isNotEmpty || finishReason != null) {
        yield DeepSeekDelta(
          reasoning: reasoning,
          content: content,
          finishReason: finishReason,
        );
      }
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
  }) async {
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${apiKey.trim()}',
          },
          body: jsonEncode({
            'model': model.apiName,
            'messages': messages,
            'thinking': {'type': thinking ? 'enabled' : 'disabled'},
            if (thinking) 'reasoning_effort': effort.apiName,
            'max_tokens': maxTokens,
            'response_format': {'type': 'json_object'},
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeepSeekException(response.statusCode, _extractError(response.body));
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = root['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('DeepSeek 返回中没有 choices');
    }
    final message =
        ((choices.first as Map<String, dynamic>)['message'] as Map).cast<String, dynamic>();
    final content = message['content'] as String? ?? '{}';
    return (jsonDecode(content) as Map).cast<String, dynamic>();
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

  void close() => _client.close();
}

class DeepSeekException implements Exception {
  const DeepSeekException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'DeepSeek API $statusCode: $message';
}
