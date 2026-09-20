import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/presentation/chat_visuals.dart';
import '../core/presentation/sen_live2d_presentation.dart';
import '../core/database/app_database.dart';
import 'chat_portrait_stage.dart';

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
  const SenLive2DQuickControls({
    super.key,
    this.onChanged,
    this.onAdjust,
  });

  final Future<void> Function()? onChanged;
  final VoidCallback? onAdjust;

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
              if (widget.onAdjust != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.zoom_out_map_rounded),
                  title: const Text('调整位置与大小'),
                  subtitle: const Text('进入舞台后单指移动、双指缩放'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onAdjust,
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
    required this.nsfwActive,
    required this.transform,
    this.adjustmentEnabled = false,
    this.onTransformChanged,
    this.onAdjustmentDone,
    this.onTransformReset,
    this.animationToken,
    this.showEffect = true,
  });

  final ChatEmotionVisual emotion;
  final String outfit;
  final bool glasses;
  final bool nsfwActive;
  final ChatPortraitTransform transform;
  final bool adjustmentEnabled;
  final ValueChanged<ChatPortraitTransform>? onTransformChanged;
  final VoidCallback? onAdjustmentDone;
  final VoidCallback? onTransformReset;
  final Object? animationToken;
  final bool showEffect;

  @override
  State<SenLive2DStage> createState() => SenLive2DStageState();
}

class SenLive2DStageState extends State<SenLive2DStage> {
  MethodChannel? _channel;
  static const _effectAnchor = Offset(.60, .09);
  Timer? _effectTimer;
  bool _effectVisible = false;
  String _status = '正在启动 Sen Live2D…';
  bool _modelMissing = false;
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  String get _senEmotion => senLive2DEmotionFor(
        widget.emotion.key,
        outfit: widget.outfit,
        nsfwActive: widget.nsfwActive,
      );

  @override
  void didUpdateWidget(covariant SenLive2DStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emotion.key != oldWidget.emotion.key ||
        widget.outfit != oldWidget.outfit ||
        widget.nsfwActive != oldWidget.nsfwActive ||
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
    if (widget.transform.scale != oldWidget.transform.scale ||
        widget.transform.offset != oldWidget.transform.offset) {
      unawaited(_invoke('setStageTransform', {
        'scale': widget.transform.scale,
        'offsetX': widget.transform.offset.dx,
        'offsetY': widget.transform.offset.dy,
      }));
    }
  }

  void listen() => unawaited(_invoke('listen'));

  /// Routes any Flutter-visible App touch to Sen's existing look target. System
  /// keyboard touches live in a separate Android window and never reach this
  /// Flutter pointer route, so they are deliberately not guessed.
  void lookAtGlobal(Offset globalPosition, {required bool active}) {
    if (widget.adjustmentEnabled) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    if (!active) {
      unawaited(_invoke('setLookTarget', const {'active': false}));
      return;
    }
    final local = renderObject.globalToLocal(globalPosition);
    final x = (local.dx / renderObject.size.width).clamp(0.0, 1.0);
    final y = (local.dy / renderObject.size.height).clamp(0.0, 1.0);
    unawaited(_invoke('setLookTarget', {
      'active': true,
      'x': x * 2 - 1,
      'y': 1 - y * 2,
    }));
  }

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
    return AndroidView(
      viewType: 'ai_companion/sen_live2d_view',
      creationParams: <String, Object?>{
        'emotion': _senEmotion,
        'outfit': widget.outfit,
        'glasses': widget.glasses,
        'scale': widget.transform.scale,
        'offsetX': widget.transform.offset.dx,
        'offsetY': widget.transform.offset.dy,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
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
        final effectScale = widget.transform.scale;
        final effectExtent = extent * effectScale;
        final effectX = (0.5 +
                (_effectAnchor.dx - 0.5) * effectScale +
                widget.transform.offset.dx) *
            constraints.maxWidth;
        final effectY = (0.5 +
                (_effectAnchor.dy - 0.5) * effectScale +
                widget.transform.offset.dy) *
            constraints.maxHeight;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildNativeStage(),
              if (widget.emotion.effectAsset != null)
                Positioned(
                  left: effectX - effectExtent / 2,
                  top: effectY - effectExtent * .20,
                  width: effectExtent,
                  height: effectExtent,
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
              if (widget.adjustmentEnabled)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      _gestureStartScale = widget.transform.scale;
                      _gestureStartOffset = widget.transform.offset;
                      _gestureStartFocal = details.localFocalPoint;
                    },
                    onScaleUpdate: (details) {
                      final delta = details.localFocalPoint - _gestureStartFocal;
                      widget.onTransformChanged?.call(
                        ChatPortraitTransform(
                          scale: (_gestureStartScale * details.scale)
                              .clamp(0.35, 6.0)
                              .toDouble(),
                          offset: Offset(
                            (_gestureStartOffset.dx +
                                    delta.dx / constraints.maxWidth)
                                .clamp(-1.5, 1.5)
                                .toDouble(),
                            (_gestureStartOffset.dy +
                                    delta.dy / constraints.maxHeight)
                                .clamp(-1.5, 1.5)
                                .toDouble(),
                          ),
                        ),
                      );
                    },
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
              if (widget.adjustmentEnabled)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: SafeArea(
                    bottom: false,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xB3000000),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '单指移动 · 双指缩放 · ${(widget.transform.scale * 100).round()}%',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onTransformReset,
                              child: const Text('还原'),
                            ),
                            FilledButton.tonal(
                              onPressed: widget.onAdjustmentDone,
                              child: const Text('完成'),
                            ),
                          ],
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
