import 'package:flutter/material.dart';

import '../core/ai/reasoning_translation_service.dart';

class ReasoningPanel extends StatefulWidget {
  const ReasoningPanel({
    super.key,
    required this.reasoning,
    this.streaming = false,
    this.messageId = '',
    this.translationScope,
    this.translationService,
  });

  final String reasoning;
  final bool streaming;
  final String messageId;
  final ReasoningTranslationScope? translationScope;
  final ReasoningTranslationService? translationService;

  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel> {
  String? _translation;
  String? _translationError;
  bool _translating = false;
  int _loadEpoch = 0;
  late bool _expanded;

  ReasoningTranslationService get _service =>
      widget.translationService ?? ReasoningTranslationService.instance;

  bool get _canTranslate =>
      !widget.streaming &&
      widget.messageId.trim().isNotEmpty &&
      widget.translationScope != null &&
      ReasoningTranslationPolicy.shouldOffer(widget.reasoning);

  @override
  void initState() {
    super.initState();
    _expanded = widget.streaming;
    _loadCachedTranslation();
  }

  @override
  void didUpdateWidget(covariant ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reasoning != widget.reasoning ||
        oldWidget.messageId != widget.messageId ||
        oldWidget.translationScope != widget.translationScope ||
        oldWidget.streaming != widget.streaming) {
      _translation = null;
      _translationError = null;
      _translating = false;
      _loadCachedTranslation();
    }
    if (!oldWidget.streaming && widget.streaming && !_expanded) {
      _expanded = true;
    }
  }

  Future<void> _loadCachedTranslation() async {
    final epoch = ++_loadEpoch;
    if (!_canTranslate) return;
    try {
      final value = await _service.cached(
        scope: widget.translationScope!,
        messageId: widget.messageId,
        reasoning: widget.reasoning,
      );
      if (!mounted || epoch != _loadEpoch || value == null) return;
      setState(() => _translation = value);
    } catch (_) {
      // Cache failures never hide the original provider reasoning.
    }
  }

  Future<void> _translate() async {
    if (!_canTranslate || _translating) return;
    setState(() {
      _translating = true;
      _translationError = null;
    });
    try {
      final outcome = await _service.translate(
        scope: widget.translationScope!,
        messageId: widget.messageId,
        reasoning: widget.reasoning,
      );
      if (!mounted) return;
      setState(() => _translation = outcome.translation);
    } catch (error) {
      if (!mounted) return;
      final raw = error is ReasoningTranslationException
          ? error.message
          : error.toString();
      setState(() {
        _translationError =
            raw.length <= 220 ? raw : '${raw.substring(0, 220)}…';
      });
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reasoning.trim().isEmpty) return const SizedBox.shrink();
    final translation = _translation?.trim() ?? '';
    const purple = Color(0xFFB388FF);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: widget.streaming,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: AnimatedRotation(
          turns: _expanded ? 0.25 : 0,
          duration: const Duration(milliseconds: 150),
          child: const Icon(
            Icons.arrow_right_rounded,
            size: 15,
            color: purple,
          ),
        ),
        title: const Text(
          'THINKING',
          style: TextStyle(
            color: purple,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.0,
          ),
        ),
        trailing: const SizedBox.shrink(),
        onExpansionChanged: (value) => setState(() => _expanded = value),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              widget.reasoning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (_canTranslate && translation.isEmpty) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _translating ? null : _translate,
                style: TextButton.styleFrom(
                  foregroundColor: purple,
                  disabledForegroundColor: purple.withValues(alpha: 0.58),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: Text(
                  _translating
                      ? '翻译中…'
                      : _translationError == null
                          ? '翻译'
                          : '重试翻译',
                ),
              ),
            ),
          ],
          if (_translationError != null && translation.isEmpty) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _translationError!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.35,
                    ),
              ),
            ),
          ],
          if (translation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '中文翻译',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: purple,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                translation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
