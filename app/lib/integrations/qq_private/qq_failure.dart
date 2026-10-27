import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qq_private_bridge/qq_private_bridge.dart';
import '../../core/ai/deepseek_client.dart';

class QqOperationFailure implements Exception {
  const QqOperationFailure(this.code);
  final String code;
}

/// Categories only. Never persist exception messages, SVG, URLs or credentials.
abstract final class QqFailure {
  static const historyKey='qq_operation_failures_v1';
  static String code(Object error) {
    if(error is QqOperationFailure)return error.code;
    if(error is DeepSeekException)return 'model_http_${error.statusCode}';
    if(error is TimeoutException)return 'timeout';
    if(error is SocketException || error is http.ClientException)return 'network';
    if(error is IncompleteJsonCompletionException)return error.finishReason=='length'?'model_output_limit':'model_incomplete';
    if(error is MalformedJsonCompletionException || error is EmptyJsonCompletionException || error is FormatException)return 'model_format';
    if(error is QqApiException)return 'qq_${error.code}';
    if(error is PlatformException) {
      final details=error.details;
      final reason=details is Map?details['reason']:null;
      if(reason is String && const {'svg_tag','svg_attribute','svg_number','svg_color','svg_path','svg_limit',
        'svg_nesting','svg_viewbox','svg_transform','svg_text','svg_xml_or_geometry'}.contains(reason))return reason;
      if(error.code=='sketch_invalid_or_busy')return 'sketch_render_busy';
      return error.code=='sketch_invalid'?'sketch_render_format':'native_render';
    }
    return 'operation_failed';
  }
  static String sketchMessage(Object error) {
    final reason=code(error);
    if(reason=='sketch_budget')return '这小时的绘图请求次数用完了，要等下个小时才能再画。';
    if(reason.contains('timeout'))return '这次画图等了太久，已经停下了，没有发出图片。';
    if(reason=='model_output_limit' || reason=='model_incomplete')return '这次画稿还没生成完整，就被接口截断了，没有得到图片。';
    if(reason.startsWith('svg_') || reason.contains('format'))return '这次画稿没能转成图片，绘图格式出了问题。';
    if(reason=='sketch_render_busy')return '绘图这边还在忙，这次没有生成图片。';
    if(reason=='network' || reason.startsWith('model_http_'))return '这次绘图请求没成功，暂时没画出来。';
    return '小涂鸦这次没画成。';
  }
}
