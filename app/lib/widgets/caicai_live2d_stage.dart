import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The model stays in app-private storage; this stage only owns one native view.
class CaicaiLive2DService {
  CaicaiLive2DService._();

  static const _channel = MethodChannel('ai_companion/caicai_live2d');

  static Future<bool> get available async {
    final status = await _channel.invokeMapMethod<String, Object?>('status');
    return status?['available'] == true;
  }

  static Future<bool> pickModelZip() async {
    final imported = await _channel.invokeMapMethod<String, Object?>('pickModelZip');
    return imported?['cancelled'] == false && imported?['available'] == true;
  }
}

class CaicaiLive2DStage extends StatefulWidget {
  const CaicaiLive2DStage({super.key});

  @override
  State<CaicaiLive2DStage> createState() => _CaicaiLive2DStageState();
}

class _CaicaiLive2DStageState extends State<CaicaiLive2DStage> {
  MethodChannel? _channel;
  String? _status = '正在检查菜菜模型…';

  void _created(int id) {
    final channel = MethodChannel('ai_companion/caicai_live2d/view/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      final args = (call.arguments as Map?)?.cast<Object?, Object?>();
      switch (call.method) {
        case 'onReady':
          setState(() => _status = null);
          return;
        case 'onModelMissing':
        case 'onError':
          setState(() => _status = args?['detail']?.toString() ?? 'Live2D 模型不可用');
          return;
      }
    });
    CaicaiLive2DService.available.then((available) {
      if (mounted && !available) {
        setState(() => _status = '请先在画面设置导入菜菜女仆三配件模型 ZIP');
      }
    }).catchError((Object error) {
      if (mounted) setState(() => _status = '模型检查失败：$error');
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          AndroidView(
            viewType: 'ai_companion/caicai_live2d_view',
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
          ),
          if (_status != null)
            Center(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .68),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_status!, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
        ],
      );
}
