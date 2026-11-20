import 'dart:async';

import 'package:flutter/widgets.dart';

/// The owner renders immediately after writing. Expiry requests its own rebuild.
class InlineFeedback {
  InlineFeedback(this.onChanged);

  static const lifetime = Duration(seconds: 4);
  final VoidCallback onChanged;
  String? text;
  Timer? _timer;
  bool _disposed = false;

  void replace(String? value, {bool temporary = false}) {
    if (_disposed) return;
    _timer?.cancel();
    text = value;
    if (temporary && value != null) {
      _timer = Timer(lifetime, () {
        text = null;
        onChanged();
      });
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

mixin InlineFeedbackState<T extends StatefulWidget> on State<T> {
  late final inlineFeedback = InlineFeedback(() => setState(() {}));

  set briefFeedback(String text) => inlineFeedback.replace(text, temporary: true);

  @override
  void dispose() {
    inlineFeedback.dispose();
    super.dispose();
  }
}
