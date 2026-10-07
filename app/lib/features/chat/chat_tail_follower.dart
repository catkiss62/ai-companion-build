import 'package:flutter/widgets.dart';

/// Settles lazy-list extent estimates across frames, independently of typing.
/// Real user scrolling cancels via canFollow; late size changes request again.
class ChatTailFollower {
  ChatTailFollower({required this.controller, required this.canFollow,
    this.onProgrammaticChange});
  final ScrollController controller;
  final bool Function() canFollow;
  final void Function(bool)? onProgrammaticChange;
  bool _scheduled = false;
  bool _disposed = false;
  int _attempts = 0;
  int _stableFrames = 0;

  void request() {
    if (_disposed || !canFollow()) return;
    if (_scheduled) return;
    _attempts = 0;
    _stableFrames = 0;
    _schedule();
  }

  void _schedule() {
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || !canFollow() || !controller.hasClients) return;
      final position = controller.position;
      if (!position.hasContentDimensions) return;
      final remaining = (position.maxScrollExtent - position.pixels).abs();
      if (remaining > .5) {
        _stableFrames = 0;
        onProgrammaticChange?.call(true);
        try {
          controller.jumpTo(position.maxScrollExtent);
        } finally {
          onProgrammaticChange?.call(false);
        }
      } else {
        _stableFrames++;
      }
      if (++_attempts < 12 && _stableFrames < 2) _schedule();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void dispose() { _disposed = true; }
}
