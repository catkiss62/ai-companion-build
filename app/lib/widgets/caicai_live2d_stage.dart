import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  const CaicaiLive2DStage({super.key, this.qForm = false, this.emotion = 'normal', this.active = true});
  final bool qForm;
  final bool active;
  final String emotion;
  @override
  State<CaicaiLive2DStage> createState() => _CaicaiLive2DStageState();
}

class _CaicaiLive2DStageState extends State<CaicaiLive2DStage> {
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
        _failed = false;
        _available = exists;
        _status = exists ? '已导入模型' : '未导入模型';
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() {
        _available = false;
        _status = '未导入模型';
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
    if (oldWidget.active != widget.active) _channel?.invokeMethod<void>('setVisible', widget.active);
    if (oldWidget.qForm != widget.qForm || oldWidget.emotion != widget.emotion) _syncState();
  }

  Future<void> _syncState() async {
    await _channel?.invokeMethod<void>('setForm', widget.qForm);
    await _channel?.invokeMethod<void>('setEmotion',
        CaicaiLive2DService.nativeEmotionId(widget.emotion));
  }

  void _created(int id) {
    final channel = MethodChannel('ai_companion/caicai_live2d/view/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || _channel != channel) return;
      switch (call.method) {
        case 'onReady':
          setState(() { _status = null; _failed = false; });
          await _syncState();
          return;
        case 'onStatus':
          if (_status != null) setState(() => _status = '已导入模型');
          return;
        case 'onModelMissing':
          setState(() { _failed = false; _status = '未导入模型'; });
          return;
        case 'onError':
          setState(() { _failed = true; _status = '模型显示失败'; });
          return;
      }
    });
    () async {
      try {
        await channel.invokeMethod<void>('setVisible', widget.active);
        await channel.invokeMethod<void>('setKeyboardVisible', _keyboardVisible);
        final state = await channel.invokeMapMethod<String, Object?>('start');
        if (!mounted || _channel != channel) return;
        if (state?['status'] == 'ready') {
          setState(() { _status = null; _failed = false; });
          await _syncState();
        } else if (state?['status'] == 'missing' || state?['status'] == 'error') {
          setState(() {
            _failed = state?['status'] == 'error';
            _status = _failed ? '模型显示失败' : '未导入模型';
          });
        }
      } catch (_) {
        if (mounted) setState(() { _failed = true; _status = '模型显示失败'; });
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
    if (_available) AndroidView(
      key: ValueKey(_modelRevision),
      viewType: 'ai_companion/caicai_live2d_view',
      onPlatformViewCreated: _created,
    ),
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
