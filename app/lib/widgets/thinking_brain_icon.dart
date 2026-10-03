import 'package:flutter/material.dart';

const thinkingColor = Color(0xFFB388FF);

class ThinkingBrainIcon extends StatelessWidget {
  const ThinkingBrainIcon({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SizedBox.square(dimension: size, child: CustomPaint(
      painter: _BrainPainter(color ?? theme.color ?? Colors.black),
    ));
  }
}

class _BrainPainter extends CustomPainter {
  const _BrainPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()..color = color..style = PaintingStyle.stroke
      ..strokeWidth = 1.7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final left = Path()..moveTo(12, 5)
      ..cubicTo(12, 1.5, 7, 1.5, 6.7, 5)
      ..cubicTo(3.2, 4.8, 2.3, 8, 3.5, 10)
      ..cubicTo(1, 12, 2.2, 16, 5, 16.5)
      ..cubicTo(4.8, 20.8, 10.6, 22.2, 12, 18.5)..close();
    canvas.drawPath(left, pen);
    canvas.save(); canvas.translate(24, 0); canvas.scale(-1, 1);
    canvas.drawPath(left, pen); canvas.restore();
    canvas.drawPath(Path()..moveTo(6.7, 5)..quadraticBezierTo(6.5, 8, 9, 8)
      ..moveTo(3.5, 10)..quadraticBezierTo(7, 9, 7.5, 12)
      ..moveTo(5, 16.5)..quadraticBezierTo(8.5, 17, 8.5, 14)
      ..moveTo(17.3, 5)..quadraticBezierTo(17.5, 8, 15, 8)
      ..moveTo(20.5, 10)..quadraticBezierTo(17, 9, 16.5, 12)
      ..moveTo(19, 16.5)..quadraticBezierTo(15.5, 17, 15.5, 14), pen);
  }
  @override
  bool shouldRepaint(_BrainPainter oldDelegate) => oldDelegate.color != color;
}
