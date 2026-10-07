import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Display-frame motion between sensor targets, independent of event frequency.
class RoomMotionSmoother extends ValueNotifier<Offset> {
  RoomMotionSmoother() : super(Offset.zero);

  Offset _target = Offset.zero;
  bool get isSettled => value == _target;

  void setTarget(Offset target) {
    _target = target.dx.isFinite && target.dy.isFinite
        ? Offset(target.dx.clamp(-1.0, 1.0).toDouble(),
            target.dy.clamp(-1.0, 1.0).toDouble())
        : Offset.zero;
  }

  void advance(double seconds) {
    if (isSettled || !seconds.isFinite || seconds <= 0) return;
    final alpha = 1 - math.exp(-seconds.clamp(0.0, .05) / .035);
    final next = Offset.lerp(value, _target, alpha)!;
    value = (next - _target).distanceSquared < 1e-8 ? _target : next;
  }

  void reset() {
    _target = Offset.zero;
    value = Offset.zero;
  }
}
