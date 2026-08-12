import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/chat/chat_controller.dart';
import '../database/app_database.dart';
import '../models/chat_message.dart';

/// Command surface used by the native WindowManager overlay.
///
/// The overlay itself is intentionally native Android. Flutter's current
/// Android embedding documents FlutterView as requiring an Activity for full
/// platform-view compatibility, while a SYSTEM_ALERT_WINDOW overlay is owned
/// by a foreground Service. Keeping the UI native avoids a fragile unsupported
/// service-hosted FlutterView while still reusing the exact same Dart chat,
/// memory, Desire, TTS and database pipeline as the full app.
class BackgroundChatCommandServer {
  BackgroundChatCommandServer({
    AppDatabase? db,
    ChatController? controller,
    this.onWake,
  })  : db = db ?? AppDatabase.instance,
        _controller = controller;

  static const MethodChannel _channel =
      MethodChannel('ai_companion/background_commands');

  final AppDatabase db;
  final void Function(String reason)? onWake;
  ChatController? _controller;
  bool _controllerInitialized = false;
  Future<void>? _initializing;

  void start() {
    _channel.setMethodCallHandler(_handle);
    unawaited(_announceReady());
  }

  Future<void> _announceReady() async {
    // Native diagnostics only call the background brain "ready" after Dart has
    // actually installed the command handler. This also lets the service detect
    // a FlutterEngine that was created successfully but whose Dart entrypoint
    // failed during startup.
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final accepted = await _channel.invokeMethod<bool>('backgroundDartReady');
        if (accepted == true) return;
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
  }

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'loadRecentMessages':
        final limit = _intArg(call.arguments, 'limit', 8).clamp(1, 40);
        return _rows(await db.recentMessages(limit: limit));
      case 'loadOlderMessages':
        final beforeMs = _intArg(call.arguments, 'beforeMs', 0);
        if (beforeMs <= 0) return const <Map<String, Object?>>[];
        final limit = _intArg(call.arguments, 'limit', 100).clamp(20, 200);
        return _rows(
          await db.messagesBefore(
            DateTime.fromMillisecondsSinceEpoch(beforeMs),
            limit: limit,
          ),
        );
      case 'overlayOpened':
        onWake?.call('overlay_opened');
        // History should appear immediately. Do not make the native overlay
        // wait for ChatController + maintenance/perception warm-up just to read
        // SQLite. The full controller is warmed asynchronously afterwards.
        final visible = _rows(await db.recentMessages(limit: 8));
        unawaited(_warmOverlayController());
        return visible;
      case 'sendMessage':
        final text = _stringArg(call.arguments, 'text').trim();
        if (text.isEmpty) {
          return <String, Object?>{
            'ok': false,
            'error': '消息为空。',
            'messages': _rows(await db.recentMessages(limit: 8)),
          };
        }
        final controller = await _ensureController();
        await controller.sendText(text);
        onWake?.call('overlay_send');
        return <String, Object?>{
          'ok': controller.error == null,
          'error': controller.error ?? '',
          'messages': _rows(await db.recentMessages(limit: 8)),
        };
      case 'notificationReply':
        final text = _stringArg(call.arguments, 'text').trim();
        final replyId = _stringArg(call.arguments, 'replyId').trim();
        if (text.isEmpty || replyId.isEmpty) {
          return <String, Object?>{
            'ok': false,
            'error': '通知快捷回复缺少正文或稳定消息 ID。',
          };
        }
        final controller = await _ensureController();
        if (controller.sending) {
          return <String, Object?>{
            'ok': false,
            'error': '另一轮聊天仍在处理中，稍后重试快捷回复。',
          };
        }
        await controller.sendText(text, requestedMessageId: replyId);
        onWake?.call('notification_inline_reply');
        return <String, Object?>{
          'ok': controller.error == null,
          'error': controller.error ?? '',
        };
      case 'speakMessage':
        final id = _stringArg(call.arguments, 'messageId');
        final message = await db.messageById(id);
        if (message != null && message.isAssistant) {
          final controller = await _ensureController();
          await controller.speakMessage(message);
        }
        return null;
      case 'stopSpeech':
        final controller = await _ensureController();
        await controller.stopSpeech();
        return null;
      case 'wakeBackground':
        final reason = _stringArg(call.arguments, 'reason').trim();
        onWake?.call(reason.isEmpty ? 'native_wake' : reason);
        return <String, Object?>{'ok': true};
      default:
        throw MissingPluginException('Unknown background command: ${call.method}');
    }
  }


  Future<void> _warmOverlayController() async {
    try {
      final controller = await _ensureController();
      // Collapsing/reopening the native window must not disturb an in-flight
      // turn that is intentionally owned by this persistent controller.
      if (!controller.sending) {
        await controller.reload();
        await controller.onOverlayOpened();
      }
    } catch (_) {
      // Recent history is already visible. Overlay warm-up is best-effort and
      // must not erase or delay the lightweight SQLite history path.
    }
  }

  Future<ChatController> _ensureController() async {
    final existing = _controller ??= ChatController(
      db: db,
      externalRecoveryOrchestrator: true,
    );
    if (_controllerInitialized) return existing;
    final pending = _initializing;
    if (pending != null) {
      await pending;
      return existing;
    }
    final future = existing.initialize();
    _initializing = future;
    try {
      await future;
      _controllerInitialized = true;
    } finally {
      _initializing = null;
    }
    return existing;
  }

  List<Map<String, Object?>> _rows(List<ChatMessage> messages) =>
      messages.map((message) => message.toDb()).toList(growable: false);

  int _intArg(dynamic arguments, String key, int fallback) {
    if (arguments is Map) return (arguments[key] as num?)?.toInt() ?? fallback;
    return fallback;
  }

  String _stringArg(dynamic arguments, String key) {
    if (arguments is Map) return arguments[key] as String? ?? '';
    return '';
  }
}
