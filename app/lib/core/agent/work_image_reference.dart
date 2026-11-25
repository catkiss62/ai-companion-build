import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../ai/generation_cancellation.dart';
import '../ai/model_profile.dart';
import '../ai/routed_vision_client.dart';
import '../ai/qwen_vision_client.dart';
import '../database/app_database.dart';
import '../models/message_attachment.dart';
import '../platform/android_bridge.dart';
import '../storage/secure_config.dart';

/// A selected image belongs to one work turn. Only its description and
/// fingerprint are checkpointed, so a resumed order can reuse the observation.
class WorkImageReference {
  WorkImageReference(this.name, this.bytes) : digest = sha256.convert(bytes).toString();
  final String name;
  final Uint8List bytes;
  final String digest;
  Map<String, Object?> get receipt => {'name': name, 'sha256': digest};

  static Future<WorkImageReference?> choose() async {
    const reason = 'work_image_gallery';
    final bridge = AndroidBridge.instance;
    await bridge.beginSystemPickerOverlayGuard(reason: reason);
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery,
          maxWidth: 2560, maxHeight: 2560, imageQuality: 90, requestFullMetadata: false);
    } finally {
      await bridge.endSystemPickerOverlayGuard(reason: reason);
    }
    if (file == null) return null;
    if (await file.length() > 25 * 1024 * 1024) throw const FormatException('图片过大，请选择较小的图片');
    final data = await file.readAsBytes();
    if (data.isEmpty) throw const FormatException('图片没有可读取的内容');
    final buffer = await ui.ImmutableBuffer.fromUint8List(data);
    try {
      final info = await ui.ImageDescriptor.encoded(buffer);
      try {
        final known = data.length >= 12 &&
            (data[0] == 0xff && data[1] == 0xd8 ||
             data[0] == 137 && data[1] == 80 ||
             ascii.decode(data.sublist(8,12),allowInvalid:true) == 'WEBP');
        final longest = info.width > info.height ? info.width : info.height;
        if (known && longest <= 2560) return WorkImageReference(file.name, data);
        final scale = longest > 2560 ? 2560 / longest : 1.0;
        final codec = await info.instantiateCodec(
          targetWidth:(info.width * scale).round().clamp(1,2560).toInt(),
          targetHeight:(info.height * scale).round().clamp(1,2560).toInt());
        try {
          final frame = await codec.getNextFrame();
          try {
            final png = await frame.image.toByteData(format:ui.ImageByteFormat.png);
            if (png == null) throw const FormatException('无法转换这张图片');
            return WorkImageReference(file.name,png.buffer.asUint8List(png.offsetInBytes,png.lengthInBytes));
          } finally { frame.image.dispose(); }
        } finally { codec.dispose(); }
      } finally { info.dispose(); }
    } finally { buffer.dispose(); }
  }

  Future<String> observe({required AppDatabase db, required SecureConfig config,
    required String endpoint, required DeepSeekModelProfile model,
    required String goal, required GenerationCancellationToken cancel,
    http.Client Function()? clientFactory}) async {
    cancel.throwIfCancelled();
    final vision = RoutedVisionClient(db:db, secure:config, route:ImageVisionRoute.first,
        firstModel:() async => model, clientFactory:clientFactory, current:() async => !cancel.isCancelled);
    try {
      final observation = await cancelWithToken(vision.observeBytes(apiKey:'', endpoint:endpoint,
          model:model.apiName, imageBytes:bytes,
          caption:'用户主动为工作任务选择的图片。按任务关注画面和清晰可辨的文字。任务：$goal'), cancel);
      if (observation.inputContentSha256 != digest || observation.summary.trim().isEmpty) {
        throw const FormatException('未能核实图片内容，请重新选择图片');
      }
      return observation.summary;
    } on QwenVisionException catch (error) {
      throw StateError('第一通道识图失败${error.statusCode > 0 ? "（HTTP ${error.statusCode}）" : ""}');
    } on FormatException {
      throw const FormatException('第一通道未返回可用的图片识别结果');
    } finally { vision.close(); }
  }
}
