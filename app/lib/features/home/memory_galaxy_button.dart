import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small, self-contained star field; animation repaints only this button.
class MemoryGalaxyButton extends StatefulWidget {
  const MemoryGalaxyButton({
    super.key,
    required this.onPressed,
    this.opening = false,
  });

  final VoidCallback? onPressed;
  final bool opening;

  @override
  State<MemoryGalaxyButton> createState() => _MemoryGalaxyButtonState();
}

class _MemoryGalaxyButtonState extends State<MemoryGalaxyButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 36),
  );
  late final _GalaxyButtonPainter _painter = _GalaxyButtonPainter(_motion);
  bool _tickerEnabled = false;
  bool _reduceMotion = true;
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.of(context);
    final media = MediaQuery.maybeOf(context);
    _reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_tickerEnabled && _resumed && !_reduceMotion) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CustomPaint(
            painter: _painter,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(24),
                splashColor: const Color(0x339CD9FF),
                highlightColor: const Color(0x1FFFFFFF),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.opening)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF6EFFF),
                          ),
                        )
                      else
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 21,
                          color: Color(0xFFDFD3FF),
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '记忆星谷',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFFF9F5FF),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99201845),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalaxyButtonPainter extends CustomPainter {
  _GalaxyButtonPainter(this.motion) : super(repaint: motion);

  final Animation<double> motion;

  static final List<_ButtonStar> _stars = List.generate(32, (index) {
    return _ButtonStar(
      x: ((index * 137 + 41) % 997) / 997,
      y: ((index * 83 + 29) % 101) / 101,
      radius: index % 7 == 0 ? 1.5 : 0.65 + (index % 3) * 0.2,
      phase: index * 2.399963,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = motion.value;
    final wave = math.sin(t * math.pi * 2);
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1, -0.7 + wave * 0.2),
          end: Alignment(1, 0.8 - wave * 0.2),
          colors: [
            const Color(0xFF302F78),
            Color.lerp(
              const Color(0xFF604694),
              const Color(0xFF544C9C),
              (wave + 1) / 2,
            )!,
            const Color(0xFF393573),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );

    final glow = Offset(size.width * (0.72 + wave * 0.1), size.height * 0.25);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader =
            RadialGradient(colors: const [Color(0x2BC6A1FF), Color(0x00C6A1FF)])
                .createShader(
                  Rect.fromCircle(center: glow, radius: size.width * 0.45),
                ),
    );

    final starPaint = Paint();
    for (final star in _stars) {
      final x = ((star.x + t * 0.14) % 1) * size.width;
      final y =
          (star.y * 0.86 + 0.07) * size.height +
          math.sin(t * math.pi * 2 + star.phase) * 1.8;
      final shimmer = (math.sin(t * math.pi * 4 + star.phase) + 1) / 2;
      starPaint.color = Color.lerp(
        const Color(0x459FC6FF),
        const Color(0xCFF5E9FF),
        shimmer,
      )!;
      canvas.drawCircle(Offset(x, y), star.radius, starPaint);
      if (star.radius > 1.4) {
        starPaint.color = const Color(0x226FCEFF);
        canvas.drawCircle(Offset(x, y), star.radius * 3, starPaint);
      }
    }

    _drawMeteor(canvas, size, t, start: 0.18, duration: 0.055, x: 0.14);
    _drawMeteor(canvas, size, t, start: 0.73, duration: 0.045, x: 0.61);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(0.5), const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x3BDCC7FF),
    );
  }

  void _drawMeteor(
    Canvas canvas,
    Size size,
    double t, {
    required double start,
    required double duration,
    required double x,
  }) {
    final progress = (t - start) / duration;
    if (progress <= 0 || progress >= 1) return;
    final visibility = math.sin(progress * math.pi);
    final head = Offset(
      size.width * (x + progress * 0.3),
      size.height * (-0.3 + progress * 1.6),
    );
    final tail = head - Offset(size.width * 0.14, size.height * 0.55);
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          const Color(0x00D8ECFF),
          Color.fromARGB((visibility * 210).round(), 232, 231, 255),
        ],
      ).createShader(Rect.fromPoints(tail, head));
    canvas.drawLine(tail, head, paint);
    canvas.drawCircle(
      head,
      1.4,
      Paint()
        ..color = Color.fromARGB((visibility * 230).round(), 250, 241, 255),
    );
  }

  @override
  bool shouldRepaint(_GalaxyButtonPainter oldDelegate) =>
      oldDelegate.motion != motion;
}

class _ButtonStar {
  const _ButtonStar({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
}
