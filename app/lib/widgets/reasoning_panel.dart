import 'package:flutter/material.dart';

import '../core/ai/reasoning_translation.dart';

class ReasoningPanel extends StatelessWidget {
  const ReasoningPanel({
    super.key,
    required this.reasoning,
    this.streaming = false,
    this.messageId,
    this.translationCoordinator,
  }) : assert(
          (messageId == null) == (translationCoordinator == null),
          'messageId and translationCoordinator must be provided together',
        );

  final String reasoning;
  final bool streaming;
  final String? messageId;
  final ReasoningTranslationCoordinator? translationCoordinator;

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
          streaming ? '🧠 正在思考' : '🧠 思考',
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
          if (!streaming &&
              messageId != null &&
              translationCoordinator!.shouldOffer(reasoning))
            AnimatedBuilder(
              animation: translationCoordinator!,
              builder: (context, _) => _TranslationSection(
                messageId: messageId!,
                reasoning: reasoning,
                coordinator: translationCoordinator!,
              ),
            ),
        ],
      ),
    );
  }
}

class _TranslationSection extends StatelessWidget {
  const _TranslationSection({
    required this.messageId,
    required this.reasoning,
    required this.coordinator,
  });

  static const purple = Color(0xFF8B5CF6);

  final String messageId;
  final String reasoning;
  final ReasoningTranslationCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    final entry = coordinator.entryFor(messageId);
    final linkText = switch (entry.phase) {
      ReasoningTranslationPhase.idle => '翻译成中文',
      ReasoningTranslationPhase.translating => '翻译中…',
      ReasoningTranslationPhase.failed => '翻译失败，点击重试',
      ReasoningTranslationPhase.translated =>
        entry.visible ? '隐藏翻译' : '显示翻译',
    };
    final canTap = entry.phase != ReasoningTranslationPhase.translating;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              enabled: canTap,
              label: linkText,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canTap
                    ? () => coordinator.translate(
                          messageId: messageId,
                          reasoning: reasoning,
                        )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    linkText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: purple,
                          decoration: TextDecoration.underline,
                          decorationColor: purple,
                          decorationThickness: 1,
                        ),
                  ),
                ),
              ),
            ),
            if (entry.phase == ReasoningTranslationPhase.translated &&
                entry.visible &&
                entry.translation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  entry.translation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
