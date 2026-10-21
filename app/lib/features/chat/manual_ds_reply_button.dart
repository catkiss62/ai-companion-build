import 'package:flutter/material.dart';

/// Confirmation belongs to the reply that was active when the dialog opened.
class ManualDsReplyButton extends StatefulWidget {
  const ManualDsReplyButton({super.key, required this.replyIdentity,
    required this.enabled, required this.selected, required this.onConfirmed});

  final Object? replyIdentity;
  final bool enabled, selected;
  final Future<void> Function(Object replyIdentity) onConfirmed;

  @override
  State<ManualDsReplyButton> createState() => _ManualDsReplyButtonState();
}

class _ManualDsReplyButtonState extends State<ManualDsReplyButton> {
  bool _dialogOpen = false;

  Future<void> _confirm() async {
    final identity = widget.replyIdentity;
    if (_dialogOpen || identity == null || !widget.enabled || widget.selected) return;
    setState(() => _dialogOpen = true);
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('使用DS回复？'),
        content: const Text('确认后会停止第二通道的本轮回复，改用第一通道重新生成回复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认回复')),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (approved != true || !widget.enabled || widget.selected ||
        widget.replyIdentity != identity) return;
    await widget.onConfirmed(identity);
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: widget.enabled && !widget.selected && !_dialogOpen &&
        widget.replyIdentity != null ? _confirm : null,
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    ),
    child: Text(widget.selected ? '已切换 DS' : '使用DS回复'),
  );
}
