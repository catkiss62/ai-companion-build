import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';

abstract final class DreamReviewDiagnostic {
  static Map<String, Object?> failure(Object error) {
    final category = switch (error) {
      IncompleteJsonCompletionException() => error.finishReason == 'length'
          ? 'output_limit' : 'abnormal_finish',
      EmptyJsonCompletionException() => 'empty_body',
      MalformedJsonCompletionException() => 'invalid_json',
      DeepSeekException() => 'http_error',
      TimeoutException() => 'timeout',
      SocketException() || http.ClientException() => 'connection_error',
      GenerationSuspendedByRuntimeGateException() ||
      GenerationCancelledByUserException() => 'runtime_interrupted',
      _ => 'review_error',
    };
    return {
      'failure_category': category,
      if (error is DeepSeekException) 'http_status': error.statusCode,
      'content_included': false,
    };
  }
}
