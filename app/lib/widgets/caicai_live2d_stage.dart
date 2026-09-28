import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

class CaicaiLive2DService {
  CaicaiLive2DService._();
  static const _channel = MethodChannel('ai_companion/caicai_live2d');
  static final revision = ValueNotifier<int>(0);
  static Future<Map<String, Object?>> get diagnostics async =>
      (await _channel.invokeMapMethod<String, Object?>('status')) ?? const {};
  static Future<bool> get available async => (await diagnostics)['available'] == true;
  static Future<void> setEditorFocused(bool focused) =>
      _channel.invokeMethod<void>('setEditorFocused', focused);
  static Future<bool> pickModelZip() async {
    final imported = await _channel.invokeMapMethod<String, Object?>('pickModelZip');
    final success = imported?['cancelled'] == false && imported?['available'] == true;
    if (success) revision.value++;
    return success;
  }
  static Future<void> clearImportedModels() async {
    await _channel.invokeMethod<void>('clearImportedModels');
    revision.value++;
  }
  static Future<Object?> command(String method, [Object? arguments]) =>
      _channel.invokeMethod<Object?>('control', {'method': method, 'arguments': arguments});
}

class CaicaiLive2DStage extends StatefulWidget {
  const CaicaiLive2DStage({super.key, this.qForm = false, this.emotion = 'normal'});
  final bool qForm;
  final String emotion;
  @override
  State<CaicaiLive2DStage> createState() => _CaicaiLive2DStageState();
}

class _CaicaiLive2DStageState extends State<CaicaiLive2DStage> {
  MethodChannel? _channel;
  bool _available = false;
  int _generation = 0;
  int _modelRevision = 0;
  String? _status = '正在检查菜菜模型…';
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    CaicaiLive2DService.revision.addListener(_checkModel);
    _checkModel();
  }

  Future<void> _checkModel() async {
    final generation = ++_generation;
    try {
      final model = await CaicaiLive2DService.diagnostics;
      final exists = model['available'] == true;
      if (!mounted || generation != _generation) return;
      _channel?.setMethodCallHandler(null);
      _channel = null;
      setState(() {
        _modelRevision++;
        _available = exists;
        _status = exists ? '正在加载菜菜模型…' :
            (model['detail']?.toString() ?? '请在 Live2D 设置中导入菜菜模型 ZIP');
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() {
        _available = false;
        _status = '模型检查失败：$error';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_keyboardVisible == visible) return;
    _keyboardVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _channel?.invokeMethod<void>('setKeyboardVisible', visible);
    });
  }

  @override
  void didUpdateWidget(CaicaiLive2DStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qForm != widget.qForm || oldWidget.emotion != widget.emotion) _syncState();
  }

  Future<void> _syncState() async {
    await _channel?.invokeMethod<void>('setForm', widget.qForm);
    await _channel?.invokeMethod<void>('setEmotion', widget.emotion);
  }

  void _created(int id) {
    final channel = MethodChannel('ai_companion/caicai_live2d/view/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || _channel != channel) return;
      final args = (call.arguments as Map?)?.cast<Object?, Object?>();
      switch (call.method) {
        case 'onReady':
          setState(() => _status = null);
          await _syncState();
          return;
        case 'onStatus':
          if (_status != null) setState(() => _status = args?['detail']?.toString() ?? '正在加载模型…');
          return;
        case 'onModelMissing':
        case 'onError':
          setState(() => _status = args?['detail']?.toString() ?? 'Live2D 模型不可用');
          return;
      }
    });
    () async {
      try {
        await channel.invokeMethod<void>('setKeyboardVisible', _keyboardVisible);
        final state = await channel.invokeMapMethod<String, Object?>('start');
        if (!mounted || _channel != channel) return;
        if (state?['status'] == 'ready') {
          setState(() => _status = null);
          await _syncState();
        } else if (state?['status'] == 'missing' || state?['status'] == 'error') {
          setState(() => _status = state?['detail']?.toString());
        }
      } catch (error) {
        if (mounted) setState(() => _status = '模型加载失败：$error');
      }
    }();
  }

  @override
  void dispose() {
    CaicaiLive2DService.revision.removeListener(_checkModel);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    // No imported model means no native view, GL thread or focus participant.
    if (_available) PlatformViewLink(
      key: ValueKey(_modelRevision),
      viewType: 'ai_companion/caicai_live2d_view',
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: 'ai_companion/caicai_live2d_view',
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        controller.addOnPlatformViewCreatedListener(_created);
        controller.create();
        return controller;
      },
    ),
    if (_status != null) Center(child: IgnorePointer(child: Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(12)),
      child: Text(_status!, style: const TextStyle(color: Colors.white)),
    ))),
  ]);
}
