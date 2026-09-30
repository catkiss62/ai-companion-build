import 'dart:async';

import 'package:flutter/material.dart';

import '../core/presentation/chat_visuals.dart';

/// A fixed, pointer-transparent effect. It never drives the model renderer.
class ChatEmotionEffectLayer extends StatefulWidget {
  const ChatEmotionEffectLayer({
    super.key,
    required this.emotion,
    required this.replyId,
    this.enabled = true,
    this.active = true,
    this.qForm = false,
    this.generating = false,
  });
  final ChatEmotionVisual emotion;
  final String? replyId;
  final bool enabled;
  final bool active;
  final bool qForm;
  final bool generating;
  @override
  State<ChatEmotionEffectLayer> createState() => _ChatEmotionEffectLayerState();
}

class _ChatEmotionEffectLayerState extends State<ChatEmotionEffectLayer> {
  Timer? _timer;
  String? _playedReply;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _playedReply = widget.replyId;
  }

  @override
  void didUpdateWidget(ChatEmotionEffectLayer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.generating) {
      _timer?.cancel();
      _visible = false;
      return;
    }
    if (!widget.enabled || !widget.active) {
      _timer?.cancel();
      _visible = false;
      _playedReply = widget.replyId;
      return;
    }
    final id = widget.replyId;
    if (id == null || id == _playedReply) return;
    _playedReply = id;
    _timer?.cancel();
    _visible = widget.emotion.effectAsset != null;
    if (_visible)
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _visible = false);
      });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.emotion.effectAsset;
    if (asset == null) return const SizedBox.shrink();
    final anchor =
        (widget.qForm ? ChatPortraitSet.smallWhale : ChatPortraitSet.largeWhale)
            .effectAnchor;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, bounds) => ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: bounds.maxHeight * anchor.top,
                left: bounds.maxWidth * anchor.left,
                width: bounds.maxWidth * anchor.size,
                height: bounds.maxWidth * anchor.size,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
