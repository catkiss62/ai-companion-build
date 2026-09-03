import 'dart:async';
import 'dart:io';

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
import '../../core/diagnostics/visible_reasoning_language_telemetry.dart';
import '../../core/diagnostics/provider_health.dart';
import '../../core/desire/desire_core_policy.dart';
import '../../core/desire/desire_engine.dart';
import '../../core/desire/proactive_rhythm_engine.dart';
import '../../core/desire/thought_consolidation_engine.dart';
import '../../core/desire/thought_lifecycle_engine.dart';
import '../../core/emotion/emotion_contract.dart';
import '../../core/maintenance/long_running_maintenance_engine.dart';
import '../../core/integration/moe_shadow_coordinator.dart';
import '../../core/memory/memory_maintenance_engine.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/message_attachment.dart';
import '../../core/models/generation_job.dart';
import '../../core/models/desire_state.dart';
import '../../core/perception/perception_engine.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/phone/album_perceptual_hash.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/presentation/generation_presentation_policy.dart';
import '../../core/relationship/relationship_assimilator.dart';
import '../../core/storage/secure_config.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/storage/companion_album_storage.dart';
import '../../core/tts/emotion_sound_service.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../core/tts/tts_policy.dart';
import '../../core/tts/tts_provider.dart';
import '../../core/tts/tts_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    AppDatabase? db,
    DeepSeekClient? client,
    QwenVisionClient? visionClient,
    SecureConfig? secureConfig,
    AndroidBridge? android,
    MessageAttachmentStorage? attachmentStorage,
    EmotionSoundService? emotionSoundService,
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
    emotionSounds =
        emotionSoundService ?? EmotionSoundService(db: this.db);
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
  late final EmotionSoundService emotionSounds;
  late final TtsPlaybackQueue ttsPlayback;
  late final PerceptionEngine perceptionEngine;
  late final RelationshipAssimilator relationshipAssimilator;
  late final MemoryMaintenanceEngine memoryMaintenance;
  late final LongRunningMaintenanceEngine longMaintenance;
  final Uuid _uuid = Uuid();

  List<ChatMessage> messages = [];
  List<GenerationInterruption> generationInterruptions = [];
  bool loading = true;
  bool sending = false;
  bool externalGenerationActive = false;
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
  String? _externalGenerationAssistantMessageId;
  String _lastPetConversationState = '';
  bool _petGenerationActive = false;

  String? get activeGenerationAssistantMessageId =>
      _activeGenerationAssistantMessageId ??
      _externalGenerationAssistantMessageId;

  bool get generationActive => sending || externalGenerationActive;

  bool get showGenerationDraft => GenerationPresentationPolicy.showDraft(
        generationActive: generationActive,
        assistantMessageId: activeGenerationAssistantMessageId,
        committedMessageIds: messages.map((message) => message.id),
      );

  List<ChatTimelineItem> get timelineItems {
    final items = <ChatTimelineItem>[
      for (final message in messages) ChatTimelineItem.message(message),
      for (final marker in generationInterruptions)
        if (messages.isEmpty || !marker.createdAt.isBefore(messages.first.createdAt))
        ChatTimelineItem.interruption(marker),
    ];
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

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

  Future<void> _stopTurnAudio() async {
    await Future.wait<void>([
      ttsPlayback.stop(),
      emotionSounds.stop(),
    ]);
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
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      unawaited(attachmentStorage.cleanOldDrafts());
      unawaited(_pruneOrphanAttachmentFiles());
      unawaited(
        MoeShadowCoordinator(db)
            .reconcileRecentCommittedTurns()
            .catchError((_) {}),
      );
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
    generationInterruptions =
        await db.recentGenerationInterruptions(limit: 20);
    _safeNotify();
  }

  Future<void> acknowledgeOverlayUnread() async {
    try {
      await android.clearOverlayUnread();
      await android.acknowledgeCompanionNotifications(
        reason: 'full_chat_visible',
      );
    } catch (_) {
      // Unread/notification state is cosmetic and must never block chat UI.
    }
  }

  Future<void> _incrementOverlayUnread() async {
    try {
      await android.incrementOverlayUnread();
    } catch (_) {
      // The durable assistant commit is authoritative; badge delivery is
      // cosmetic and must never turn a completed reply into an error.
    }
  }

  /// Refreshes messages written by another engine (native overlay/background).
  /// Returns true only when the visible tail actually changed.
  Future<bool> syncExternalMessages() async {
    if (_disposed) return false;
    final job = await db.blockingGenerationJob() ??
        await db.failedGenerationNeedingAttention();
    var runtimeChanged = false;
    if (!sending) {
      final nextActive = job != null;
      final nextReasoning = job?.partialReasoning ?? '';
      // Durable checkpoints may already contain the provider candidate body.
      // Ordinary chat must not expose it before the guarded final commit; the
      // app-local typewriter will present the single approved body afterwards.
      const nextContent = '';
      final nextAssistantId = job?.assistantMessageId;
      final statusText = nextActive
          ? (await db.getSetting('agent_tool_runtime_status_text') ?? '')
          : '';
      runtimeChanged = externalGenerationActive != nextActive ||
          streamingReasoning != nextReasoning ||
          streamingContent != nextContent ||
          _externalGenerationAssistantMessageId != nextAssistantId ||
          (agentActivity?.text ?? '') != statusText;
      externalGenerationActive = nextActive;
      streamingReasoning = nextReasoning;
      streamingContent = nextContent;
      _externalGenerationAssistantMessageId = nextAssistantId;
      agentActivity = statusText.isEmpty
          ? null
          : AgentToolActivity(
              toolId: 'shared_runtime',
              status: AgentToolStatus.running,
              text: statusText,
            );
    }
    final latest = await db.recentMessages(limit: 120);
    final interruptions = await db.recentGenerationInterruptions(limit: 20);
    final sameMessages = latest.length == messages.length &&
        (latest.isEmpty ||
            (messages.isNotEmpty &&
                latest.last.id == messages.last.id &&
                latest.last.content == messages.last.content &&
                latest.last.attachments.length == messages.last.attachments.length));
    final sameInterruptions = interruptions.length == generationInterruptions.length &&
        (interruptions.isEmpty ||
            (generationInterruptions.isNotEmpty &&
                interruptions.last.jobId == generationInterruptions.last.jobId &&
                interruptions.last.createdAt == generationInterruptions.last.createdAt));
    if (sameMessages && sameInterruptions && !runtimeChanged) return false;
    if (!sending) messages = latest;
    generationInterruptions = interruptions;
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
    if (generationActive || analyzingImage) return;
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
      holdFor: const Duration(seconds: 30),
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
    var chatLeaseHeld = false;
    var visionRecorded = false;
    final visionStarted = DateTime.now();
    GenerationJob? trustedGeneration;
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
      final albumEnabled =
          (await db.getSetting('simulated_phone_enabled')) != '0';
      final observation = await visionClient.observe(
        apiKey: visionKey,
        endpoint: await secureConfig.readVisionEndpoint(),
        model: await secureConfig.readVisionModel(),
        imageFile: thumbnail,
        caption: message.content,
        assessForAlbum: albumEnabled,
        albumPreferenceHint:
            albumEnabled ? await db.companionAlbumPreferenceHint() : '',
      );
      await CompanionAlbumStorage().requireContentSha256(
        thumbnail,
        observation.inputContentSha256,
      );
      await db.recordProviderHealthEvent(ProviderHealthEvent(
        lane: 'vision',
        context: 'chat_image',
        primaryProvider: 'qwen_vision',
        primaryOutcome: 'success',
        finalProvider: 'qwen_vision',
        finalOutcome: 'success',
        resultCount: 1,
        latencyBucket:
            ProviderHealth.latencyBucket(DateTime.now().difference(visionStarted)),
      ));
      visionRecorded = true;
      chatLeaseHeld = await db.tryAcquireLocalLease(
        'chat_turn_lease',
        holdFor: const Duration(seconds: 30),
      );
      if (!chatLeaseHeld) {
        throw StateError('另一处聊天窗口正在发送消息，请稍后重试这张图片。');
      }
      trustedGeneration = await db.completeAttachmentVisionAndCreateGeneration(
        attachmentId: attachment.id,
        summary: observation.summary,
        visionModel: observation.model,
        assistantMessageId: _uuid.v4(),
        model: model.apiName,
        reasoningEffort: effort.apiName,
        thinking: true,
      );
      if (albumEnabled) {
        try {
          await _recordUserImageAlbumDecision(
            message: message,
            attachment: attachment,
            thumbnail: thumbnail,
            observation: observation,
          );
        } catch (albumError) {
          await db.recordProviderHealthEvent(ProviderHealthEvent(
            lane: 'album',
            context: 'user_image_album',
            primaryProvider: 'local_album',
            primaryOutcome: 'failed',
            primaryErrorCategory: ProviderHealth.errorCategory(albumError),
            finalOutcome: 'failed',
          ));
          await db.setSetting(
            'companion_album_last_error',
            albumError.toString().length <= 360
                ? albumError.toString()
                : albumError.toString().substring(0, 360),
          );
        }
      }
    } catch (exception) {
      if (!visionRecorded) {
        await db.recordProviderHealthEvent(ProviderHealthEvent(
          lane: 'vision',
          context: 'chat_image',
          primaryProvider: 'qwen_vision',
          primaryOutcome: marked ? 'failed' : 'not_called',
          primaryErrorCategory: ProviderHealth.errorCategory(exception),
          finalOutcome: 'failed',
          latencyBucket:
              ProviderHealth.latencyBucket(DateTime.now().difference(visionStarted)),
        ));
      }
      if (marked && trustedGeneration == null) {
        await db.failAttachmentVision(attachment.id, exception.toString());
      }
      messages = await db.recentMessages(limit: 160);
      error = '图片识别失败：$exception';
    } finally {
      analyzingImage = false;
      await db.releaseLocalLease('image_vision_lease');
      if (trustedGeneration == null && chatLeaseHeld) {
        await db.releaseLocalLease('chat_turn_lease');
        chatLeaseHeld = false;
      }
      _safeNotify();
    }
    final generation = trustedGeneration;
    if (generation != null && chatLeaseHeld) {
      if (_disposed) {
        await db.releaseLocalLease('chat_turn_lease');
      } else {
        await _runTrustedCurrentProcessGeneration(
          generation,
          leaseAlreadyHeld: true,
        );
      }
    }
  }

  Future<void> _recordUserImageAlbumDecision({
    required ChatMessage message,
    required MessageAttachment attachment,
    required File thumbnail,
    required QwenVisionObservation observation,
  }) async {
    final started = DateTime.now();
    final candidateId = _uuid.v4();
    final begun = await db.beginCompanionAlbumCandidate(
      id: candidateId,
      sourceKind: 'user_message',
      sourceId: attachment.id,
      sourceUrl: '',
      sourceDomain: '',
      title: message.content.trim().isEmpty ? '你发来的图片' : message.content,
      createdAt: DateTime.now(),
    );
    if (!begun) return;
    String path = '';
    String contentSha = '';
    String perceptualHash = '';
    if (observation.albumSave) {
      final stored = await CompanionAlbumStorage().saveThumbnail(
        id: candidateId,
        source: thumbnail,
        expectedContentSha256: observation.inputContentSha256,
      );
      path = stored.relativePath;
      contentSha = stored.contentSha256;
      perceptualHash = await AlbumPerceptualHash.fromFile(thumbnail);
    }
    final completed = await db.completeCompanionAlbumCandidate(
      id: candidateId,
      save: observation.albumSave,
      visionSummary: observation.albumSave ? observation.summary : '',
      visionModel: observation.model,
      aiReason: observation.albumReason,
      category: observation.albumCategory,
      thumbnailPath: path,
      contentSha256: contentSha,
      perceptualHash: perceptualHash,
      visualFingerprint: observation.aestheticTags.join('|'),
      width: attachment.width,
      height: attachment.height,
      recognizedAt: DateTime.now(),
    );
    if (!completed && path.isNotEmpty) {
      await CompanionAlbumStorage().deleteThumbnail(path);
    }
    final outcome = observation.albumAdultContent
        ? 'adult_rejected'
        : await db.companionAlbumCandidateOutcomeCategory(candidateId);
    await db.recordProviderHealthEvent(ProviderHealthEvent(
      lane: 'album',
      context: 'user_image_album',
      primaryProvider: 'local_album',
      primaryOutcome: outcome,
      finalProvider: completed && observation.albumSave ? 'local_album' : 'none',
      finalOutcome: outcome,
      resultCount: completed && observation.albumSave ? 1 : 0,
      latencyBucket:
          ProviderHealth.latencyBucket(DateTime.now().difference(started)),
    ));
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
    if (text.isEmpty || generationActive || analyzingImage) return;
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

    await _stopTurnAudio();
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
      holdFor: const Duration(seconds: 30),
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
      await perceptionEngine.capture();
      cancellation.throwIfCancelled();
      await desireEngine.tick(
        pulses: DesireCorePolicy.ordinaryConversationPulses,
      );
      cancellation.throwIfCancelled();

      await _executeCurrentProcessGeneration(
        job: job,
        user: user,
        cancellation: cancellation,
      );
    } on GenerationCancelledByUserException {
      await _stopTurnAudio();
      final jobId = _activeGenerationJobId;
      if (jobId != null) {
        await db.cancelGenerationJobByUser(jobId);
        messages = await db.recentMessages(limit: 120);
      }
      error = null;
    } catch (e) {
      await _stopTurnAudio();
      final jobId = _activeGenerationJobId;
      if (durableTurnCreated && jobId != null) {
        // Once the user turn is durable, an incidental enrichment, lease or
        // transport exception must not masquerade as the user's Stop action.
        // Keep the message and hand the same job to recovery.
        await db.deferGenerationJob(
          jobId,
          delay: const Duration(seconds: 3),
          reason: 'current_process_exception',
        );
        messages = await db.recentMessages(limit: 120);
        generationInterruptions =
            await db.recentGenerationInterruptions(limit: 20);
        error = '这一轮没有被删除，已经转入自动恢复。';
      } else {
        error = e.toString();
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
      if (durableTurnCreated && !cancellation.isCancelled) {
        unawaited(_scheduleGenerationRecovery());
      }
    }
  }

  Future<void> _executeCurrentProcessGeneration({
    required GenerationJob job,
    required ChatMessage user,
    required GenerationCancellationToken cancellation,
  }) async {
    var streamTts = false;
    var emotionCueStarted = false;
    var emotionLeadIn = Future<void>.value();
    Completer<void>? streamLeadIn;

    Future<void> startEmotionCue(String emotionKey) {
      if (emotionCueStarted) return emotionLeadIn;
      emotionCueStarted = true;
      final visual = ChatVisualResolver.resolveEmotionKey(emotionKey);
      emotionLeadIn = emotionSounds.play(visual).then<void>((_) {});
      final gate = streamLeadIn;
      if (gate != null && !gate.isCompleted) {
        gate.complete(emotionLeadIn);
      }
      return emotionLeadIn;
    }

    void releaseStreamLeadIn() {
      final gate = streamLeadIn;
      if (gate != null && !gate.isCompleted) gate.complete();
    }

    final ttsEnabled = (await db.getSetting('tts_enabled')) != '0';
    final autoTts = ttsEnabled && (await db.getSetting('auto_tts')) != '0';
    streamTts = autoTts &&
        (await db.getSetting('tts_streaming_enabled')) != '0';
    if (streamTts) {
      streamLeadIn = Completer<void>();
      try {
        await ttsPlayback.beginStream(
          manual: false,
          ownerId: job.assistantMessageId,
          leadIn: streamLeadIn!.future,
        );
      } catch (_) {
        releaseStreamLeadIn();
        streamTts = false;
      }
    }

    // Best-effort enrichment can take a while on a large local database.
    // Refresh ownership immediately before opening the network stream so an
    // expired lease cannot let another engine start a competing chat turn.
    cancellation.throwIfCancelled();
    final stillOwnsTurn = await db.renewLocalLease(
      'chat_turn_lease',
      holdFor: const Duration(seconds: 30),
    );
    if (!stillOwnsTurn) {
      await db.suspendGenerationJob(
        job.id,
        reason: 'chat_turn_lease_lost_before_stream',
      );
      throw StateError('这轮回复的处理已经转到恢复流程，会安全地继续。');
    }

    var reasoningPresentationNoted = false;
    final result = await generationRunner.run(
      job,
      cancellationToken: cancellation,
      onNsfwRoute: _applyNsfwRoute,
      onAgentToolActivity: _applyAgentToolActivity,
      onEmotionCue: startEmotionCue,
      onDelta: (delta) {
        if (cancellation.isCancelled) return;
        if (delta.reasoning.isNotEmpty) {
          streamingReasoning += delta.reasoning;
          if (!reasoningPresentationNoted) {
            reasoningPresentationNoted = true;
            unawaited(
              VisibleReasoningLanguageTelemetry.noteUiPresentation(db),
            );
          }
        }
        if (delta.content.isNotEmpty) {
          // A valid leading emotion envelope is announced before this visible
          // delta. If the provider omitted it, never hold speech indefinitely.
          if (streamTts && !emotionCueStarted) releaseStreamLeadIn();
          streamingContent += delta.content;
          if (streamTts) ttsPlayback.addDelta(delta.content);
        }
        _safeNotify();
      },
    );

    if (result.completed) {
      messages = [...messages, result.assistant!];
      await _incrementOverlayUnread();
      _petGenerationActive = false;
      _safeNotify();
      if (streamTts) {
        releaseStreamLeadIn();
        // Ordinary visible body deltas are buffered until commit. Preserve the
        // optional streaming-TTS setting by feeding the approved body once.
        ttsPlayback.addDelta(result.assistant!.content);
        ttsPlayback.endStream();
      } else {
        final leadIn = emotionCueStarted
            ? emotionLeadIn
            : startEmotionCue(result.assistant!.emotionKey);
        if (autoTts) {
          unawaited(
            ttsPlayback.playText(
              result.assistant!.content,
              manual: false,
              ownerId: result.assistant!.id,
              emotion: _ttsEmotionCue(result.assistant!),
              leadIn: leadIn,
            ),
          );
        }
      }
      await memoryExtractor.extractFromTurn(
        user: user,
        assistant: result.assistant!,
        specialStyleTrialId: result.specialStyleTrialId,
        specialStyleKey: result.specialStyleKey,
      );
    } else if (result.status == 'cancelled_by_user') {
      await _stopTurnAudio();
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      error = null;
    } else if (result.status == 'interrupted') {
      await _stopTurnAudio();
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      error = null;
    } else if (result.retryScheduled) {
      await _stopTurnAudio();
      error = '网络/API 中断。这条消息已经安全保存在本机，恢复连接后会自动继续。';
    } else if (result.status == 'suspended') {
      await _stopTurnAudio();
      error = '这轮回复已安全暂停；她回到当前设备后会继续。';
    } else {
      await _stopTurnAudio();
      error = result.error?.toString() ?? '这一轮生成失败。';
    }
  }

  Future<void> _runTrustedCurrentProcessGeneration(
    GenerationJob job, {
    required bool leaseAlreadyHeld,
  }) async {
    if (_disposed) {
      if (leaseAlreadyHeld) await db.releaseLocalLease('chat_turn_lease');
      return;
    }
    if (!await db.brainWorkAllowed()) {
      await db.suspendGenerationJob(
        job.id,
        reason: 'active_brain_unavailable',
      );
      if (leaseAlreadyHeld) await db.releaseLocalLease('chat_turn_lease');
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      _safeNotify();
      return;
    }

    var ownsLease = leaseAlreadyHeld;
    if (!ownsLease) {
      ownsLease = await db.tryAcquireLocalLease(
        'chat_turn_lease',
        holdFor: const Duration(seconds: 30),
      );
    }
    if (!ownsLease) {
      await db.suspendGenerationJob(
        job.id,
        reason: 'chat_turn_lease_busy',
      );
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      error = '图片识别已经完成；另一处聊天窗口暂时占用回复通道，本轮会自动继续。';
      _safeNotify();
      return;
    }

    final user = await db.messageById(job.userMessageId);
    if (user == null || !user.isUser) {
      await db.cancelGenerationJobByUser(job.id);
      await db.releaseLocalLease('chat_turn_lease');
      return;
    }

    messages = await db.recentMessages(limit: 160);
    sending = true;
    nsfwRouting = (await db.getSetting('nsfw_manual_override') ?? '').isEmpty;
    _petGenerationActive = true;
    recoveringGeneration = false;
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
      await _executeCurrentProcessGeneration(
        job: job,
        user: user,
        cancellation: cancellation,
      );
    } on GenerationCancelledByUserException {
      await _stopTurnAudio();
      await db.cancelGenerationJobByUser(job.id);
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      error = null;
    } catch (_) {
      await _stopTurnAudio();
      await db.deferGenerationJob(
        job.id,
        delay: const Duration(seconds: 3),
        reason: 'trusted_process_exception',
      );
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
      error = '这一轮没有被删除，已经转入自动恢复。';
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

  Future<void> resumePendingGeneration() async {
    if (_disposed || sending) return;
    if (!await db.brainWorkAllowed()) return;

    recoveringGeneration = true;
    cancellingGeneration = false;
    error = null;
    _safeNotify();
    try {
      final finalized = await generationRecovery.recoverOne();
      if (finalized) {
        await _stopTurnAudio();
        messages = await db.recentMessages(limit: 120);
        generationInterruptions =
            await db.recentGenerationInterruptions(limit: 20);
        externalGenerationActive = false;
        _externalGenerationAssistantMessageId = null;
        streamingReasoning = '';
        streamingContent = '';
        agentActivity = null;
        error = null;
      }
    } catch (exception) {
      final raw = exception.toString();
      await db.setSetting(
        'last_generation_recovery_error',
        raw.length <= 320 ? raw : raw.substring(0, 320),
      );
      error = '上次中断的回复还没有清理完成：$raw';
    } finally {
      recoveringGeneration = false;
      _petGenerationActive = false;
      _safeNotify();
      if (await db.nextGenerationRecoveryDelay() != null) {
        unawaited(
          _scheduleGenerationRecovery(
            extraDelay: const Duration(seconds: 4),
          ),
        );
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

    await _stopTurnAudio();
    final jobId = _activeGenerationJobId ??
        (await db.blockingGenerationJob())?.id ??
        (await db.failedGenerationNeedingAttention())?.id;
    if (jobId != null) {
      await db.cancelGenerationJobByUser(jobId);
      messages = await db.recentMessages(limit: 120);
      generationInterruptions =
          await db.recentGenerationInterruptions(limit: 20);
    }

    externalGenerationActive = false;
    _externalGenerationAssistantMessageId = null;
    cancellingGeneration = false;
    _safeNotify();
  }

  TtsEmotionCue? _ttsEmotionCue(ChatMessage message) {
    if (message.emotionKey.isEmpty) return null;
    return TtsEmotionCue(
      key: message.emotionKey,
      label: message.emotionLabel,
      confidence: message.emotionConfidence,
      source: message.emotionSource,
    );
  }

  Future<void> speakMessage(ChatMessage message) async {
    if (!message.isAssistant || message.content.trim().isEmpty) return;
    await ttsPlayback.playText(
      message.content,
      manual: true,
      ownerId: message.id,
      emotion: _ttsEmotionCue(message),
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
      emotion: _ttsEmotionCue(latest),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _recoveryScheduleEpoch++;
    // Closing/rebuilding a chat surface is lifecycle, not the user's Stop
    // action. Closing the provider client below will hand an unfinished
    // durable turn to retry without withdrawing the user's message.
    unawaited(ttsPlayback.stop());
    unawaited(emotionSounds.stop());
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

class ChatTimelineItem {
  const ChatTimelineItem._({
    required this.createdAt,
    this.message,
    this.interruption,
  });

  factory ChatTimelineItem.message(ChatMessage message) => ChatTimelineItem._(
        createdAt: message.createdAt,
        message: message,
      );

  factory ChatTimelineItem.interruption(GenerationInterruption interruption) =>
      ChatTimelineItem._(
        createdAt: interruption.createdAt,
        interruption: interruption,
      );

  final DateTime createdAt;
  final ChatMessage? message;
  final GenerationInterruption? interruption;

  bool get isInterruption => interruption != null;
}
