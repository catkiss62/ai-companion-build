import 'package:flutter/material.dart';

/// Keeps the room title and controls on the standard toolbar.
class ImmersiveRoomAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ImmersiveRoomAppBar({
    super.key,
    required this.controls,
    required this.actions,
  });

  final List<Widget> controls;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final usableWidth = width - MediaQuery.paddingOf(context).horizontal;
    final compact = usableWidth < 420;
    final leadingWidth = compact ? 44.0 : 56.0;
    final gap = compact ? 2.0 : 5.0;
    return AppBar(
      centerTitle: false,
      leadingWidth: leadingWidth,
      titleSpacing: gap,
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          '沉浸房间',
          maxLines: 1,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      actions: [
        ConstrainedBox(
          // Leave room for the back affordance and the four-character title.
          constraints: BoxConstraints(
            maxWidth: (usableWidth - leadingWidth - 56)
                .clamp(0, width)
                .toDouble(),
          ),
          child: FittedBox(
            alignment: AlignmentDirectional.centerEnd,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final control in controls) ...[
                  control,
                  SizedBox(width: gap),
                ],
                ...actions,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
