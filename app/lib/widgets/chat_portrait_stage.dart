import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/presentation/chat_visuals.dart';

class ChatPortraitTransform {
  const ChatPortraitTransform({
    required this.scale,
    required this.offset,
  });

  static const defaults = ChatPortraitTransform(
    scale: 1.10,
    offset: Offset.zero,
  );

  factory ChatPortraitTransform.defaultsFor(ChatPortraitSet set) =>
      ChatPortraitTransform(scale: set.defaultScale, offset: Offset.zero);

  final double scale;
  final Offset offset;
}

/// Keeps the user's persistent scale/offset outside the short-lived LingChat
/// expression animation. Image replacement uses gapless playback so an emotion
/// change never inserts a blank frame.
class ChatPortraitStage extends StatefulWidget {
  const ChatPortraitStage({
    super.key,
    required this.emotion,
    this.portraitSet = ChatPortraitSet.largeWhale,
    required this.transform,
    this.animationToken,
    this.showEffect = true,
    this.animate = true,
  });

  final ChatEmotionVisual emotion;
  final ChatPortraitSet portraitSet;
  final ChatPortraitTransform transform;
  final Object? animationToken;
  final bool showEffect;
  final bool animate;

  /// Emotion assets are square. Deriving both axes from the stage width keeps
  /// BoxFit.contain from vertically centering a small image inside a tall box
  /// after the effect was enlarged to 2x.
  static double effectExtentFor({
    required double stageWidth,
    required ChatEffectAnchor anchor,
  }) =>
      stageWidth * anchor.size;

  @override
  State<ChatPortraitStage> createState() => _ChatPortraitStageState();
}

class _ChatPortraitStageState extends State<ChatPortraitStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ChatPortraitAnimation _activeAnimation = ChatPortraitAnimation.breathing;
  Timer? _effectTimer;
  bool _effectVisible = false;
  int _playGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playEmotion();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      AssetImage(widget.emotion.portraitAssetFor(widget.portraitSet)),
      context,
    );
    final effect = widget.emotion.effectAsset;
    if (effect != null) precacheImage(AssetImage(effect), context);
  }

  @override
  void didUpdateWidget(covariant ChatPortraitStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final portraitAsset = widget.emotion.portraitAssetFor(widget.portraitSet);
    final oldPortraitAsset =
        oldWidget.emotion.portraitAssetFor(oldWidget.portraitSet);
    if (portraitAsset != oldPortraitAsset) {
      precacheImage(AssetImage(portraitAsset), context);
    }
    final effect = widget.emotion.effectAsset;
    if (effect != null && effect != oldWidget.emotion.effectAsset) {
      precacheImage(AssetImage(effect), context);
    }
    if (widget.emotion.key != oldWidget.emotion.key ||
        widget.animationToken != oldWidget.animationToken ||
        widget.animate != oldWidget.animate) {
      _playEmotion();
    }
  }

  Duration _durationFor(ChatPortraitAnimation animation) => switch (animation) {
        ChatPortraitAnimation.happyBounce => const Duration(milliseconds: 600),
        ChatPortraitAnimation.angryJump => const Duration(milliseconds: 800),
        ChatPortraitAnimation.seriousThink => const Duration(milliseconds: 600),
        ChatPortraitAnimation.heartBeat => const Duration(milliseconds: 800),
        ChatPortraitAnimation.naughtyBounce => const Duration(milliseconds: 300),
        ChatPortraitAnimation.embarrassedShake =>
          const Duration(milliseconds: 300),
        ChatPortraitAnimation.breathing => const Duration(seconds: 4),
        ChatPortraitAnimation.none => const Duration(milliseconds: 1),
      };

  Future<void> _playEmotion() async {
    final generation = ++_playGeneration;
    _effectTimer?.cancel();
    if (mounted) {
      setState(() {
        _effectVisible =
            widget.showEffect && widget.emotion.effectAsset != null;
      });
    }
    if (_effectVisible) {
      _effectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && generation == _playGeneration) {
          setState(() => _effectVisible = false);
        }
      });
    }

    _controller.stop();
    if (!widget.animate) {
      _activeAnimation = ChatPortraitAnimation.none;
      _controller.value = 0;
      if (mounted) setState(() {});
      return;
    }

    final requested = widget.emotion.animation;
    if (requested == ChatPortraitAnimation.none ||
        requested == ChatPortraitAnimation.breathing) {
      _activeAnimation = ChatPortraitAnimation.breathing;
      _controller.duration = _durationFor(ChatPortraitAnimation.breathing);
      _controller.repeat();
      if (mounted) setState(() {});
      return;
    }

    _activeAnimation = requested;
    _controller.duration = _durationFor(requested);
    if (mounted) setState(() {});
    await _controller.forward(from: 0);
    if (!mounted || generation != _playGeneration) return;
    _activeAnimation = ChatPortraitAnimation.breathing;
    _controller.duration = _durationFor(ChatPortraitAnimation.breathing);
    _controller.repeat();
    setState(() {});
  }

  ({double x, double y, double scale}) _motion(double t) {
    switch (_activeAnimation) {
      case ChatPortraitAnimation.happyBounce:
        return (x: 0, y: -10 * math.sin(2 * math.pi * t).abs(), scale: 1);
      case ChatPortraitAnimation.angryJump:
        final y = _piecewise(t, const [0, -15, 0, -5, 0, 0]);
        final scale = _piecewise(t, const [1, 1.03, 1, 1.01, 1, 1]);
        return (x: 0, y: y, scale: scale);
      case ChatPortraitAnimation.seriousThink:
        return (x: 0, y: 5 * math.sin(math.pi * t), scale: 1);
      case ChatPortraitAnimation.heartBeat:
        return (
          x: 0,
          y: 0,
          scale: 1 + 0.015 * math.sin(2 * math.pi * t).abs(),
        );
      case ChatPortraitAnimation.naughtyBounce:
        return (x: 0, y: -4 * math.sin(math.pi * t), scale: 1);
      case ChatPortraitAnimation.embarrassedShake:
        return (x: 5 * math.sin(2 * math.pi * t), y: 0, scale: 1);
      case ChatPortraitAnimation.breathing:
        return (
          x: 0,
          y: 0,
          scale: 1 + 0.0035 * (0.5 - 0.5 * math.cos(2 * math.pi * t)),
        );
      case ChatPortraitAnimation.none:
        return (x: 0, y: 0, scale: 1);
    }
  }

  double _piecewise(double t, List<double> values) {
    final scaled = t.clamp(0.0, 1.0).toDouble() * (values.length - 1);
    final lower = scaled.floor().clamp(0, values.length - 1).toInt();
    final upper = (lower + 1).clamp(0, values.length - 1).toInt();
    final local = scaled - lower;
    return values[lower] + (values[upper] - values[lower]) * local;
  }

  Curve _curveFor(ChatPortraitAnimation animation) => switch (animation) {
        ChatPortraitAnimation.angryJump => Curves.easeOut,
        ChatPortraitAnimation.happyBounce ||
        ChatPortraitAnimation.seriousThink ||
        ChatPortraitAnimation.heartBeat ||
        ChatPortraitAnimation.naughtyBounce ||
        ChatPortraitAnimation.embarrassedShake =>
          const Cubic(0.175, 0.885, 0.32, 1.275),
        ChatPortraitAnimation.breathing => Curves.easeInOut,
        ChatPortraitAnimation.none => Curves.linear,
      };

  @override
  void dispose() {
    _effectTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dx = widget.transform.offset.dx * constraints.maxWidth;
        final dy = widget.transform.offset.dy * constraints.maxHeight;
        final anchor = widget.portraitSet.effectAnchor;
        final effectExtent = ChatPortraitStage.effectExtentFor(
          stageWidth: constraints.maxWidth,
          anchor: anchor,
        );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(
                  scale: widget.transform.scale,
                  alignment: Alignment.topCenter,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = _curveFor(_activeAnimation)
                          .transform(
                            _controller.value.clamp(0.0, 1.0).toDouble(),
                          );
                      final motion = _motion(progress);
                      return Transform.translate(
                        offset: Offset(motion.x, motion.y),
                        child: Transform.scale(
                          scale: motion.scale,
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          widget.emotion.portraitAssetFor(widget.portraitSet),
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                        ),
                        if (widget.emotion.effectAsset != null)
                          Positioned(
                            top: constraints.maxHeight * anchor.top,
                            left: constraints.maxWidth * anchor.left,
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
                      ],
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

class ChatPortraitTransformEditor extends StatefulWidget {
  const ChatPortraitTransformEditor({
    super.key,
    required this.emotion,
    required this.portraitSet,
    required this.initial,
    required this.backgroundAsset,
  });

  final ChatEmotionVisual emotion;
  final ChatPortraitSet portraitSet;
  final ChatPortraitTransform initial;
  final String backgroundAsset;

  @override
  State<ChatPortraitTransformEditor> createState() =>
      _ChatPortraitTransformEditorState();
}

class _ChatPortraitTransformEditorState
    extends State<ChatPortraitTransformEditor> {
  late double _scale;
  late Offset _offset;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scale = widget.initial.scale;
    _offset = widget.initial.offset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义立绘'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              ChatPortraitTransform(scale: _scale, offset: _offset),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    _startScale = _scale;
                    _startOffset = _offset;
                    _startFocal = details.localFocalPoint;
                  },
                  onScaleUpdate: (details) {
                    final delta = details.localFocalPoint - _startFocal;
                    setState(() {
                      _scale = (_startScale * details.scale)
                          .clamp(0.85, 1.80)
                          .toDouble();
                      _offset = Offset(
                        (_startOffset.dx + delta.dx / constraints.maxWidth)
                            .clamp(-0.45, 0.45)
                            .toDouble(),
                        (_startOffset.dy + delta.dy / constraints.maxHeight)
                            .clamp(-0.35, 0.35)
                            .toDouble(),
                      );
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(widget.backgroundAsset, fit: BoxFit.cover),
                      ChatPortraitStage(
                        emotion: widget.emotion,
                        portraitSet: widget.portraitSet,
                        transform:
                            ChatPortraitTransform(scale: _scale, offset: _offset),
                        showEffect: false,
                        animate: false,
                      ),
                      const Positioned(
                        left: 16,
                        right: 16,
                        bottom: 18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x99000000),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              '单指拖动位置，双指缩放立绘',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      final defaults =
                          ChatPortraitTransform.defaultsFor(widget.portraitSet);
                      _scale = defaults.scale;
                      _offset = ChatPortraitTransform.defaults.offset;
                    }),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('还原'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      ChatPortraitTransform(scale: _scale, offset: _offset),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
