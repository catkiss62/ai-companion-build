import '../tts/native_tts_provider.dart';
import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/chat/chat_controller.dart';
import '../ai/reasoning_translation_service.dart';
import '../database/app_database.dart';
import '../agent/agent_tool.dart';
import '../agent/agent_tool_registry.dart';
import '../models/chat_language_variant.dart';
import '../models/chat_message.dart';
import '../presentation/generation_presentation_policy.dart';
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
    ReasoningTranslationService? translationService,
    this.onWake,
  })  : db = db ?? AppDatabase.instance,
        _controller = controller,
        _translationService =
            translationService ?? ReasoningTranslationService.instance;

  static const MethodChannel _channel =
      MethodChannel('ai_companion/background_commands');

  final AppDatabase db;
  final MessageAttachmentStorage _attachmentStorage = MessageAttachmentStorage();
  final void Function(String reason)? onWake;
  final ReasoningTranslationService _translationService;
  ChatController? _controller;
  bool _controllerInitialized = false;
  Future<void>? _initializing;
  int _overlaySendEpoch = 0;

  void start() {
    _channel.setMethodCallHandler(_handle);
    unawaited(_announceReady());
  }

  /// Acceptance completes at the durable user+job transaction, not at the
  /// end of a possibly long model reply. Completion remains owned by controller.
  Future<bool> _submit(ChatController controller, String text, String requestId, {bool Function()? isCancelled}) async {
    final accepted = Completer<bool>();
    unawaited(controller.sendText(text,
      requestedMessageId: requestId.isEmpty ? null : requestId,
      onAccepted: () { if (!accepted.isCompleted) accepted.complete(true); },
      submissionCancelled: isCancelled,
    ).then((value) { if (!accepted.isCompleted) accepted.complete(value); },
      onError: (Object error, StackTrace stack) { if (!accepted.isCompleted) accepted.complete(false); }));
    return accepted.future;
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
        final requestId = _stringArg(call.arguments, 'request_id').trim();
        final accepted = await _submit(controller, text, requestId,
          isCancelled: () => sendEpoch != _overlaySendEpoch);
        if (accepted) onWake?.call('overlay_send');
        return <String, Object?>{
          'ok': accepted && controller.error == null,
          'accepted': accepted,
          'request_id': requestId,
          'generation_active': controller.generationActive || await db.blockingGenerationJob() != null,
          'cancelled': sendEpoch != _overlaySendEpoch,
          'error': controller.error ?? (accepted ? '' : '回复通道正忙，消息尚未发送，请重试。'),
          'notice': controller.notice ?? '',
          'notice_is_error':
              GenerationPresentationPolicy.isErrorNotice(controller.notice),
          'messages': await _presentRecentMessages(8),
        };
      case 'generationSnapshot':
        return (await _generationSnapshot()).toChannelMap();
      case 'ttsSnapshot':
        try {
          final native = await NativeTtsProvider.instance.playbackSnapshot();
          if (native.containsKey('phase')) return native;
        } catch (_) {}
        final state = _controller?.ttsState;
        return <String, Object>{
          'phase': state?.phase.name ?? 'idle',
          'message_id': state?.ownerId ?? '',
        };
      case 'petAutonomySnapshot':
        return _petAutonomySnapshot();
      case 'cancelGeneration':
        _overlaySendEpoch++;
        final targetJob = _stringArg(call.arguments, 'generation_job_id').trim();
        final current = _controller;
        final identity = current?.generationIdentity;
        if (targetJob.isNotEmpty) {
          final controller = await _ensureController();
          await controller.cancelCurrentGeneration(targetJobId: targetJob);
        } else if (current != null && identity != null) {
          await current.cancelCurrentGeneration(expectedIdentity: identity);
        }
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
        final accepted = await _submit(controller, text, replyId);
        if (accepted) onWake?.call('notification_inline_reply');
        return <String, Object?>{
          'ok': accepted, 'accepted': accepted, 'request_id': replyId,
          'error': accepted ? '' : controller.error ?? '回复通道正忙，消息尚未接受。',
        };
      case 'speakMessage':
        final id = _stringArg(call.arguments, 'messageId');
        final message = await db.messageById(id);
        if (message != null && message.isAssistant) {
          final controller = await _ensureController();
          final selected =
              ChatLanguage.tryParse(await db.getSetting('tts_language')) ??
                  ChatLanguage.chinese;
          await controller.speakMessage(
            message,
            language: message.hasLanguage(selected)
                ? selected
                : ChatLanguage.chinese,
          );
        }
        return null;
      case 'stopSpeech':
        final controller = await _ensureController();
        await controller.stopSpeech();
        return null;
      case 'translateReasoning':
        final id = _stringArg(call.arguments, 'messageId').trim();
        final message = await db.messageById(id);
        if (message == null || !message.isAssistant) {
          return const <String, Object?>{
            'ok': false,
            'error': '没有找到这条助手思考。',
          };
        }
        if (!ReasoningTranslationPolicy.shouldOffer(
          message.reasoningContent,
        )) {
          return const <String, Object?>{
            'ok': false,
            'error': '这条思考不是英文居多，无需翻译。',
          };
        }
        try {
          final outcome = await _translationService.translate(
            scope: ReasoningTranslationScope.chat,
            messageId: message.id,
            reasoning: message.reasoningContent,
          );
          return <String, Object?>{
            'ok': true,
            'translation': outcome.translation,
            'cached': outcome.fromCache,
          };
        } catch (error) {
          final raw = error is ReasoningTranslationException
              ? error.message
              : error.toString();
          return <String, Object?>{
            'ok': false,
            'error': raw.length <= 220
                ? raw
                : '${raw.substring(0, 220)}…',
          };
        }
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
        jobId: controller!.generationJobId ?? '',
        cancelling: controller.cancellingGeneration,
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
      jobId: job.id,
      sending: job.status != 'failed' && job.status != 'awaiting_confirmation',
      cancelling: false,
      reasoning: job.partialReasoning,
      content: '',
      assistantMessageId: job.assistantMessageId,
      statusText: job.waitingStatusText.isNotEmpty ? job.waitingStatusText :
          await db.getSetting('agent_tool_runtime_status_text') ?? '',
      runtimePhase: job.waitingStatusText.isNotEmpty ? job.status :
          await db.getSetting('agent_tool_runtime_phase') ?? '',
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
    final showForeign =
        (await db.getSetting('show_foreign_replies')) == '1';
    final selectedLanguage = showForeign
        ? ChatLanguage.tryParse(await db.getSetting('tts_language')) ??
            ChatLanguage.chinese
        : ChatLanguage.chinese;
    final translationSources = <String, String>{
      for (final message in messages)
        if (message.isAssistant &&
            ReasoningTranslationPolicy.shouldOffer(message.reasoningContent))
          message.id: ReasoningTranslationPolicy.sourceSha256(
            message.reasoningContent,
          ),
    };
    final translations = await db.reasoningTranslationsFor(
      scope: ReasoningTranslationScope.chat.key,
      messageSourceSha256: translationSources,
    );
    final toolRecords = await db.recentAgentToolOutcomeRecords();
    final toolsByAssistant = <String, List<String>>{};
    for (final record in toolRecords) {
      final title = AgentToolRegistry.byId(record.toolId)?.title ?? '本地工具';
      final status = switch (record.status) {
        AgentToolStatus.succeeded => '成功',
        AgentToolStatus.noResult => '没有找到结果',
        AgentToolStatus.failed => '失败',
        AgentToolStatus.blocked => '未获准执行',
        AgentToolStatus.stopped => '已停止',
        AgentToolStatus.running => '进行中',
        AgentToolStatus.requested => '等待执行',
      };
      toolsByAssistant.putIfAbsent(record.assistantMessageId, () => [])
          .add(record.displayText.isEmpty
              ? '$title · $status'
              : '$title · $status\n${record.displayText}');
    }
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
      final displayLanguage = message.isAssistant &&
              message.hasLanguage(selectedLanguage)
          ? selectedLanguage
          : ChatLanguage.chinese;
      final projectedContent = displayLanguage == ChatLanguage.chinese
          ? message.content
          : '${message.contentFor(displayLanguage)}\n\n中文对照\n${message.content}';
      rows.add(<String, Object?>{
        ...message.toDb(),
        'content': projectedContent,
        'reasoning_translation_offer':
            translationSources.containsKey(message.id),
        'reasoning_translation': translations[message.id] ?? '',
        'tool_activities': toolsByAssistant[message.id] ?? const <String>[],
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
          'role': marker.hasDisplayOnlyUserContent
              ? 'interrupted_user'
              : 'system_notice',
          'content': marker.hasDisplayOnlyUserContent
              ? marker.userContent
              : marker.notice,
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
