import 'dart:io';
import 'package:flutter/material.dart';
import '../core/models/room_background_config.dart';

const immersiveRoomBackground = 'assets/immersive/background.jpg';

/// Scale to the room width, preserve aspect ratio and crop vertically.
/// The keyboard reveals a smaller part of the same background, rather than
/// squeezing the illustration each time the input is focused.
class RoomImageBackground extends StatelessWidget {
  const RoomImageBackground({super.key, this.asset = immersiveRoomBackground,
    this.config = const RoomBackgroundConfig(), this.imageFile,
    this.aspectRatio = 1000/2048});
  final String asset;
  final RoomBackgroundConfig config;
  final File? imageFile;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    // Original 1000 x 2048 artwork: width is the only scale input. Neither
    // viewport height nor keyboard insets may distort its aspect ratio.
    final width = size.maxWidth * config.scale;
    final height = width / (config.mode == 'custom' ? aspectRatio : 1000/2048);
    if (!config.visible) return const ColoredBox(color:Color(0xFF111821));
    final image = config.mode == 'custom'
        ? (imageFile == null ? const SizedBox.shrink() : Image.file(imageFile!,
          width:width,height:height,fit:BoxFit.contain,excludeFromSemantics:true,
          errorBuilder:(_,__,___)=>const SizedBox.shrink()))
        : Image.asset(asset,width:width,height:height,fit:BoxFit.contain,
          alignment:Alignment.topCenter,excludeFromSemantics:true);
    return ColoredBox(color: const Color(0xFF111821), child: ClipRect(
      child: OverflowBox(alignment: Alignment.topCenter,
        minWidth: width, maxWidth: width,
        minHeight: height, maxHeight: height,
        child: Transform.translate(offset:Offset(size.maxWidth*config.x,size.maxWidth*config.y),
          child:image))));
  });
}
