import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/agent/agent_tool.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/ai/durable_generation_recovery.dart';
import '../../core/ai/durable_generation_runner.dart';
import '../../core/ai/generation_cancellation.dart';
import '../../core/ai/memory_extractor.dart';
import '../../core/ai/model_profile.dart';
import '../../core/ai/nsfw_context_router.dart';
import '../../core/ai/qwen_vision_client.dart';
import '../../core/database/app_database.dart';
import '../../core/desire/desire_engine.dart';
import '../../core/desire/proactive_rhythm_engine.dart';
import '../../core/desire/thought_consolidation_engine.dart';
import '../../core/desire/thought_lifecycle_engine.dart';
import '../../core/maintenance/long_running_maintenance_engine.dart';
import '../../core/memory/memory_maintenance_engine.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/message_attachment.dart';
import '../../core/models/desire_state.dart';
import '../../core/perception/perception_engine.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/relationship/relationship_assimilator.dart';
import '../../core/storage/secure_config.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../core/tts/tts_policy.dart';
import '../../core/tts/tts_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    AppDatabase? db,
    DeepSeekClient? client,
    QwenVisionClient? visionClient,
    SecureConfig? secureConfig,
    AndroidBridge? android,
    MessageAttachmentStorage? attachmentStorage,
    this.externalRecoveryOrchestrator = false,
  })  : db = db ?? AppDatabase.instance,
        client = client ?? DeepSeekClient(),
        visionClient = visionClient ?? QwenVisionClient(),
        secureConfig = secureConfig ?? SecureConfig.instance,
        android = android ?? AndroidBridge.instance,
        attachmentStorage = attachmentStorage ?? MessageAttachmentStorage() {
    desireEngine = DesireEngine(this.db);
    thoughtLifecycle = ThoughtLifecycleEngine(db: this.db);
    thoughtConsolidation = ThoughtConsolidationEngine(this.db);
    proactiveRhythm =
        ProactiveRhythmEngine(db: this.db, lifecycle: thoughtLifecycle);
    generationRunner = DurableGenerationRunner(
      db: this.db,
      client: this.client,
      secureConfig: this.secureConfig,
    );
    generationRecovery = DurableGenerationRecovery(
      db: this.db,
      runner: generationRunner,
    );
    ttsService = TtsService(db: this.db);
    ttsPlayback = TtsPlaybackQueue(
      service: ttsService,
      onStateChanged: (state) {
        ttsState = state;
        _safeNotify();
      },
    );
    perceptionEngine = PerceptionEngine(
      db: this.db,
      android: this.android,
      desire: desireEngine,
    );
    relationshipAssimilator =
        RelationshipAssimilator(db: this.db);
    memoryMaintenance = MemoryMaintenanceEngine(this.db);
    longMaintenance = LongRunningMaintenanceEngine(this.db);
    memoryExtractor = MemoryExtractor(
      db: this.db,
      client: this.client,
      desireEngine: desireEngine,
    );
  }

  final AppDatabase db;
  final DeepSeekClient client;
  final QwenVisionClient visionClient;
  final SecureConfig secureConfig;
  final AndroidBridge android;
  final MessageAttachmentStorage attachmentStorage;
  final bool externalRecoveryOrchestrator;
  late final DesireEngine desireEngine;
  late final ThoughtLifecycleEngine thoughtLifecycle;
  late final ThoughtConsolidationEngine thoughtConsolidation;
  late final ProactiveRhythmEngine proactiveRhythm;
  late final DurableGenerationRunner generationRunner;
  late final DurableGenerationRecovery generationRecovery;
  late final MemoryExtractor memoryExtractor;
  late final TtsService ttsService;
  late final TtsPlaybackQueue ttsPlayback;
  late final PerceptionEngine perceptionEngine;
  late final RelationshipAssimilator relationshipAssimilator;
  late final MemoryMaintenanceEngine memoryMaintenance;
  late final LongRunningMaintenanceEngine longMaintenance;
  final Uuid _uuid = Uuid();

  List<ChatMessage> messages = [];
  bool loading = true;
  bool sending = false;
  bool savingImage = false;
  bool analyzingImage = false;
  bool recoveringGeneration = false;
  bool cancellingGeneration = false;
  String streamingReasoning = '';
  String streamingContent = '';
  AgentToolActivity? agentActivity;
  String? error;
  DeepSeekModelProfile model = DeepSeekModelProfile.flash;
  ReasoningEffort effort = ReasoningEffort.high;
  bool nsfwActive = false;
  bool nsfwRouting = false;
  TtsQueueState ttsState = TtsQueueState.idle;
  bool _disposed = false;
  int _recoveryScheduleEpoch = 0;
  GenerationCancellationToken? _activeGenerationCancellation;
  String? _activeGenerationJobId;
  String? _activeGenerationAssistantMessageId;
  String _lastPetConversationState = '';
  bool _petGenerationActive = false;

  String? get activeGenerationAssistantMessageId =>
      _activeGenerationAssistantMessageId;

  bool get agentToolActive => agentActivity?.active ?? false;

  void _applyAgentToolActivity(AgentToolActivity activity) {
    agentActivity = activity;
    _safeNotify();
  }

  TtsPlaybackPhase ttsPhaseForMessage(String messageId) {
    if (ttsState.ownerId != messageId) return TtsPlaybackPhase.idle;
    return ttsState.phase;
  }

  TtsPlaybackPhase get activeGenerationTtsPhase {
    final messageId = _activeGenerationAssistantMessageId;
    if (messageId == null || ttsState.ownerId != messageId) {
      return TtsPlaybackPhase.idle;
    }
    if (messages.any((message) => message.id == messageId)) {
      return TtsPlaybackPhase.idle;
    }
    return ttsState.phase;
  }

  void _safeNotify() {
    if (_disposed) return;
    _publishPetConversationState();
    notifyListeners();
  }

  Future<void> _ignorePetStateSync(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // Pet expression is best-effort and must never block the chat UI.
    }
  }

  void _publishPetConversationState() {
    final generationPhase = !_petGenerationActive
        ? 'idle'
        : streamingContent.isNotEmpty
            ? 'answering'
            : cancellingGeneration
                ? 'cancelling'
                : 'thinking';
    final ttsPhase = switch (ttsState.phase) {
      TtsPlaybackPhase.synthesizing => 'synthesizing',
      TtsPlaybackPhase.playing => 'playing',
      TtsPlaybackPhase.idle => 'idle',
    };
    final stateKey = '$_petGenerationActive|$generationPhase|$ttsPhase';
    if (stateKey == _lastPetConversationState) return;
    _lastPetConversationState = stateKey;
    unawaited(
      _ignorePetStateSync(
        android.setPetConversationState(
          generationActive: _petGenerationActive,
          generationPhase: generationPhase,
          ttsPhase: ttsPhase,
        ),
      ),
    );
  }

  Future<void> initialize() async {
    try {
      await db.ensureReady();
      model = DeepSeekModelProfile.fromApiName(await db.getSetting('model'));
      effort = ReasoningEffort.fromApiName(await db.getSetting('reasoning_effort'));
      nsfwActive = (await db.getSetting('nsfw_active')) == '1';
      messages = await db.recentMessages(limit: 120);
      unawaited(attachmentStorage.cleanOldDrafts());
      unawaited(_pruneOrphanAttachmentFiles());
      loading = false;
      _safeNotify();

      if (!externalRecoveryOrchestrator) {
        unawaited(_runStartupMaintenanceSafely());
        unawaited(_scheduleGenerationRecovery());
        final unfinishedVision = await db.unfinishedVisionMessageId();
        if (unfinishedVision != null) {
          unawaited(_analyzeImageMessage(unfinishedVision));
        }
      }
    } catch (e) {
      loading = false;
      error = '聊天初始化失败：$e';
      _safeNotify();
    }
  }

  Future<void> _runStartupMaintenanceSafely() async {
    final tasks = <Future<void> Function()>[
      () async => thoughtConsolidation.maybeRun(),
      () async => relationshipAssimilator.assimilatePending(),
      () async => memoryMaintenance.maybeRun(),
      () async => longMaintenance.maybeRun(),
      () async => memoryExtractor.drainPendingSafely(),
    ];
    for (final task in tasks) {
      try {
        await task();
      } catch (e) {
        // Maintenance is deliberately best-effort. A maintenance fault must not
        // leave the user staring at an endless chat loading spinner.
        final text = e.toString();
        await db.setSetting(
          'last_chat_startup_maintenance_error',
          text.length <= 320 ? text : text.substring(0, 320),
        );
      }
    }
  }

  Future<void> _pruneOrphanAttachmentFiles() async {
    try {
      final attachments = await db.allMessageAttachments();
      await attachmentStorage.pruneUnreferencedFiles({
        for (final attachment in attachments) ...[
          attachment.originalPath,
          attachment.thumbnailPath,
        ],
      });
    } catch (_) {
      // File reconciliation is best-effort and must never block chat startup.
    }
  }

  Future<void> reload() async {
    messages = await db.recentMessages(limit: 120);
    _safeNotify();
  }

  Future<void> acknowledgeOverlayUnread() async {
    try {
      await android.clearOverlayUnread();
    } catch (_) {
      // Overlay unread state is cosmetic and must never block the chat UI.
    }
  }

  /// Refreshes messages written by another engine (native overlay/background).
  /// Returns true only when the visible tail actually changed.
  Future<bool> syncExternalMessages() async {
    if (_disposed || sending) return false;
    final latest = await db.recentMessages(limit: 120);
    final same = latest.length == messages.length &&
        (latest.isEmpty ||
            (messages.isNotEmpty &&
                latest.last.id == messages.last.id &&
                latest.last.content == messages.last.content &&
                latest.last.attachments.length == messages.last.attachments.length));
    if (same) return false;
    messages = latest;
    _safeNotify();
    return true;
  }

  Future<void> setModel(DeepSeekModelProfile next) async {
    model = next;
    await db.setSetting('model', next.apiName);
    _safeNotify();
  }

  Future<void> setEffort(ReasoningEffort next) async {
    effort = next;
    await db.setSetting('reasoning_effort', next.apiName);
    _safeNotify();
  }

  Future<void> setNsfwActive(bool next) async {
    if (sending || analyzingImage) return;
    nsfwActive = next;
    nsfwRouting = false;
    await db.setSetting('nsfw_active', next ? '1' : '0');
    await db.setSetting('nsfw_reference_active', '0');
    await db.setSetting('nsfw_manual_override', next ? 'on' : 'off');
    await db.setSetting('nsfw_route_source', next ? 'manual_pending_on' : 'manual_pending_off');
    _safeNotify();
  }

  Future<void> _refreshChatRoutingSettings() async {
    nsfwActive = (await db.getSetting('nsfw_active')) == '1';
  }

  void _applyNsfwRoute(NsfwRouteDecision decision) {
    nsfwActive = decision.active;
    nsfwRouting = false;
    _safeNotify();
  }

  Future<PreparedImageAttachment> prepareImage({
    required String sourcePath,
    required String source,
    String? mimeType,
  }) {
    return attachmentStorage.prepareImage(
      sourcePath: sourcePath,
      source: source,
      mimeType: mimeType,
    );
  }

  Future<bool> sendPreparedImage(
    PreparedImageAttachment draft, {
    String caption = '',
  }) async {
    if (sending || savingImage || analyzingImage) return false;
    error = null;
    savingImage = true;
    _safeNotify();
    MessageAttachment? committed;
    try {
      final deepSeekKey = await secureConfig.readApiKey();
      if (deepSeekKey == null || deepSeekKey.trim().isEmpty) {
        throw StateError('请先到“AI 与陪伴设置”填写 DeepSeek API Key。');
      }
      final visionKey = await secureConfig.readVisionApiKey();
      if (visionKey == null || visionKey.trim().isEmpty) {
        throw StateError('请先到“AI 与陪伴设置”填写千问视觉 API Key。');
      }
      if ((await db.getSetting('transfer_lock')) == '1') {
        throw StateError('她正在换到另一台设备，接管完成前先不能继续聊天。');
      }
      if ((await db.getSetting('active_brain')) == '0') {
        throw StateError('她现在在另一台设备上，请先把她接到这台设备。');
      }
      final messageId = _uuid.v4();
      committed = await attachmentStorage.commitDraft(
        draft,
        messageId: messageId,
      );
      final message = ChatMessage(
        id: messageId,
        role: 'user',
        content: caption.trim(),
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
        attachments: [committed],
        expectsReply: false,
      );
      await db.insertMessageWithAttachments(message, [committed]);
      messages = [...messages, message];
      _safeNotify();
      unawaited(_analyzeImageMessage(message.id));
      return true;
    } catch (exception) {
      if (committed != null) {
        try {
          await attachmentStorage.deleteAttachmentFiles(committed);
        } catch (_) {}
      } else {
        try {
          await attachmentStorage.discardDraft(draft);
        } catch (_) {}
      }
      error = '图片消息保存失败：$exception';
      return false;
    } finally {
      savingImage = false;
      _safeNotify();
    }
  }

  Future<void> retryImageVision(ChatMessage message) async {
    if (!message.isUser ||
        !message.hasAttachments ||
        sending ||
        savingImage ||
        analyzingImage) {
      return;
    }
    await _analyzeImageMessage(message.id);
  }

  Future<void> _analyzeImageMessage(String messageId) async {
    if (_disposed || analyzingImage || sending) return;
    final acquired = await db.tryAcquireLocalLease(
      'image_vision_lease',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return;
    final message = await db.messageById(messageId);
    if (message == null || !message.isUser || message.attachments.isEmpty) {
      await db.releaseLocalLease('image_vision_lease');
      return;
    }
    final attachment = message.attachments.firstWhere(
      (item) => item.isImage,
      orElse: () => message.attachments.first,
    );
    if (attachment.visionCompleted) {
      await db.releaseLocalLease('image_vision_lease');
      return;
    }

    analyzingImage = true;
    error = null;
    _safeNotify();
    var marked = false;
    try {
      final visionKey = await secureConfig.readVisionApiKey();
      if (visionKey == null || visionKey.trim().isEmpty) {
        throw StateError('请先到“AI 与陪伴设置”填写千问视觉 API Key。');
      }
      final deepSeekKey = await secureConfig.readApiKey();
      if (deepSeekKey == null || deepSeekKey.trim().isEmpty) {
        throw StateError('请先到“AI 与陪伴设置”填写 DeepSeek API Key。');
      }
      marked = await db.markAttachmentVisionAnalyzing(attachment.id);
      if (!marked) return;
      await _refreshChatRoutingSettings();
      messages = await db.recentMessages(limit: 160);
      _safeNotify();

      // The original remains local. Vision receives only the already-generated
      // 1000 px max-edge PNG thumbnail, which bounds upload size and removes EXIF data.
      final thumbnail = await attachmentStorage.fileFor(
        attachment.thumbnailPath,
      );
      final observation = await visionClient.observe(
        apiKey: visionKey,
        endpoint: await secureConfig.readVisionEndpoint(),
        model: await secureConfig.readVisionModel(),
        imageFile: thumbnail,
        caption: message.content,
      );
      await db.completeAttachmentVisionAndCreateGeneration(
        attachmentId: attachment.id,
        summary: observation.summary,
        visionModel: observation.model,
        assistantMessageId: _uuid.v4(),
        model: model.apiName,
        reasoningEffort: effort.apiName,
        thinking: true,
      );
      messages = await db.recentMessages(limit: 160);
    } catch (exception) {
      if (marked) {
        await db.failAttachmentVision(attachment.id, exception.toString());
      }
      messages = await db.recentMessages(limit: 160);
      error = '图片识别失败：$exception';
    } finally {
      analyzingImage = false;
      await db.releaseLocalLease('image_vision_lease');
      _safeNotify();
    }
    if (!_disposed && error == null) {
      await resumePendingGeneration();
    }
  }

  Future<void> discardPreparedImage(PreparedImageAttachment draft) async {
    await attachmentStorage.discardDraft(draft);
  }

  Future<bool> deleteAttachmentMessage(ChatMessage message) async {
    if (!message.isUser || !message.hasAttachments || sending || savingImage || analyzingImage) {
      return false;
    }
    final removed = await db.deleteAttachmentMessage(message.id);
    if (removed.isEmpty) return false;
    for (final attachment in removed) {
      try {
        await attachmentStorage.deleteAttachmentFiles(attachment);
      } catch (_) {}
    }
    messages = messages.where((item) => item.id != message.id).toList();
    _safeNotify();
    return true;
  }

  Future<void> sendText(String raw, {String? requestedMessageId}) async {
    final text = raw.trim();
    if (text.isEmpty || sending || analyzingImage) return;
    error = null;

    final stableMessageId = requestedMessageId?.trim();
    if (stableMessageId != null && stableMessageId.isNotEmpty) {
      final existing = await db.messageById(stableMessageId);
      if (existing != null) {
        // Native notification quick-reply may be redelivered after a Service or
        // FlutterEngine restart. The original user turn and durable generation
        // job are created atomically, so seeing this stable message id means
        // the first delivery already won. Never create a duplicate user turn.
        messages = await db.recentMessages(limit: 160);
        _safeNotify();
        unawaited(_scheduleGenerationRecovery());
        return;
      }
    }

    await ttsPlayback.stop();
    if ((await db.getSetting('transfer_lock')) == '1') {
      error = '她正在换到另一台设备，接管完成前先不能继续聊天。';
      _safeNotify();
      return;
    }
    if ((await db.getSetting('active_brain')) == '0') {
      error = '她现在在另一台设备上。请先到“更多”→“手机 / 平板接管”把她接到这台设备，再继续聊天。';
      _safeNotify();
      return;
    }
    final failedTurn = await db.failedGenerationNeedingAttention();
    if (failedTurn != null) {
      error = '上一轮回复需要你处理一下。请到“更多”→“权限与系统状态”→“长期运行诊断”选择重新尝试或放弃这一轮后再继续。';
      _safeNotify();
      return;
    }
    final apiKey = await secureConfig.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      error = '请先到“更多”→“AI 与陪伴设置”填写 DeepSeek API Key。';
      _safeNotify();
      return;
    }
    final blocking = await db.blockingGenerationJob();
    if (blocking != null) {
      error = '刚才那轮回复还在恢复，请等她接回来后再发送新消息。';
      _safeNotify();
      unawaited(_scheduleGenerationRecovery());
      return;
    }

    final chatLease = await db.tryAcquireLocalLease(
      'chat_turn_lease',
      holdFor: const Duration(minutes: 3),
    );
    if (!chatLease) {
      error = '另一处聊天窗口正在发送消息，请等她这一轮回复完成后再试。';
      _safeNotify();
      return;
    }

    sending = true;
    nsfwRouting = (await db.getSetting('nsfw_manual_override') ?? '').isEmpty;
    _petGenerationActive = true;
    recoveringGeneration = false;
    cancellingGeneration = false;
    streamingReasoning = '';
    streamingContent = '';
    agentActivity = null;
    final cancellation = GenerationCancellationToken();
    _activeGenerationCancellation = cancellation;
    _activeGenerationJobId = null;
    _safeNotify();

    var streamTts = false;
    var durableTurnCreated = false;
    try {
      if ((await db.getSetting('transfer_lock')) == '1') {
        throw StateError('她已经开始换到另一台设备，这轮发送已取消。');
      }
      if ((await db.getSetting('active_brain')) == '0') {
        throw StateError('她已经切换到另一台设备，这轮发送已取消。');
      }

      cancellation.throwIfCancelled();
      await _refreshChatRoutingSettings();
      final user = ChatMessage(
        id: stableMessageId != null && stableMessageId.isNotEmpty
            ? stableMessageId
            : _uuid.v4(),
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
      );
      final job = await db.createGenerationTurn(
        user: user,
        assistantMessageId: _uuid.v4(),
        model: model.apiName,
        reasoningEffort: effort.apiName,
        thinking: true,
      );
      durableTurnCreated = true;
      _activeGenerationJobId = job.id;
      _activeGenerationAssistantMessageId = job.assistantMessageId;
      cancellation.throwIfCancelled();
      messages = [...messages, user];
      _safeNotify();

      // The committed user turn + generation job are already crash-safe. These
      // enrichment steps are best-effort: if Android kills the process here,
      // recovery prioritizes producing the missing reply without duplicating
      // Desire pulses or other state mutations.
      await proactiveRhythm.captureUserResponse(user);
      cancellation.throwIfCancelled();
      await thoughtLifecycle.advance();
      cancellation.throwIfCancelled();
      await relationshipAssimilator.assimilatePending();
      cancellation.throwIfCancelled();
      await memoryMaintenance.maybeRun();
      cancellation.throwIfCancelled();
      await desireEngine.applyExperience({
        DriveKey.attachment: 0.018,
        DriveKey.social: 0.008,
      }, baselineLearning: 0.0015);
      cancellation.throwIfCancelled();
      await perceptionEngine.capture();
      cancellation.throwIfCancelled();
      await desireEngine.tick(pulses: {
        DriveKey.attachment: 0.025,
        DriveKey.reflection: 0.012,
      });
      cancellation.throwIfCancelled();

      final ttsEnabled = (await db.getSetting('tts_enabled')) != '0';
      final autoTts = ttsEnabled && (await db.getSetting('auto_tts')) != '0';
      streamTts = autoTts &&
          (await db.getSetting('tts_streaming_enabled')) != '0';
      if (streamTts) {
        try {
          await ttsPlayback.beginStream(
            manual: false,
            ownerId: job.assistantMessageId,
          );
        } catch (_) {
          streamTts = false;
        }
      }

      // Best-effort enrichment can take a while on a large local database.
      // Refresh ownership immediately before opening the network stream so an
      // expired lease cannot let another engine start a competing chat turn.
      cancellation.throwIfCancelled();
      final stillOwnsTurn = await db.renewLocalLease(
        'chat_turn_lease',
        holdFor: const Duration(minutes: 3),
      );
      if (!stillOwnsTurn) {
        await db.suspendGenerationJob(
          job.id,
          reason: 'chat_turn_lease_lost_before_stream',
        );
        throw StateError('这轮回复的处理已经转到恢复流程，会安全地继续。');
      }

      final result = await generationRunner.run(
        job,
        cancellationToken: cancellation,
        onNsfwRoute: _applyNsfwRoute,
        onAgentToolActivity: _applyAgentToolActivity,
        onDelta: (delta) {
          if (cancellation.isCancelled) return;
          if (delta.reasoning.isNotEmpty) {
            streamingReasoning += delta.reasoning;
          }
          if (delta.content.isNotEmpty) {
            streamingContent += delta.content;
            if (streamTts) ttsPlayback.addDelta(delta.content);
          }
          _safeNotify();
        },
      );

      if (result.completed) {
        messages = [...messages, result.assistant!];
        _petGenerationActive = false;
        _safeNotify();
        if (streamTts) {
          ttsPlayback.endStream();
        } else if (autoTts) {
          unawaited(
            ttsPlayback.playText(
              result.assistant!.content,
              manual: false,
              ownerId: result.assistant!.id,
            ),
          );
        }
        await memoryExtractor.extractFromTurn(
          user: user,
          assistant: result.assistant!,
        );
      } else if (result.status == 'cancelled_by_user') {
        await ttsPlayback.stop();
        messages = await db.recentMessages(limit: 120);
        error = null;
      } else if (result.retryScheduled) {
        await ttsPlayback.stop();
        error = '网络/API 中断。这条消息已经安全保存在本机，恢复连接后会自动继续。';
      } else if (result.status == 'suspended') {
        await ttsPlayback.stop();
        error = '这轮回复已安全暂停；她回到当前设备后会继续。';
      } else {
        await ttsPlayback.stop();
        error = result.error?.toString() ?? '这一轮生成失败。';
      }
    } on GenerationCancelledByUserException {
      await ttsPlayback.stop();
      final jobId = _activeGenerationJobId;
      if (jobId != null) {
        await db.cancelGenerationJobByUser(jobId);
        messages = await db.recentMessages(limit: 120);
      }
      error = null;
    } catch (e) {
      await ttsPlayback.stop();
      error = durableTurnCreated
          ? '这条消息已经保存，回复会在连接恢复后继续。\n$e'
          : e.toString();
    } finally {
      sending = false;
      nsfwRouting = false;
      _petGenerationActive = false;
      recoveringGeneration = false;
      cancellingGeneration = false;
      streamingReasoning = '';
      streamingContent = '';
      agentActivity = null;
      if (identical(_activeGenerationCancellation, cancellation)) {
        _activeGenerationCancellation = null;
        _activeGenerationJobId = null;
        _activeGenerationAssistantMessageId = null;
      }
      await db.releaseLocalLease('chat_turn_lease');
      _safeNotify();
      if (durableTurnCreated && !cancellation.isCancelled) {
        unawaited(_scheduleGenerationRecovery());
      }
    }
  }

  Future<void> resumePendingGeneration() async {
    if (_disposed || sending) return;
    if (!await db.brainWorkAllowed()) return;
    final job = await db.nextRecoverableGenerationJob();
    if (job == null) {
      unawaited(_scheduleGenerationRecovery());
      return;
    }
    final acquired = await db.tryAcquireLocalLease(
      'chat_turn_lease',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) {
      unawaited(_scheduleGenerationRecovery(extraDelay: const Duration(seconds: 4)));
      return;
    }

    sending = true;
    nsfwRouting = (await db.getSetting('nsfw_manual_override') ?? '').isEmpty;
    _petGenerationActive = true;
    recoveringGeneration = true;
    cancellingGeneration = false;
    streamingReasoning = '';
    streamingContent = '';
    agentActivity = null;
    error = null;
    final cancellation = GenerationCancellationToken();
    _activeGenerationCancellation = cancellation;
    _activeGenerationJobId = job.id;
    _activeGenerationAssistantMessageId = job.assistantMessageId;
    _safeNotify();
    try {
      final result = await generationRunner.run(
        job,
        cancellationToken: cancellation,
        onNsfwRoute: _applyNsfwRoute,
        onAgentToolActivity: _applyAgentToolActivity,
        onDelta: (delta) {
          if (cancellation.isCancelled) return;
          if (delta.reasoning.isNotEmpty) {
            streamingReasoning += delta.reasoning;
          }
          if (delta.content.isNotEmpty) streamingContent += delta.content;
          _safeNotify();
        },
      );
      if (result.completed) {
        messages = await db.recentMessages(limit: 120);
        _petGenerationActive = false;
        _safeNotify();
        await db.setSetting('last_generation_recovery_error', '');
        final recoveredUser = await db.messageById(job.userMessageId);
        if (recoveredUser != null) {
          await memoryExtractor.extractFromTurn(
            user: recoveredUser,
            assistant: result.assistant!,
          );
        }
      } else if (result.status == 'cancelled_by_user') {
        await ttsPlayback.stop();
        messages = await db.recentMessages(limit: 120);
        error = null;
      } else if (result.retryScheduled) {
        error = '上一轮回复恢复时网络仍不可用，已经继续保留重试任务。';
      } else if (result.status != 'suspended') {
        final raw = result.error?.toString() ?? 'generation_recovery_failed';
        error = raw;
        await db.setSetting(
          'last_generation_recovery_error',
          raw.length <= 320 ? raw : raw.substring(0, 320),
        );
      }
    } finally {
      sending = false;
      nsfwRouting = false;
      _petGenerationActive = false;
      recoveringGeneration = false;
      cancellingGeneration = false;
      streamingReasoning = '';
      streamingContent = '';
      agentActivity = null;
      if (identical(_activeGenerationCancellation, cancellation)) {
        _activeGenerationCancellation = null;
        _activeGenerationJobId = null;
        _activeGenerationAssistantMessageId = null;
      }
      await db.releaseLocalLease('chat_turn_lease');
      _safeNotify();
      if (!cancellation.isCancelled) {
        unawaited(_scheduleGenerationRecovery());
      }
    }
  }

  Future<void> _scheduleGenerationRecovery({Duration extraDelay = Duration.zero}) async {
    if (_disposed || externalRecoveryOrchestrator) return;
    final epoch = ++_recoveryScheduleEpoch;
    final delay = await db.nextGenerationRecoveryDelay();
    if (delay == null || _disposed) return;
    var bounded = delay;
    if (bounded > const Duration(minutes: 2)) bounded = const Duration(minutes: 2);
    bounded += extraDelay;
    if (bounded < const Duration(milliseconds: 500)) {
      bounded = const Duration(milliseconds: 500);
    }
    await Future<void>.delayed(bounded);
    if (_disposed || epoch != _recoveryScheduleEpoch) return;
    await resumePendingGeneration();
  }

  /// Stops the current reply as one operation: model stream, durable recovery,
  /// streaming UI, and speech. The database transition wins against late
  /// tokens through the existing run-token fence.
  Future<void> cancelCurrentGeneration() async {
    if (_disposed || cancellingGeneration) return;
    cancellingGeneration = true;
    _petGenerationActive = false;
    error = null;
    _recoveryScheduleEpoch++;
    final token = _activeGenerationCancellation;
    token?.cancel();
    streamingReasoning = '';
    streamingContent = '';
    agentActivity = null;
    _safeNotify();

    await ttsPlayback.stop();
    final jobId =
        _activeGenerationJobId ?? (await db.blockingGenerationJob())?.id;
    if (jobId != null) {
      await db.cancelGenerationJobByUser(jobId);
      messages = await db.recentMessages(limit: 120);
    }

    cancellingGeneration = false;
    _safeNotify();
  }

  Future<void> speakMessage(ChatMessage message) async {
    if (!message.isAssistant || message.content.trim().isEmpty) return;
    await ttsPlayback.playText(
      message.content,
      manual: true,
      ownerId: message.id,
    );
  }

  Future<void> stopSpeech() => ttsPlayback.stop();

  Future<void> onOverlayOpened() async {
    final policy = ProactiveTtsPolicy.fromSetting(
      await db.getSetting('proactive_tts_policy'),
    );
    if (policy != ProactiveTtsPolicy.whenOverlayOpened) return;
    if ((await db.getSetting('tts_enabled')) == '0') return;

    ChatMessage? latest;
    for (final message in messages.reversed) {
      if (message.isAssistant && message.isProactive) {
        latest = message;
        break;
      }
    }
    if (latest == null) return;
    final lastSpoken = await db.getSetting('last_proactive_spoken_message_id');
    if (lastSpoken == latest.id) return;
    await db.setSetting('last_proactive_spoken_message_id', latest.id);
    await ttsPlayback.playText(
      latest.content,
      manual: true,
      ownerId: latest.id,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _recoveryScheduleEpoch++;
    _activeGenerationCancellation?.cancel();
    unawaited(ttsPlayback.stop());
    unawaited(
      _ignorePetStateSync(
        android.setPetConversationState(
          generationActive: false,
          generationPhase: 'idle',
          ttsPhase: 'idle',
        ),
      ),
    );
    visionClient.close();
    client.close();
    super.dispose();
  }
}
