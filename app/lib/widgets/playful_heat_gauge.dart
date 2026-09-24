import 'package:flutter/material.dart';

/// A small floating heart above a glowing glass tube; pink rises with heat.
class PlayfulHeatGauge extends StatelessWidget {
  const PlayfulHeatGauge({super.key, required this.heat, required this.qForm, required this.onSelected, required this.locked});

  final int heat;
  final bool qForm;
  final bool locked;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: '气焰值 · ${qForm ? '小豆丁形态' : '本体'}',
        onSelected: onSelected,
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'kindle', child: Text('轻弹额头 · 气焰上涨')),
          const PopupMenuItem(value: 'comfort', child: Text('温柔安抚 · 气焰回落')),
          PopupMenuItem(
            value: 'lock',
            child: Text(locked ? '解除形态锁定' : '锁定当前形态'),
          ),
        ],
        child: Semantics(
          label: '气焰值 $heat，当前${qForm ? '小豆丁形态' : '本体'}，${locked ? '形态已锁定' : '自动变换'}',
          child: SizedBox(
            width: 44,
            height: 124,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: heat / 100),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOut,
              builder: (_, amount, __) => CustomPaint(
                painter: _HeartGlassPainter(amount),
              ),
            ),
          ),
        ),
      );
}

class _HeartGlassPainter extends CustomPainter {
  _HeartGlassPainter(this.amount);
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint in reference coordinates so the silhouette stays proportional if
    // the chat overlay later changes size. The tube has no artificial minimum
    // fill: an empty meter looks empty, and full height always means 100.
    canvas.save();
    canvas.scale(size.width / 44, size.height / 124);
    final heart = Path()
      ..moveTo(22, 11)
      ..cubicTo(17, 3, 10, 6, 10, 13)
      ..cubicTo(10, 19, 17, 24, 22, 27)
      ..cubicTo(27, 24, 34, 19, 34, 13)
      ..cubicTo(34, 6, 27, 3, 22, 11)
      ..close();
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0xDDF9A4E1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7A2D6), Color(0xFFD77DC4)],
        ).createShader(const Rect.fromLTWH(10, 5, 24, 23)),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0xFFFDE0F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawArc(
      const Rect.fromLTWH(12.5, 8, 9, 8),
      3.45,
      1.3,
      false,
      Paint()
        ..color = const Color(0xDFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );

    final glass = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 32, 20, 88),
      const Radius.circular(10),
    );
    final inside = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 34, 16, 84),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..color = const Color(0xCCF099DE)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xD3443548), Color(0xE8241D2A), Color(0xD348394C)],
        ).createShader(const Rect.fromLTWH(12, 32, 20, 88)),
    );

    final fill = amount.clamp(0.0, 1.0);
    if (fill > 0) {
      final surface = inside.outerRect.bottom - inside.outerRect.height * fill;
      canvas.save();
      canvas.clipRRect(inside);
      canvas.drawRect(
        Rect.fromLTRB(14, surface, 30, 120),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF7B0E4), Color(0xFFFFD1F2), Color(0xFFF59DD9)],
          ).createShader(Rect.fromLTRB(14, surface, 30, 120)),
      );
      canvas.drawOval(
        Rect.fromLTWH(14, surface - 1.5, 16, 3),
        Paint()..color = const Color(0xFFFFE0F5),
      );
      canvas.restore();
    }
    canvas.drawRRect(
      glass,
      Paint()
        ..color = const Color(0xFFFFC5ED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      const Offset(15.5, 40),
      const Offset(15.5, 109),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeartGlassPainter oldDelegate) =>
      oldDelegate.amount != amount;
}
