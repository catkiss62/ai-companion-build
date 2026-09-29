import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

class CaicaiLive2DService {
  CaicaiLive2DService._();
  static const _channel = MethodChannel('ai_companion/caicai_live2d');
  static final editor = ValueNotifier<Map<String, Object?>?>(null);
  static final revision = ValueNotifier<int>(0);
  static Future<Map<String, Object?>> get diagnostics async =>
      (await _channel.invokeMapMethod<String, Object?>('status')) ?? const {};
  static Future<bool> get available async => (await diagnostics)['available'] == true;
  static String nativeEmotionId(String emotion) => switch (emotion) {
        'crying' => 'sad',
        'nervous' => 'tense',
        'embarrassed' => 'ashamed',
        _ => emotion,
      };
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
  const CaicaiLive2DStage({super.key, this.qForm = false, this.emotion = 'normal', this.active = true, this.sceneSize});
  final Size? sceneSize;
  final bool qForm;
  final bool active;
  final String emotion;
  @override
  State<CaicaiLive2DStage> createState() => _CaicaiLive2DStageState();
}

class _CaicaiLive2DStageState extends State<CaicaiLive2DStage> with WidgetsBindingObserver {
  Timer? _loadDeadline;
  bool _foreground = true;
  MethodChannel? _channel;
  bool _available = false;
  bool _failed = false;
  int _generation = 0;
  int _modelRevision = 0;
  String? _status = '未导入模型';
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CaicaiLive2DService.revision.addListener(_checkModel);
    _checkModel();
  }

  Future<void> _checkModel() async {
    final generation = ++_generation;
    _loadDeadline?.cancel();
    try {
      final model = await CaicaiLive2DService.diagnostics;
      final exists = model['available'] == true;
      if (!mounted || generation != _generation) return;
      _channel?.setMethodCallHandler(null);
      _channel = null;
      setState(() {
        _modelRevision++;
        _failed = false;
        _available = exists;
        _status = exists ? '素材已导入，正在加载画面…' : '未导入模型';
      });
      _watchLoading();
    } catch (_) {
      if (mounted && generation == _generation) setState(() {
        _available = false;
        _failed = true;
        _status = '无法读取模型状态，请重试';
      });
    }
  }

  // This also covers failure before onPlatformViewCreated. File availability is
  // not renderer readiness, and a missing callback must never spin indefinitely.
  void _watchLoading() {
    _loadDeadline?.cancel();
    if (!_available || _status == null || _failed || !widget.active || !_foreground) return;
    final generation = _generation;
    _loadDeadline = Timer(const Duration(seconds: 30), () async {
      try {
        final state = await _channel?.invokeMapMethod<String, Object?>('getState')
            .timeout(const Duration(seconds: 3));
        if (!mounted || generation != _generation || !widget.active || !_foreground || _status == null) return;
        if (state?['status'] == 'ready') {
          setState(() { _status = null; _failed = false; });
          await _syncState();
          return;
        }
      } catch (_) {}
      if (mounted && generation == _generation && widget.active && _foreground && _status != null) {
        setState(() { _failed = true; _status = '画面加载未完成，请重试；模型文件仍保留'; });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _watchLoading();
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
    if (oldWidget.active != widget.active) {
      _channel?.invokeMethod<void>('setVisible', widget.active);
      _watchLoading();
    }
    if (oldWidget.qForm != widget.qForm || oldWidget.sceneSize != widget.sceneSize) _syncState();
  }

  Future<void> _syncState() async {
    await _channel?.invokeMethod<void>('setForm', widget.qForm);
    final size=widget.sceneSize;
    if(size!=null) await _channel?.invokeMethod<void>('setSceneSize',{'width':size.width,'height':size.height});
  }

  void _created(int id) {
    final channel = MethodChannel('ai_companion/caicai_live2d/view/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || _channel != channel) return;
      switch (call.method) {
        case 'onReady':
          _loadDeadline?.cancel();
          setState(() { _status = null; _failed = false; });
          await _syncState();
          return;
        case 'onStatus':
          return;
        case 'onModelMissing':
          _loadDeadline?.cancel();
          setState(() { _failed = false; _status = '未导入模型'; });
          return;
        case 'onError':
          _loadDeadline?.cancel();
          setState(() { _failed = true; _status = '模型显示失败'; });
          return;
      }
    });
    () async {
      try {
        await _syncState();
        await channel.invokeMethod<void>('setVisible', widget.active);
        await channel.invokeMethod<void>('setKeyboardVisible', _keyboardVisible);
        final state = await channel.invokeMapMethod<String, Object?>('start');
        if (!mounted || _channel != channel) return;
        if (state?['status'] == 'ready') {
          _loadDeadline?.cancel();
          setState(() { _status = null; _failed = false; });
          await _syncState();
        } else if (state?['status'] == 'missing' || state?['status'] == 'error') {
          _loadDeadline?.cancel();
          setState(() {
            _failed = state?['status'] == 'error';
            _status = _failed ? '模型显示失败' : '未导入模型';
          });
        }
      } catch (_) {
        if (mounted && _channel == channel) {
          _loadDeadline?.cancel();
          setState(() { _failed = true; _status = '模型显示失败'; });
        }
      }
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadDeadline?.cancel();
    CaicaiLive2DService.revision.removeListener(_checkModel);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    // No imported model means no native view, GL thread or focus participant.
    if (_available) LayoutBuilder(builder: (context, size) {
      void touch(PointerEvent event, int action) {
        if (!widget.active || size.maxWidth <= 0 || size.maxHeight <= 0) return;
        _channel?.invokeMethod<void>('stageTouch', {
          'action': action, 'x': event.localPosition.dx / size.maxWidth,
          'y': event.localPosition.dy / size.maxHeight,
        });
      }
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => touch(e, 0), onPointerMove: (e) => touch(e, 2),
        onPointerUp: (e) => touch(e, 1), onPointerCancel: (e) => touch(e, 3),
        // A GLSurfaceView inside ordinary AndroidView falls back to Virtual
        // Display, whose surface is reset on every Activity resume. Keep the
        // native surface attached with direct Hybrid Composition instead.
        child: PlatformViewLink(
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
      );
    }),
    if (_status != null) Center(child: Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_status!, style: const TextStyle(color: Colors.white)),
        if (_failed) TextButton(onPressed: _checkModel, child: const Text('重试')),
      ]),
    )),
  ]);
}
