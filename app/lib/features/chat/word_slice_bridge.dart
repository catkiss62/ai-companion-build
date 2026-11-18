import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Geometry and read-only visible text adapter. Game owns no conversation data.
class WordSliceBridge {
  WordSliceBridge({required this.onPlaying});
  final ValueChanged<bool> onPlaying;
  static const _channel = MethodChannel('ai_companion/word_slice');
  final areaKey = GlobalKey();
  final timelineKey = GlobalKey();
  final composerKey = GlobalKey();
  final gaugeKey = GlobalKey();
  bool _disposed = false, _scheduled = false, _enabled = false;
  bool _installed = false;
  double _fraction = .62;
  String? _lastLayout;
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void schedule({required bool enabled, required double fraction}) {
    if (_disposed || !_supported) return;
    _enabled = enabled; _fraction = fraction;
    if (!_installed) {
      _installed = true;
      _channel.setMethodCallHandler((call) async {
        if (_disposed) return null;
        if (call.method == 'playing') onPlaying(call.arguments == true);
        if (call.method == 'capture') return _enabled ? captureVisibleGlyphs(timelineKey) : <Object>[];
        return null;
      });
    }
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final area = _rect(areaKey), composer = _rect(composerKey), gauge = _rect(gaugeKey);
      final ok = _enabled && area != null && composer != null && gauge != null;
      final data = <String, Object>{'enabled': ok};
      if (ok) data.addAll({
        'anchorX': gauge.center.dx,
        'panelTop': area.top + area.height * (1 - _fraction),
        'floor': composer.top,
        'hudTop': area.top,
      });
      final signature = jsonEncode(data);
      if (signature == _lastLayout) return;
      _lastLayout = signature;
      unawaited(_invoke('configure', data));
    });
  }
  // RouteObserver callbacks need not rebuild ChatPage, so hide immediately.
  void hide() {
    if (_disposed || !_supported) return;
    _enabled = false; _lastLayout = null;
    unawaited(_invoke('hide'));
  }
  Future<void> _invoke(String method, [Object? args]) async {
    try { await _channel.invokeMethod<void>(method, args); }
    on PlatformException { if (!_disposed) onPlaying(false); }
    on MissingPluginException { /* Non-Android test harness. */ }
  }
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_installed) { _channel.setMethodCallHandler(null); unawaited(_invoke('dispose')); }
  }
  static Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Snapshot rendered paragraphs only; never read hidden history or log text.
/// A visual cap bounds per-character layout work on unusually dense screens.
List<Map<String, Object>> captureVisibleGlyphs(GlobalKey key) {
  final root = key.currentContext?.findRenderObject();
  if (root is! RenderBox || !root.hasSize || !root.attached) return [];
  final clip = root.localToGlobal(Offset.zero) & root.size;
  final result = <Map<String, Object>>[];
  void visit(RenderObject object) {
    if (result.length >= 500) return;
    if (object is RenderParagraph && object.hasSize) {
      final bounds = object.localToGlobal(Offset.zero) & object.size;
      if (!bounds.overlaps(clip)) return;
      final text = object.text.toPlainText(includeSemanticsLabels: false);
      var offset = 0;
      for (final rune in text.runes) {
        if (result.length >= 500) break;
        final char = String.fromCharCode(rune), end = offset + (rune > 0xffff ? 2 : 1);
        if (char.trim().isNotEmpty && rune != 0xfffc) {
          final boxes = object.getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: end));
          if (boxes.isNotEmpty) {
            final box = boxes.first.toRect();
            final pos = object.localToGlobal(box.center);
            if (box.width > 0 && clip.contains(pos) && pos.dy-box.height/2 >= clip.top && pos.dy+box.height/2 <= clip.bottom) {
              result.add({'ch': char, 'x': pos.dx, 'y': pos.dy, 'size': (box.height*.8).clamp(12.0, 30.0)});
            }
          }
        }
        offset = end;
      }
    } else { object.visitChildren(visit); }
  }
  visit(root);
  return result;
}
