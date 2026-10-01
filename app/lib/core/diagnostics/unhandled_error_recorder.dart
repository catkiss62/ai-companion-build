import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Best-effort native breadcrumbs, independent of a potentially broken DB.
/// Never forwards exception messages, stack text, chat data or filesystem paths.
class UnhandledErrorRecorder {
  UnhandledErrorRecorder({required this.runtime, Future<void> Function(Map<String, String>)? write})
      : _write = write ?? _writeNative;
  final String runtime;
  final Future<void> Function(Map<String, String>) _write;
  final Map<String, DateTime> _recent = {};
  var _pending = false;

  static Future<void> _writeNative(Map<String, String> event) async {
    const channel = MethodChannel('ai_companion/system');
    await channel.invokeMethod<void>('recordDartRuntimeError', event)
        .timeout(const Duration(seconds: 2));
  }

  Future<void> record(Object error, StackTrace? stack, String source) async {
    if (_pending) return;
    final now = DateTime.now();
    _recent.removeWhere((_, at) => now.difference(at) > const Duration(minutes: 1));
    final rawType = error.runtimeType.toString().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    final type = rawType.length > 80 ? rawType.substring(0, 80) : rawType;
    final trace = stack?.toString() ?? '';
    final fingerprint = sha256.convert(utf8.encode('$type\n$trace')).toString();
    if (_recent.containsKey(fingerprint) || _recent.length >= 8) return;
    _recent[fingerprint] = now;
    _pending = true;
    final frame = RegExp(r'#[0-9]+\s+([A-Za-z_][A-Za-z0-9_$.<>]*)\s+\(package:ai_companion_localfirst/')
        .firstMatch(trace)?.group(1) ?? '';
    try {
      await _write({'runtime': runtime, 'source': source, 'errorType': type,
        'stackFp': fingerprint, 'frame': frame});
    } catch (_) {
      // Reporting must not recursively report its own channel/timeout failures.
    } finally { _pending = false; }
  }

  /// Preserve the previous handlers and the platform's original error behavior.
  void install() {
    final flutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(record(details.exception, details.stack, 'flutter'));
      if (flutterHandler != null) flutterHandler(details);
      else FlutterError.presentError(details);
    };
    final platformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(error, stack, 'platform'));
      return platformHandler?.call(error, stack) ?? false;
    };
  }
}
