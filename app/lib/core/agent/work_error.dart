import 'dart:io';

import 'package:flutter/services.dart';
import '../ai/final_reply_failure_policy.dart';

final _chineseMessage = RegExp(r'[\u3400-\u9fff]');

String workErrorReason(Object error, {String fallback = '工作未能完成，原因未明'}) {
  final message = switch (error) {
    PlatformException e => e.message,
    StateError e => e.message,
    FormatException e => e.message,
    String text => text,
    _ => null,
  };
  if (message != null && _chineseMessage.hasMatch(message)) return message;
  if (error is PlatformException || error is FileSystemException) {
    return '无法访问文件，请检查保存位置和读写权限';
  }
  if (message != null && message.contains('timeout')) return '请求超时';
  final reason = FinalReplyFailurePolicy.userCategory(error);
  return reason == '返回格式异常' && error is! FormatException ? fallback : reason;
}
