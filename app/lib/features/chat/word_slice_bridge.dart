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

/// Explicit message-body boundary: timestamps, icons and tool UI are not text.
class WordSliceText extends SingleChildRenderObjectWidget {
  const WordSliceText({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _WordSliceTextBox();
}
class _WordSliceTextBox extends RenderProxyBox {}

/// Read the rendered glyph positions, including SelectableText's RenderEditable.
/// No history lookup or mutation; grapheme clusters preserve emoji/combining text.
List<Map<String, Object>> captureVisibleGlyphs(GlobalKey key) {
  final root = key.currentContext?.findRenderObject();
  if (root is! RenderBox || !root.hasSize || !root.attached) return [];
  final clip = root.localToGlobal(Offset.zero) & root.size;
  final result = <Map<String, Object>>[];
  void visit(RenderObject object, bool inBody) {
    if (result.length >= 500) return;
    inBody = inBody || object is _WordSliceTextBox;
    if (inBody && (object is RenderParagraph || object is RenderEditable)) {
      final boxObject = object as RenderBox;
      if (!boxObject.hasSize || !boxObject.attached) return;
      final bounds = boxObject.localToGlobal(Offset.zero) & boxObject.size;
      if (!bounds.overlaps(clip)) return;
      final span = object is RenderParagraph ? object.text : (object as RenderEditable).text;
      final text = span?.toPlainText(includeSemanticsLabels: false) ?? '';
      var offset = 0;
      for (final char in text.characters) {
        if (result.length >= 500) break;
        final end = offset + char.length;
        if (char.trim().isNotEmpty && char != '\uFFFC') {
          final selection = TextSelection(baseOffset: offset, extentOffset: end);
          final boxes = object is RenderParagraph
              ? object.getBoxesForSelection(selection)
              : (object as RenderEditable).getBoxesForSelection(selection);
          if (boxes.isNotEmpty) {
            final box = boxes.map((b) => b.toRect()).reduce((a,b) => a.expandToInclude(b));
            final pos = boxObject.localToGlobal(box.center);
            if (box.width > 0 && clip.contains(pos) &&
                pos.dy-box.height/2 >= clip.top && pos.dy+box.height/2 <= clip.bottom) {
              result.add({'ch': char, 'x': pos.dx, 'y': pos.dy,
                'size': (box.height*.8).clamp(12.0, 30.0)});
            }
          }
        }
        offset = end;
      }
    } else { object.visitChildren((child) => visit(child, inBody)); }
  }
  visit(root, false);
  return result;
}
