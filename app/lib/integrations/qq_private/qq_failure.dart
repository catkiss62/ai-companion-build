import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qq_private_bridge/qq_private_bridge.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/ai/qwen_vision_client.dart';

class QqOperationFailure implements Exception {
  const QqOperationFailure(this.code);
  final String code;
}

/// Categories only. Never persist exception messages, SVG, URLs or credentials.
abstract final class QqFailure {
  static const historyKey='qq_operation_failures_v1';
  static QqOperationFailure visionFailure(Object error,String stage) {
    final reason=error is TimeoutException?'timeout':
      error is SocketException || error is http.ClientException?'network':
      error is QwenVisionException?'http_${error.statusCode}':
      error is HttpException?'http':
      error is FormatException && error.message=='image_size_rejected'?'size':
      error is FormatException && error.message=='image_dimensions_rejected'?'dimensions':
      error is FormatException?'format':'failed';
    return QqOperationFailure('vision_${stage}_$reason');
  }
  static String visionMessage(String code) {
    final reason=switch(code) {
      'vision_download_size'=>'图片文件超过本次下载上限',
      'vision_download_timeout'=>'图片下载超时',
      'vision_download_network' || 'vision_download_http'=>'图片下载没有成功',
      'vision_decode_dimensions'=>'图片像素尺寸超过处理上限',
      'vision_decode_format' || 'vision_decode_failed'=>'图片解码失败',
      'vision_primary_timeout' || 'vision_fallback_timeout'=>'识图接口等待超时',
      _ when code.startsWith('vision_primary_') || code.startsWith('vision_fallback_')=>'识图接口没有返回可用结果',
      _=>'识别失败，具体原因未记录',
    };
    return '[图片：$reason；没有看到内容，不能据此判断图片损坏或用户网络有问题]';
  }
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
