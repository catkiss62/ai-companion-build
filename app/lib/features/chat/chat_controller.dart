import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/deepseek_client.dart';
import '../../core/ai/companion_voice_protocol.dart';
import '../../core/ai/durable_generation_recovery.dart';
import '../../core/ai/durable_generation_runner.dart';
import '../../core/ai/memory_extractor.dart';
import '../../core/ai/model_profile.dart';
import '../../core/database/app_database.dart';
import '../../core/desire/desire_engine.dart';
import '../../core/desire/proactive_rhythm_engine.dart';
import '../../core/desire/thought_consolidation_engine.dart';
import '../../core/desire/thought_lifecycle_engine.dart';
import '../../core/maintenance/long_running_maintenance_engine.dart';
import '../../core/memory/memory_maintenance_engine.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/desire_state.dart';
import '../../core/perception/perception_engine.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/relationship/relationship_assimilator.dart';
import '../../core/storage/secure_config.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../core/tts/tts_policy.dart';
import '../../core/tts/tts_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    AppDatabase? db,
    DeepSeekClient? client,
    SecureConfig? secureConfig,
    AndroidBridge? android,
    this.externalRecoveryOrchestrator = false,
  })  : db = db ?? AppDatabase.instance,
        client = client ?? DeepSeekClient(),
        secureConfig = secureConfig ?? SecureConfig.instance,
        android = android ?? AndroidBridge.instance {
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
  final SecureConfig secureConfig;
  final AndroidBridge android;
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
  bool recoveringGeneration = false;
  String streamingReasoning = '';
  String streamingContent = '';
  bool streamingCompanionVoice = false;
  String? error;
  DeepSeekModelProfile model = DeepSeekModelProfile.pro;
  ReasoningEffort effort = ReasoningEffort.high;
  TtsQueueState ttsState = TtsQueueState.idle;
  bool _disposed = false;
  int _recoveryScheduleEpoch = 0;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      await db.ensureReady();
      model = DeepSeekModelProfile.fromApiName(await db.getSetting('model'));
      effort = ReasoningEffort.fromApiName(await db.getSetting('reasoning_effort'));
      messages = await db.recentMessages(limit: 120);
      loading = false;
      _safeNotify();

      try {
        await android.clearOverlayUnread();
      } catch (_) {
        // Overlay unread state is cosmetic and must never block the chat UI.
      }

      if (!externalRecoveryOrchestrator) {
        unawaited(_runStartupMaintenanceSafely());
        unawaited(_scheduleGenerationRecovery());
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

  Future<void> reload() async {
    messages = await db.recentMessages(limit: 120);
    _safeNotify();
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
                latest.last.content == messages.last.content));
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

  Future<void> sendText(String raw, {String? requestedMessageId}) async {
    final text = raw.trim();
    if (text.isEmpty || sending) return;
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
    recoveringGeneration = false;
    streamingReasoning = '';
    streamingContent = '';
    streamingCompanionVoice = false;
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
      messages = [...messages, user];
      _safeNotify();

      // The committed user turn + generation job are already crash-safe. These
      // enrichment steps are best-effort: if Android kills the process here,
      // recovery prioritizes producing the missing reply without duplicating
      // Desire pulses or other state mutations.
      await proactiveRhythm.captureUserResponse(user);
      await thoughtLifecycle.advance();
      await relationshipAssimilator.assimilatePending();
      await memoryMaintenance.maybeRun();
      await desireEngine.applyExperience({
        DriveKey.attachment: 0.018,
        DriveKey.social: 0.008,
      }, baselineLearning: 0.0015);
      await perceptionEngine.capture();
      await desireEngine.tick(pulses: {
        DriveKey.attachment: 0.025,
        DriveKey.reflection: 0.012,
      });

      final ttsEnabled = (await db.getSetting('tts_enabled')) != '0';
      final autoTts = ttsEnabled && (await db.getSetting('auto_tts')) != '0';
      streamingCompanionVoice = CompanionVoiceProtocol.enabledFromSetting(
        await db.getSetting(CompanionVoiceProtocol.settingKey),
      );
      streamTts = autoTts &&
          !streamingCompanionVoice &&
          (await db.getSetting('tts_streaming_enabled')) != '0';
      if (streamTts) {
        try {
          await ttsPlayback.beginStream(manual: false);
        } catch (_) {
          streamTts = false;
        }
      }

      // Best-effort enrichment can take a while on a large local database.
      // Refresh ownership immediately before opening the network stream so an
      // expired lease cannot let another engine start a competing chat turn.
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
        onDelta: (delta) {
          if (delta.finishReason == 'companion_voice_preview') {
            streamingReasoning = delta.reasoning;
          } else if (delta.finishReason == 'companion_voice_final') {
            streamingReasoning = delta.reasoning;
            streamingContent = delta.content;
          } else {
            if (delta.reasoning.isNotEmpty) {
              streamingReasoning += delta.reasoning;
            }
            if (delta.content.isNotEmpty) {
              streamingContent += delta.content;
              if (streamTts) ttsPlayback.addDelta(delta.content);
            }
          }
          _safeNotify();
        },
      );

      if (result.completed) {
        messages = [...messages, result.assistant!];
        if (streamTts) {
          ttsPlayback.endStream();
        } else if (autoTts) {
          unawaited(ttsPlayback.playText(result.assistant!.content, manual: false));
        }
        await memoryExtractor.extractFromTurn(
          user: user,
          assistant: result.assistant!,
        );
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
    } catch (e) {
      await ttsPlayback.stop();
      error = durableTurnCreated
          ? '这条消息已经保存，回复会在连接恢复后继续。\n$e'
          : e.toString();
    } finally {
      sending = false;
      streamingReasoning = '';
      streamingContent = '';
      await db.releaseLocalLease('chat_turn_lease');
      _safeNotify();
      if (durableTurnCreated) unawaited(_scheduleGenerationRecovery());
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
    recoveringGeneration = true;
    streamingReasoning = '';
    streamingContent = '';
    streamingCompanionVoice = CompanionVoiceProtocol.enabledFromSetting(
      await db.getSetting(CompanionVoiceProtocol.settingKey),
    );
    error = null;
    _safeNotify();
    try {
      final result = await generationRunner.run(
        job,
        onDelta: (delta) {
          if (delta.finishReason == 'companion_voice_preview') {
            streamingReasoning = delta.reasoning;
          } else if (delta.finishReason == 'companion_voice_final') {
            streamingReasoning = delta.reasoning;
            streamingContent = delta.content;
          } else {
            if (delta.reasoning.isNotEmpty) {
              streamingReasoning += delta.reasoning;
            }
            if (delta.content.isNotEmpty) streamingContent += delta.content;
          }
          _safeNotify();
        },
      );
      if (result.completed) {
        messages = await db.recentMessages(limit: 120);
        await db.setSetting('last_generation_recovery_error', '');
        final recoveredUser = await db.messageById(job.userMessageId);
        if (recoveredUser != null) {
          await memoryExtractor.extractFromTurn(
            user: recoveredUser,
            assistant: result.assistant!,
          );
        }
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
      recoveringGeneration = false;
      streamingReasoning = '';
      streamingContent = '';
      streamingCompanionVoice = false;
      await db.releaseLocalLease('chat_turn_lease');
      _safeNotify();
      unawaited(_scheduleGenerationRecovery());
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

  Future<void> speakMessage(ChatMessage message) async {
    if (!message.isAssistant || message.content.trim().isEmpty) return;
    await ttsPlayback.playText(message.content, manual: true);
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
    await ttsPlayback.playText(latest.content, manual: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _recoveryScheduleEpoch++;
    unawaited(ttsPlayback.stop());
    client.close();
    super.dispose();
  }
}
