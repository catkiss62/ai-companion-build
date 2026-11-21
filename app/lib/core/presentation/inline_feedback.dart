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

  set persistent(String? value) => replace(value);
  set brief(String value) => replace(value, temporary: true);

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

/// Each operation writes only to its own card. A newer action retires the
/// old handle, including its timer and any late asynchronous completion.
class SectionFeedback {
  SectionFeedback(this.onChanged);
  final VoidCallback onChanged;
  final _sections = <String, InlineFeedback>{};

  String? text(String section) => _sections[section]?.text;

  InlineFeedback begin(String section) {
    _sections[section]?.dispose();
    return _sections[section] = InlineFeedback(onChanged);
  }

  void dispose() {
    for (final feedback in _sections.values) { feedback.dispose(); }
    _sections.clear();
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
