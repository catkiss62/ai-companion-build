import 'package:flutter/services.dart';

class Live2DModelStorageStatus {
  const Live2DModelStorageStatus({
    required this.hasData,
    required this.bytes,
  });

  final bool hasData;
  final int bytes;
}

class Live2DModelStorage {
  Live2DModelStorage._();

  static const MethodChannel _channel = MethodChannel(
    'ai_companion/live2d_model_storage',
  );

  static Future<Live2DModelStorageStatus> status() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('status');
    return Live2DModelStorageStatus(
      hasData: raw?['hasData'] == true,
      bytes: (raw?['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<int> clearImportedModels() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'clearImportedModels',
    );
    if (raw?['cleared'] != true) {
      throw StateError('Live2D 模型清理未完成');
    }
    return (raw?['deletedBytes'] as num?)?.toInt() ?? 0;
  }
}
