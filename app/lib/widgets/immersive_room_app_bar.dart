import 'package:flutter/material.dart';

/// The production room header. Narrow/large-text layouts reserve a complete
/// title row, while keeping the same controls on a separate accessible row.
class ImmersiveRoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ImmersiveRoomAppBar({super.key, required this.compact,
    required this.controls, required this.actions});
  final bool compact;
  final List<Widget> controls;
  final List<Widget> actions;
  static bool useCompact(double width, double scaledTitleSize) => width < 420 || scaledTitleSize > 18;
  @override Size get preferredSize => Size.fromHeight(kToolbarHeight + (compact ? 52 : 0));
  @override Widget build(BuildContext context) => AppBar(
    titleSpacing: 8,
    title: const Text('沉浸房间', maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    actions: [if (!compact) ..._spacedControls(), ...actions],
    bottom: compact ? PreferredSize(preferredSize: const Size.fromHeight(52),
      child: SizedBox(height: 52, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: _spacedControls())))) : null,
  );
  List<Widget> _spacedControls() => [for (final control in controls) ...[
    control, const SizedBox(width: 5),
  ]];
}
