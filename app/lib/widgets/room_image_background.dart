import 'package:flutter/material.dart';

const immersiveRoomBackground = 'assets/immersive/background.jpg';

/// Preserve the complete image width; adapt its height to the room viewport.
/// The keyboard reveals a smaller part of the same background, rather than
/// squeezing the illustration each time the input is focused.
class RoomImageBackground extends StatelessWidget {
  const RoomImageBackground({super.key, this.asset = immersiveRoomBackground});
  final String asset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final height = size.maxHeight + MediaQuery.viewInsetsOf(context).bottom;
    return ClipRect(child: OverflowBox(alignment: Alignment.topCenter,
      minWidth: size.maxWidth, maxWidth: size.maxWidth,
      minHeight: height, maxHeight: height,
      child: Image.asset(asset, width: size.maxWidth, height: height,
          fit: BoxFit.fill, alignment: Alignment.topCenter, excludeFromSemantics: true)));
  });
}
