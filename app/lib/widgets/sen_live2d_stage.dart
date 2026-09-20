import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/presentation/chat_visuals.dart';
import '../core/presentation/sen_live2d_presentation.dart';
import '../core/database/app_database.dart';

class SenLive2DService {
  SenLive2DService._();

  static const _channel = MethodChannel('ai_companion/sen_live2d');

  static Future<SenLive2DStatus> status() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('status') ??
        const <String, Object?>{};
    return SenLive2DStatus.fromMap(raw);
  }

  static Future<SenLive2DStatus?> pickModelZip() async {
    final raw = await _channel
        .invokeMapMethod<String, Object?>('pickModelZip');
    if (raw == null || raw['cancelled'] == true) return null;
    return SenLive2DStatus.fromMap(raw);
  }
}

class SenLive2DStatus {
  const SenLive2DStatus({
    required this.available,
    required this.detail,
    required this.expressionCount,
  });

  final bool available;
  final String detail;
  final int expressionCount;

  factory SenLive2DStatus.fromMap(Map<String, Object?> map) => SenLive2DStatus(
        available: map['available'] == true,
        detail: map['detail']?.toString() ?? '尚未导入 Sen 模型 ZIP',
        expressionCount: (map['expressionCount'] as num?)?.toInt() ?? 0,
      );
}

class SenLive2DQuickControls extends StatefulWidget {
  const SenLive2DQuickControls({super.key, this.onChanged});

  final Future<void> Function()? onChanged;

  @override
  State<SenLive2DQuickControls> createState() =>
      _SenLive2DQuickControlsState();
}

class _SenLive2DQuickControlsState extends State<SenLive2DQuickControls> {
  final _db = AppDatabase.instance;
  bool _loading = true;
  bool _enabled = false;
  bool _glasses = false;
  String _outfit = 'maid';
  SenLive2DStatus? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    _enabled = (await _db.getSetting('chat_portrait_mode')) == 'sen_live2d';
    _glasses = (await _db.getSetting('sen_live2d_glasses')) == '1';
    _outfit = await _db.getSetting('sen_live2d_outfit') ?? 'maid';
    if (!senLive2DOutfitKeys.contains(_outfit)) {
      _outfit = 'maid';
    }
    try {
      _status = await SenLive2DService.status();
    } catch (error) {
      _error = error is PlatformException ? error.message : null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changed() async {
    await widget.onChanged?.call();
  }

  Future<void> _import() async {
    setState(() => _error = null);
    try {
      final next = await SenLive2DService.pickModelZip();
      if (next != null && mounted) setState(() => _status = next);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'Sen 模型导入失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.animation_rounded),
              title: const Text('Sen Live2D'),
              subtitle: Text(
                _enabled ? '已替代静态立绘 · 自主待机与触摸已开启' : '静态立绘正在使用',
              ),
              value: _enabled,
              onChanged: (value) async {
                setState(() => _enabled = value);
                await _db.setSetting(
                  'chat_portrait_mode',
                  value ? 'sen_live2d' : 'static',
                );
                await _changed();
              },
            ),
            if (_enabled) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const {
                  'maid': '女仆装',
                  'white_shirt': '白衬衫',
                  'bunny': '兔女郎',
                  'undressed': '脱',
                }.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: _outfit == entry.key,
                    onSelected: (_) async {
                      setState(() => _outfit = entry.key);
                      await _db.setSetting('sen_live2d_outfit', entry.key);
                      await _changed();
                    },
                  );
                }).toList(growable: false),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('眼镜'),
                value: _glasses,
                onChanged: (value) async {
                  setState(() => _glasses = value);
                  await _db.setSetting('sen_live2d_glasses', value ? '1' : '0');
                  await _changed();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_zip_rounded),
                title: Text(_status?.available == true ? '重新导入模型 ZIP' : '导入模型 ZIP'),
                subtitle: Text(
                  _error ?? _status?.detail ?? '只保存到本机 App 私有目录',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _import,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SenLive2DStage extends StatefulWidget {
  const SenLive2DStage({
    super.key,
    required this.emotion,
    required this.outfit,
    required this.glasses,
    this.animationToken,
    this.showEffect = true,
  });

  final ChatEmotionVisual emotion;
  final String outfit;
  final bool glasses;
  final Object? animationToken;
  final bool showEffect;

  @override
  State<SenLive2DStage> createState() => SenLive2DStageState();
}

class SenLive2DStageState extends State<SenLive2DStage> {
  MethodChannel? _channel;
  Offset _headAnchor = const Offset(.60, .09);
  Timer? _effectTimer;
  bool _effectVisible = false;
  String _status = '正在启动 Sen Live2D…';
  bool _modelMissing = false;

  String get _senEmotion => senLive2DEmotionFor(
        widget.emotion.key,
        outfit: widget.outfit,
      );

  @override
  void didUpdateWidget(covariant SenLive2DStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emotion.key != oldWidget.emotion.key ||
        widget.outfit != oldWidget.outfit ||
        widget.animationToken != oldWidget.animationToken) {
      unawaited(_invoke('setEmotion', {'emotion': _senEmotion}));
      _showEffect();
    }
    if (widget.outfit != oldWidget.outfit) {
      unawaited(_invoke('setOutfit', {'outfit': widget.outfit}));
    }
    if (widget.glasses != oldWidget.glasses) {
      unawaited(_invoke('setGlasses', {'enabled': widget.glasses}));
    }
  }

  void listen() => unawaited(_invoke('listen'));

  Future<void> reloadModel() => _invoke('reloadModel');

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel?.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Live2D presentation is optional and must never block chat.
    }
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('ai_companion/sen_live2d/view/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      final args = (call.arguments as Map?)?.cast<Object?, Object?>() ?? const {};
      switch (call.method) {
        case 'onHeadAnchor':
          final x = (args['x'] as num?)?.toDouble();
          final y = (args['y'] as num?)?.toDouble();
          if (x != null && y != null) {
            setState(() => _headAnchor = Offset(x, y));
          }
          break;
        case 'onReady':
          setState(() {
            _status = args['detail']?.toString() ?? 'Sen Live2D 已就绪';
            _modelMissing = false;
          });
          _showEffect();
          break;
        case 'onModelMissing':
          setState(() {
            _status = args['detail']?.toString() ?? '尚未导入 Sen 模型 ZIP';
            _modelMissing = true;
          });
          break;
        case 'onError':
          setState(() => _status = args['message']?.toString() ?? 'Sen Live2D 加载失败');
          break;
        case 'onStatus':
          setState(() => _status = args['status']?.toString() ?? _status);
          break;
      }
    });
  }

  void _showEffect() {
    _effectTimer?.cancel();
    final visible = widget.showEffect && widget.emotion.effectAsset != null;
    if (mounted) setState(() => _effectVisible = visible);
    if (visible) {
      _effectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _effectVisible = false);
      });
    }
  }

  Widget _buildNativeStage() {
    const viewType = 'ai_companion/sen_live2d_view';
    final creationParams = <String, Object?>{
      'emotion': _senEmotion,
      'outfit': widget.outfit,
      'glasses': widget.glasses,
      'compositionMode': 'forced_hybrid_composition',
    };

    // Sen owns a real GLSurfaceView. The standard
    // AndroidView( constructor uses texture-layer composition, which can keep
    // mesh alpha while losing sampled colour on some SurfaceView/Impeller/device
    // combinations. Keep the native hierarchy used by the verified Sen app.
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers:
            const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
          ..create();
        return controller;
      },
    );
  }

  @override
  void dispose() {
    _effectTimer?.cancel();
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = constraints.maxWidth * .5;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildNativeStage(),
              if (widget.emotion.effectAsset != null)
                Positioned(
                  left: constraints.maxWidth * _headAnchor.dx - extent / 2,
                  top: constraints.maxHeight * _headAnchor.dy - extent * .20,
                  width: extent,
                  height: extent,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _effectVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Image.asset(
                        widget.emotion.effectAsset!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              if (_modelMissing)
                Align(
                  alignment: const Alignment(0, -.35),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .62),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
