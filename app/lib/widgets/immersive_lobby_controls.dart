import 'package:flutter/material.dart';

class ImmersiveLobbyControls extends StatelessWidget {
  const ImmersiveLobbyControls({super.key, required this.model,
    required this.onBackground, required this.onCreate});
  final Widget model;
  final VoidCallback? onBackground;
  final VoidCallback? onCreate;

  static bool compact(BuildContext context, double width) =>
      width < 380 || MediaQuery.textScalerOf(context).scale(14) > 17;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final background = OutlinedButton(onPressed: onBackground,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: const Text('背景图'));
    final create = FloatingActionButton.extended(onPressed: onCreate,
      icon: const Icon(Icons.add_rounded), label: const Text('新建房间'));
    final settings = <Widget>[background, const SizedBox(width: 8), Expanded(child: model)];
    if (compact(context, constraints.maxWidth)) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
        children: [Row(children: settings), const SizedBox(height: 8), create]);
    }
    return Row(children: [...settings, const SizedBox(width: 8), create]);
  });
}
