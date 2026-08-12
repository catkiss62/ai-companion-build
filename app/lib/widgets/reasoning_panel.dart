import 'package:flutter/material.dart';

class ReasoningPanel extends StatelessWidget {
  const ReasoningPanel({
    super.key,
    required this.reasoning,
    this.streaming = false,
    this.companionVoice = false,
  });

  final String reasoning;
  final bool streaming;
  final bool companionVoice;

  @override
  Widget build(BuildContext context) {
    if (reasoning.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: streaming,
        title: Text(
          companionVoice
              ? (streaming ? '🧠 正在整理内心' : '🧠 内心')
              : (streaming ? '🧠 正在思考' : '🧠 思考'),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          SelectableText(
            reasoning,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
