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
  String toString() => '第二通道没有返回正文';
}

enum GenerationIncompleteReason {
  outputLimit,
  abnormalFinishReason,
  incompleteStructure,
  missingTerminalSignal,
}

class GenerationStreamIncompleteException
    implements Exception, TransientFinalReplyFailure {
  const GenerationStreamIncompleteException({
    this.reasoning = '',
    this.content = '',
    this.reason = GenerationIncompleteReason.missingTerminalSignal,
    this.finishReason = '',
  });

  final String reasoning;
  final String content;
  final GenerationIncompleteReason reason;
  final String finishReason;

  String get diagnosticCode => switch (reason) {
        GenerationIncompleteReason.outputLimit => 'output_limit',
        GenerationIncompleteReason.abnormalFinishReason =>
          'abnormal_finish_reason',
        GenerationIncompleteReason.incompleteStructure => 'incomplete_structure',
        GenerationIncompleteReason.missingTerminalSignal =>
          'missing_terminal_signal',
      };

  @override
  String toString() => switch (reason) {
        GenerationIncompleteReason.outputLimit => '聊天模型达到输出上限，回复未完成',
        GenerationIncompleteReason.abnormalFinishReason =>
          '聊天模型异常结束（$finishReason）',
        GenerationIncompleteReason.incompleteStructure => '聊天模型返回的对白结构不完整',
        GenerationIncompleteReason.missingTerminalSignal =>
          '聊天模型的流式响应在收到完成标记前结束',
      };
}

/// Cost-aware policy for the optional second final-reply lane.
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
        reason == 'error' ||
        reason == 'stream_incomplete';
  }

  /// Preserve the existing completion gate while distinguishing what actually
  /// failed. A provider's explicit terminal reason takes precedence over a
  /// missing marker or an unfinished quote; neither proves a network failure.
  static GenerationStreamIncompleteException? incompleteResponseFailure({
    required bool sawTerminalSignal,
    String finishReason = '',
    String reasoning = '',
    String content = '',
  }) {
    final normalized = finishReason.trim().toLowerCase();
    GenerationIncompleteReason? reason;
    if (normalized == 'length') {
      reason = GenerationIncompleteReason.outputLimit;
    } else if (normalized == 'stream_incomplete') {
      reason = GenerationIncompleteReason.missingTerminalSignal;
    } else if (isIncompleteFinishReason(normalized)) {
      reason = GenerationIncompleteReason.abnormalFinishReason;
    } else if (!sawTerminalSignal) {
      reason = GenerationIncompleteReason.missingTerminalSignal;
    } else if (hasStrongIncompleteStructure(content)) {
      reason = GenerationIncompleteReason.incompleteStructure;
    }
    if (reason == null) return null;
    return GenerationStreamIncompleteException(
      reasoning: reasoning,
      content: content,
      reason: reason,
      finishReason: finishReason,
    );
  }

  /// A provider may incorrectly report `stop` after cutting a structured
  /// dialogue line. Keep this deliberately narrow: natural short replies and
  /// unfinished thoughts are valid style, while an unmatched opening quote is
  /// strong evidence that the transport/model stopped mid-body.
  static bool hasStrongIncompleteStructure(String raw) {
    final text = raw.trimRight();
    if (text.isEmpty) return false;
    return _count(text, '「') > _count(text, '」') ||
        _count(text, '“') > _count(text, '”');
  }

  static int _count(String source, String token) =>
      RegExp(RegExp.escape(token)).allMatches(source).length;

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
    if (error is GenerationStreamIncompleteException) {
      return switch (error.reason) {
        GenerationIncompleteReason.outputLimit => '达到输出上限',
        GenerationIncompleteReason.abnormalFinishReason =>
          '模型异常结束（${error.finishReason.trim()}）',
        GenerationIncompleteReason.incompleteStructure => '对白结构不完整',
        GenerationIncompleteReason.missingTerminalSignal => '未收到流式完成标记',
      };
    }
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
      return '未填写第二通道 Key';
    }
    if (error is EmptyFinalReplyException) return '没有返回正文';
    return '返回格式异常';
  }
}
