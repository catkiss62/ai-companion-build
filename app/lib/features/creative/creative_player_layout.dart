import 'dart:math' as math;
import 'package:flutter/material.dart';

/// IME only affects the chat panel. The native page's viewport stays stable.
class CreativePlayerLayout extends StatelessWidget {
  const CreativePlayerLayout({super.key, required this.page, this.chat, this.banner, this.onMetrics});
  final Widget page;
  final Widget? chat, banner;
  final void Function(double inset, double pageHeight)? onMetrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final inset = MediaQuery.viewInsetsOf(context).bottom.clamp(0.0, math.max(0.0, constraints.maxHeight - 80)).toDouble();
    final normalChatHeight = math.min(260.0, constraints.maxHeight * .6);
    final chatHeight = math.min(normalChatHeight, math.max(0.0, constraints.maxHeight - inset));
    final pageHeight = math.max(1.0, constraints.maxHeight - (chat != null ? normalChatHeight : 0));
    onMetrics?.call(inset, pageHeight);
    return Stack(children: [
      Positioned(left: 0, right: 0, top: 0, height: pageHeight, child: page),
      if (banner != null) Align(alignment: Alignment.topCenter, child: banner!),
      if (chat != null) Positioned(left: 0, right: 0, bottom: inset, height: chatHeight, child: chat!),
    ]);
  });
}
