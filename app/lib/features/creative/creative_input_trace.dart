import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:flutter/scheduler.dart';
import '../../core/database/app_database.dart';
import '../../core/creative/creative_contract.dart';

/// Short, body-free observations around keyboard transitions, never a frame loop.
class CreativeInputTrace {
  CreativeInputTrace(this.lane, {AppDatabase? db}) : db = db ?? AppDatabase.instance;
  final String lane;
  final AppDatabase db;
  bool? _visible;
  Timer? _timer;
  bool _recording = false;
  int _frames = 0, _slow = 0, _maxBuild = 0, _maxRaster = 0;
  double _height = 0;
  void observe(double inset, double pageHeight) {
    final visible = inset > 0;
    if (_visible == visible) return;
    final first = _visible == null;
    _finish();
    _visible = visible;
    if (first && !visible) return;
    _height = pageHeight; _frames = 0; _slow = 0; _maxBuild = 0; _maxRaster = 0;
    _recording = true;
    SchedulerBinding.instance.addTimingsCallback(_timings);
    _timer = Timer(const Duration(milliseconds: 900), _finish);
  }
  void _timings(List<FrameTiming> timings) {
    for (final frame in timings) {
      _frames++;
      final build = frame.buildDuration.inMicroseconds, raster = frame.rasterDuration.inMicroseconds;
      if (build > 32000 || raster > 32000) _slow++;
      if (build > _maxBuild) _maxBuild = build;
      if (raster > _maxRaster) _maxRaster = raster;
    }
  }
  void _finish() {
    _timer?.cancel();
    if (!_recording) return;
    _recording = false;
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    final event = {'at': DateTime.now().millisecondsSinceEpoch, 'lane': lane,
      'keyboard': _visible, 'viewport_height': _height.round(), 'frames': _frames,
      'slow_frames_32ms': _slow, 'max_build_us': _maxBuild, 'max_raster_us': _maxRaster};
    unawaited(_save(event));
  }
  Future<void> _save(Map<String, Object?> event) async {
    try {
      final fence = await db.captureBrainWorkFence();
      if (fence == null) return;
      const key = 'creative_ui_trace_v1';
      final before = await db.getSetting(key) ?? '';
      final events = [...(CreativeContract.decode(before)['events'] as List? ?? []), event];
      await db.setSettingsAtomically({key: jsonEncode({'events': events.reversed.take(12).toList().reversed.toList()})},
        expectedSettings: {key: before}, workFence: fence);
    } catch (_) { /* Observations must never affect input or save state. */ }
  }
  void dispose() => _finish();
}
