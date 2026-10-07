import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/presentation/room_motion_smoother.dart';

/// The sensor repaints only this backdrop; chat layout and portrait never move.
class RoomDepthBackground extends StatefulWidget {
  const RoomDepthBackground({super.key, required this.asset,
    this.enabled = false, this.strength = .55, this.active = true});
  final String asset;
  final bool enabled;
  final double strength;
  final bool active;

  static double parseStrength(String? raw) {
    final value = double.tryParse(raw ?? '');
    return value == null || !value.isFinite ? .55 : value.clamp(.2, 1.0).toDouble();
  }

  @override
  State<RoomDepthBackground> createState() => _RoomDepthBackgroundState();
}

class _RoomDepthBackgroundState extends State<RoomDepthBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _events = const EventChannel('ai_companion/room_tilt').receiveBroadcastStream();
  static Future<ui.FragmentProgram>? _program;
  final _tilt = RoomMotionSmoother();
  late final Ticker _ticker;
  Duration? _lastTick;
  StreamSubscription<dynamic>? _subscription;
  ui.Image? _room;
  ui.Image? _depth;
  ui.FragmentShader? _shader;
  int _generation = 0;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    WidgetsBinding.instance.addObserver(this);
    _resumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _syncSensor();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(RoomDepthBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset || oldWidget.enabled != widget.enabled) {
      unawaited(_load());
    }
    _syncSensor();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncSensor();
  }

  void _syncSensor() {
    if (widget.enabled && widget.active && _resumed) {
      _subscription ??= _events.listen((dynamic event) {
        if (!mounted || !widget.enabled || !widget.active || !_resumed || event is! Map) return;
        final x = (event['x'] as num?)?.toDouble() ?? 0;
        final y = (event['y'] as num?)?.toDouble() ?? 0;
        if (event['reset'] == true || event['available'] == false) {
          _resetMotion();
          return;
        }
        _tilt.setTarget(Offset(x, y));
        _startMotion();
      }, onError: (Object _) { if (mounted) _resetMotion(); });
    } else {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _resetMotion();
    }
  }

  void _startMotion() {
    if (_shader != null && widget.enabled && widget.active && _resumed &&
        !_tilt.isSettled && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  void _onFrame(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous != null) {
      _tilt.advance((elapsed - previous).inMicroseconds / 1e6);
    }
    if (_tilt.isSettled) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  void _resetMotion() {
    _ticker.stop();
    _lastTick = null;
    _tilt.reset();
  }

  Future<ui.Image> _image(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    try { return (await codec.getNextFrame()).image; }
    finally { codec.dispose(); }
  }

  void _releaseImages() {
    _shader?.dispose(); _shader = null;
    _room?.dispose(); _room = null;
    _depth?.dispose(); _depth = null;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _ticker.stop();
    _lastTick = null;
    _releaseImages();
    if (!widget.enabled) return;
    final asset = widget.asset;
    ui.Image? room;
    ui.Image? depth;
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset('shaders/room_depth.frag'));
      room = await _image(asset);
      depth = await _image(asset.replaceFirst('.webp', '_depth.png'));
      if (!mounted || generation != _generation) return;
      setState(() {
        _room = room; _depth = depth; _shader = program.fragmentShader();
        room = null; depth = null;
      });
      _startMotion();
    } catch (_) {
      // The original packaged image remains usable on unsupported renderers.
      _program = null;
    } finally {
      room?.dispose(); depth?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader, room = _room, depth = _depth;
    return RepaintBoundary(child: shader == null || room == null || depth == null || !widget.enabled
        ? Image.asset(widget.asset, fit: BoxFit.cover, alignment: Alignment.center)
        : CustomPaint(painter: _RoomPainter(shader, room, depth, _tilt,
            widget.strength.isFinite ? widget.strength.clamp(.2, 1.0).toDouble() : .55),
            child: const SizedBox.expand()));
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _ticker.dispose();
    _tilt.dispose();
    _releaseImages();
    super.dispose();
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.shader, this.room, this.depth, this.tilt, this.strength) : super(repaint: tilt);
  final ui.FragmentShader shader;
  final ui.Image room, depth;
  final ValueNotifier<Offset> tilt;
  final double strength;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    shader
      ..setFloat(0, size.width)..setFloat(1, size.height)
      ..setFloat(2, room.width.toDouble())..setFloat(3, room.height.toDouble())
      ..setFloat(4, tilt.value.dx)..setFloat(5, tilt.value.dy)..setFloat(6, strength)
      ..setImageSampler(0, room)..setImageSampler(1, depth);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }
  @override
  bool shouldRepaint(_RoomPainter old) => old.shader != shader || old.strength != strength;
}
