import 'package:flutter/material.dart';

/// A glass stem ending in a heart bulb; white is empty, pink rises with heat.
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
            height: 98,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: heat / 100),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOut,
              builder: (_, amount, __) => CustomPaint(
                painter: _HeartFlaskPainter(amount),
              ),
            ),
          ),
        ),
      );
}

class _HeartFlaskPainter extends CustomPainter {
  _HeartFlaskPainter(this.amount);
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final path = Path()
      ..moveTo(center - 6, 7)
      ..lineTo(center + 6, 7)
      ..lineTo(center + 6, 59)
      ..cubicTo(center + 18, 47, center + 20, 71, center + 10, 85)
      ..quadraticBezierTo(center, 94, center, 94)
      ..quadraticBezierTo(center - 10, 85, center - 10, 85)
      ..cubicTo(center - 20, 71, center - 18, 47, center - 6, 59)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xF7FFFFFF));
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 94 - 87 * amount.clamp(0, 1), size.width, 94),
      Paint()..color = const Color(0xFFF776B7),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFDB4E98)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(center - 9, 6),
      Offset(center + 9, 6),
      Paint()
        ..color = const Color(0xFFDB4E98)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center - 2, 18),
      Offset(center - 2, 43),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HeartFlaskPainter oldDelegate) =>
      oldDelegate.amount != amount;
}
