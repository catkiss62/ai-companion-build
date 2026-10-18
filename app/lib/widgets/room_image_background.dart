import 'package:flutter/material.dart';

const immersiveRoomBackground = 'assets/immersive/background.jpg';

/// Scale to the room width, preserve aspect ratio and crop vertically.
/// The keyboard reveals a smaller part of the same background, rather than
/// squeezing the illustration each time the input is focused.
class RoomImageBackground extends StatelessWidget {
  const RoomImageBackground({super.key, this.asset = immersiveRoomBackground});
  final String asset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    // Original 1000 x 2048 artwork: width is the only scale input. Neither
    // viewport height nor keyboard insets may distort its aspect ratio.
    final height = size.maxWidth * 2048 / 1000;
    return ColoredBox(color: const Color(0xFF111821), child: ClipRect(
      child: OverflowBox(alignment: Alignment.topCenter,
        minWidth: size.maxWidth, maxWidth: size.maxWidth,
        minHeight: height, maxHeight: height,
        child: Image.asset(asset, width: size.maxWidth, height: height,
          fit: BoxFit.contain, alignment: Alignment.topCenter, excludeFromSemantics: true))));
  });
}
