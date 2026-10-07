import 'package:ai_companion_localfirst/core/presentation/room_motion_smoother.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one sensor target keeps moving on intervening display frames', () {
    final motion = RoomMotionSmoother();
    motion.setTarget(const Offset(1, -1));
    expect(motion.value, Offset.zero);
    var previous = 0.0;
    for (var frame = 0; frame < 8; frame++) {
      motion.advance(1 / 60);
      expect(motion.value.dx, greaterThan(previous));
      expect(motion.value.dy, -motion.value.dx);
      expect(motion.value.dx, lessThan(1));
      previous = motion.value.dx;
    }
    for (var frame = 0; frame < 60; frame++) {
      motion.advance(1 / 60);
    }
    expect(motion.isSettled, isTrue);
    expect(motion.value, const Offset(1, -1));
    motion.dispose();
  });

  test('display response is time based at 30, 60 and 120 FPS', () {
    Offset response(int fps) {
      final motion = RoomMotionSmoother()..setTarget(const Offset(.8, -.3));
      for (var frame = 0; frame < fps ~/ 10; frame++) {
        motion.advance(1 / fps);
      }
      final result = motion.value;
      motion.dispose();
      return result;
    }
    expect((response(30) - response(60)).distance, lessThan(1e-7));
    expect((response(60) - response(120)).distance, lessThan(1e-7));
  });

  test('reversal, invalid targets and reset remain bounded', () {
    final motion = RoomMotionSmoother()..setTarget(const Offset(5, -5));
    motion.advance(.02);
    final before = motion.value;
    motion.setTarget(const Offset(-1, 1));
    motion.advance(.02);
    expect(motion.value.dx, lessThan(before.dx));
    expect(motion.value.dx, inInclusiveRange(-1, 1));
    motion.setTarget(const Offset(double.nan, double.infinity));
    motion.advance(double.nan);
    motion.advance(.02);
    expect(motion.value.dx.isFinite && motion.value.dy.isFinite, isTrue);
    motion.reset();
    motion.advance(.02);
    expect(motion.isSettled, isTrue);
    expect(motion.value, Offset.zero);
    motion.dispose();
  });
}
