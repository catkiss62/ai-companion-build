import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'deepseek_client.dart';
import 'generation_cancellation.dart';

abstract interface class TransientFinalReplyFailure {}

class EmptyFinalReplyException
    implements Exception, TransientFinalReplyFailure {
  const EmptyFinalReplyException();

  @override
  String toString() => 'Gemini 没有返回正文';
}

class GenerationStreamIncompleteException
    implements Exception, TransientFinalReplyFailure {
  const GenerationStreamIncompleteException({
    this.reasoning = '',
    this.content = '',
  });

  final String reasoning;
  final String content;

  @override
  String toString() => '聊天模型的流式连接在收到完成标记前结束';
}

/// Cost-aware policy for the fixed-price Gemini final-reply lane.
///
/// An attempt means one HTTP request. Only failures that a second request can
/// plausibly repair consume the user's one allowed retry. Configuration and
/// protocol errors go straight to the already-configured DeepSeek fallback.
class FinalReplyFailurePolicy {
  const FinalReplyFailurePolicy._();

  static const int maxGeminiAttempts = 2;
  static const Duration retryDelay = Duration(milliseconds: 650);

  static bool isIncompleteFinishReason(String raw) {
    final reason = raw.trim().toLowerCase();
    if (reason.isEmpty || reason == 'stop') return false;
    return reason == 'length' ||
        reason == 'content_filter' ||
        reason == 'safety' ||
        reason == 'error';
  }

  static bool isTransient(Object error) {
    if (error is GenerationCancelledByUserException) return false;
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException ||
        error is TransientFinalReplyFailure) {
      return true;
    }
    if (error is DeepSeekException) {
      return error.statusCode == 429 ||
          error.statusCode == 500 ||
          error.statusCode == 502 ||
          error.statusCode == 503 ||
          error.statusCode == 504;
    }
    return false;
  }

  static String userCategory(Object error) {
    if (error is TimeoutException) return '请求超时';
    if (error is SocketException || error is http.ClientException) {
      return '连接中断';
    }
    if (error is GenerationStreamIncompleteException) return '流式连接中断';
    if (error is DeepSeekException) {
      if (error.statusCode == 429) return '服务繁忙（429）';
      if (error.statusCode >= 500) return '中转服务异常（${error.statusCode}）';
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Key 或权限错误（${error.statusCode}）';
      }
      return '请求被拒绝（${error.statusCode}）';
    }
    if (error is FormatException &&
        error.message.toString().contains('missing_gemini_final_reply_key')) {
      return '未填写 Gemini Key';
    }
    if (error is EmptyFinalReplyException) return '没有返回正文';
    return '返回格式异常';
  }
}
