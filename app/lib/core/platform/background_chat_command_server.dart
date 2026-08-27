import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/chat/chat_controller.dart';
import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../storage/message_attachment_storage.dart';
import 'overlay_generation_snapshot.dart';
import 'pet_autonomy_snapshot.dart';

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
  final MessageAttachmentStorage _attachmentStorage = MessageAttachmentStorage();
  final void Function(String reason)? onWake;
  ChatController? _controller;
  bool _controllerInitialized = false;
  Future<void>? _initializing;
  int _overlaySendEpoch = 0;

  void start() {
    _channel.setMethodCallHandler(_handle);
    unawaited(_announceReady());
  }

  Future<void> _announceReady() async {
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
        return _presentRecentMessages(limit);
      case 'loadOlderMessages':
        final beforeMs = _intArg(call.arguments, 'beforeMs', 0);
        if (beforeMs <= 0) return const <Map<String, Object?>>[];
        final limit = _intArg(call.arguments, 'limit', 100).clamp(20, 200);
        return _timelineRows(
          await db.messagesBefore(
            DateTime.fromMillisecondsSinceEpoch(beforeMs),
            limit: limit,
          ),
          before: DateTime.fromMillisecondsSinceEpoch(beforeMs),
        );
      case 'overlayOpened':
        onWake?.call('overlay_opened');
        final visible = await _presentRecentMessages(8);
        unawaited(_warmOverlayController());
        return visible;
      case 'sendMessage':
        final text = _stringArg(call.arguments, 'text').trim();
        if (text.isEmpty) {
          return <String, Object?>{
            'ok': false,
            'error': '消息为空。',
            'messages': await _presentRecentMessages(8),
          };
        }
        final sendEpoch = ++_overlaySendEpoch;
        final controller = await _ensureController();
        if (sendEpoch != _overlaySendEpoch) {
          return <String, Object?>{
            'ok': false,
            'cancelled': true,
            'error': '',
            'messages': await _presentRecentMessages(8),
          };
        }
        await controller.sendText(text);
        onWake?.call('overlay_send');
        return <String, Object?>{
          'ok': controller.error == null,
          'cancelled': sendEpoch != _overlaySendEpoch,
          'error': controller.error ?? '',
          'messages': await _presentRecentMessages(8),
        };
      case 'generationSnapshot':
        return (await _generationSnapshot()).toChannelMap();
      case 'ttsSnapshot':
        final state = _controller?.ttsState;
        return <String, Object>{
          'phase': state?.phase.name ?? 'idle',
          'message_id': state?.ownerId ?? '',
        };
      case 'petAutonomySnapshot':
        return _petAutonomySnapshot();
      case 'cancelGeneration':
        _overlaySendEpoch++;
        final controller = await _ensureController();
        await controller.cancelCurrentGeneration();
        return (await _generationSnapshot()).toChannelMap();
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

  Future<Map<String, Object>> _petAutonomySnapshot() async {
    final desire = await db.loadDesire();
    final thoughts = await db.activeThoughtMetadata(limit: 16);
    final allowed = await db.brainWorkAllowed();
    return PetAutonomySnapshot.project(
      desire: desire,
      thoughts: thoughts,
      brainWorkAllowed: allowed,
    ).toChannelMap();
  }

  Future<OverlayGenerationSnapshot> _generationSnapshot() async {
    final controller = _controller;
    if (controller?.sending == true) {
      return OverlayGenerationSnapshot(
        sending: true,
        cancelling: controller!.cancellingGeneration,
        reasoning: controller.streamingReasoning,
        content: controller.streamingContent,
        assistantMessageId:
            controller.activeGenerationAssistantMessageId ?? '',
        statusText: controller.agentActivity?.text ?? '',
      );
    }

    // A full-app ChatController and the headless overlay controller are separate
    // Dart objects, but the generation job is durable and shared. Candidate
    // body checkpoints stay hidden until final guards approve one durable
    // reply; only reasoning and phase are shared while it is unfinished.
    final job = await db.blockingGenerationJob() ??
        await db.failedGenerationNeedingAttention();
    if (job == null) {
      return const OverlayGenerationSnapshot(
        sending: false,
        cancelling: false,
        reasoning: '',
        content: '',
      );
    }
    return OverlayGenerationSnapshot(
      sending: true,
      cancelling: false,
      reasoning: job.partialReasoning,
      content: '',
      assistantMessageId: job.assistantMessageId,
      statusText:
          await db.getSetting('agent_tool_runtime_status_text') ?? '',
      runtimePhase: await db.getSetting('agent_tool_runtime_phase') ?? '',
    );
  }

  Future<void> _warmOverlayController() async {
    try {
      final controller = await _ensureController();
      if (!controller.sending) {
        await controller.reload();
        await controller.onOverlayOpened();
      }
    } catch (_) {}
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

  Future<List<Map<String, Object?>>> _presentRecentMessages(int limit) async {
    final messages = await db.recentMessages(limit: limit);
    for (final message in messages.reversed) {
      if (!message.isAssistant) continue;
      await db.setSetting('chat_last_presented_assistant_id', message.id);
      break;
    }
    return _timelineRows(messages);
  }

  Future<List<Map<String, Object?>>> _timelineRows(
    List<ChatMessage> messages, {
    DateTime? before,
  }) async {
    final rows = <Map<String, Object?>>[];
    for (final message in messages) {
      final attachments = <Map<String, Object?>>[];
      for (final attachment in message.attachments) {
        final thumbnail = await _attachmentStorage.fileFor(attachment.thumbnailPath);
        final original = await _attachmentStorage.fileFor(attachment.originalPath);
        attachments.add(<String, Object?>{
          'id': attachment.id,
          'kind': attachment.kind,
          'thumbnail_path': thumbnail.path,
          'original_path': original.path,
          'width': attachment.width,
          'height': attachment.height,
        });
      }
      rows.add(<String, Object?>{
        ...message.toDb(),
        'attachments': attachments,
      });
    }
    rows.addAll(<Map<String, Object?>>[
      for (final marker in await db.recentGenerationInterruptions(
        limit: 20,
        before: before,
      ))
        if (messages.isEmpty ||
            !marker.createdAt.isBefore(messages.first.createdAt))
        <String, Object?>{
          'id': 'generation-interruption:${marker.jobId}',
          'role': 'system_notice',
          'content': '这一轮对话已中断',
          'reasoning_content': '',
          'created_at': marker.createdAt.millisecondsSinceEpoch,
          'is_proactive': 0,
          'proactive_intent': '',
          'proactive_delivery': '',
          'attachments': const <Object>[],
        },
    ]);
    rows.sort((a, b) =>
        (a['created_at'] as int).compareTo(b['created_at'] as int));
    return rows;
  }

  int _intArg(dynamic arguments, String key, int fallback) {
    if (arguments is Map) return (arguments[key] as num?)?.toInt() ?? fallback;
    return fallback;
  }

  String _stringArg(dynamic arguments, String key) {
    if (arguments is Map) return arguments[key] as String? ?? '';
    return '';
  }
}
