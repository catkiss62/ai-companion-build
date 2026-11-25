import 'dart:io';

import 'package:flutter/services.dart';
import '../ai/final_reply_failure_policy.dart';

final _chineseMessage = RegExp(r'[\u3400-\u9fff]');

String workErrorReason(Object error, {String fallback = '暂时无法确定中断原因'}) {
  final message = switch (error) {
    PlatformException e => e.message,
    StateError e => e.message,
    FormatException e => e.message,
    String text => text,
    _ => null,
  };
  final transport = (error is PlatformException
      ? '${error.code} ${error.message ?? ""}'
      : message ?? error.toString()).toLowerCase();
  if (RegExp(r'(^|[^a-z])(socketexception|network_error|network is unreachable|failed host lookup|connection reset by peer|connection closed before full header|software caused connection abort)([^a-z]|$)').hasMatch(transport)) {
    return '连接中断';
  }
  if (error is HandshakeException) return '安全连接握手失败';
  if (error is HttpException) return '网络请求中断';
  if (RegExp(r'(^|[^a-z])(timeout|timed out)([^a-z]|$)').hasMatch(transport)) return '请求超时';
  if (message != null && _chineseMessage.hasMatch(message)) return message;
  if(error is PlatformException && RegExp(r'^(?:page_|quiz_)').hasMatch(error.code)) {
    return '网页操作未能完成（${error.code}）';
  }
  if (error is PlatformException || error is FileSystemException) {
    return '无法访问文件，请检查保存位置和读写权限';
  }
  final reason = FinalReplyFailurePolicy.userCategory(error);
  return reason == '返回格式异常' && error is! FormatException ? fallback : reason;
}
