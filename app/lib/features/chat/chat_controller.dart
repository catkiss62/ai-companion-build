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
import '../../core/diagnostics/attachment_pipeline_telemetry.dart';
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
    err