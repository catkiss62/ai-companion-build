import 'package:flutter/material.dart';

const thinkingColor = Color(0xFFB388FF);

class ThinkingIcon extends StatelessWidget {
  const ThinkingIcon({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.lightbulb_outline, color: color);
}
