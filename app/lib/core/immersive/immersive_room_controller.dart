import '../ai/first_channel_model.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ai/chat_api_provider.dart';
import '../ai/deepseek_client.dart';
import '../ai/final_reply_failure_policy.dart';
import '../ai/generation_cancellation.dart';
import '../ai/message_language_variant_service.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../emotion/emotion_classifier_service.dart';
import '../emotion/emotion_contract.dart';
import '../models/chat_language_variant.dart';
import '../models/chat_segment.dart';
import '../models/generation_job.dart';
import '../models/immersive_room.dart';
import '../personality/form_context_snapshot.dart';
import '../personality/playful_form_state.dart';
import '../somatic/somatic_engine.dart';
import '../storage/secure_config.dart';
import '../tts/tts_playback_queue.dart';
import '../tts/tts_provider.dart';
import '../tts/tts_service.dart';
import '../tts/tts_structured_stream_parser.dart';
import 'immersive_message_language_variant_service.dart';
import 'immersive_nsfw_router.dart';
import 'immersive_prompt_builder.dart';
import 'immersive_room_repository.dart';
import 'immersive_model_selection.dart';
import 'immersive_scene_advance.dart';
import 'immersive_form_snapshot.dart';
import '../ai/final_reply_route.dart';

class ImmersiveRoomController extends ChangeNotifier {
  ImmersiveRoomController({
    required this.roomId,
    AppDatabase? db,
    DeepSeekClient? client,
    SecureConfig? secureConfig,
    MessageLanguageVariantGateway? languageVariantGateway,
    ImmersiveRoomRepository? roomRepository,
  })  : db = db ?? AppDatabase.instance,
        secureConfig = secureConfig ?? SecureConfig.instance {
    repository = roomRepository ?? ImmersiveRoomRepository(this.db);
    this.client = client ?? DeepSeekClient(abortWhen: () async {
      final fence = repository.stateFence;
      return fence == null ? !await this.db.brainWorkAllowed()
          : !await this.db.brainWorkFenceCurrent(fence);
    });
    languageVariantService = ImmersiveMessageLanguageVariantService(
      store: RepositoryImmersiveMessageLanguageVariantStore(repository),
      gateway: languageVariantGateway ??
          DeepSeekMessageLanguageVariantGateway(client: this.client),
      apiKeyLoader: this.secureConfig.readApiKey,
      endpointLoader: this.secureConfig.readEndpoint,
      modelLoader: () => FirstChannelModel.read(this.db),
    );
    promptBuilder = ImmersivePromptBuilder(this.db);
    nsfwRouter = ImmersiveNsfwRouter(this.client);
    somaticEngine = SomaticEngine(this.db);
    ttsService = TtsService(db: this.db,
      qFormOverride: () async => (await _captureEntryForm()).qForm);
    ttsPlayback = TtsPlaybackQueue(
      service: ttsService,
      onStateChanged: (state) {
        ttsState = state;
        _safeNotify();
      },
    );
  }

  final String roomId;
  final AppDatabase db;
  late final DeepSeekClient client;
  final SecureConfig secureConfig;
  late final ImmersiveRoomRepository repository;
  late final ImmersiveMessageLanguageVariantService languageVariantService;
  late final ImmersivePromptBuilder promptBuilder;
  late final ImmersiveNsfwRouter nsfwRouter;
  late final SomaticEngine somaticEngine;
  late final TtsService ttsService;
  late final TtsPlaybackQueue ttsPlayback;

  ImmersiveFormSnapshot? _entryForm;
  FormContextSnapshot _entryFormContext = const FormContextSnapshot();
  Future<ImmersiveFormSnapshot>? _entryFormLoading;
  ImmersiveFormSnapshot get formSnapshot =>
      _entryForm ?? const ImmersiveFormSnapshot();
  Future<ImmersiveFormSnapshot> _captureEntryForm() =>
      _entryFormLoading ??= (() async {
        final state = await PlayfulFormStore(db).load();
        final snapshot = ImmersiveFormSnapshot.capture(state);
        _entryFormContext = FormContextSnapshot.capture(
          state, now: DateTime.now(), kind: 'room_entry');
        _entryForm = snapshot;
        return snapshot;
      })();

  ImmersiveRoom? room;
  List<ImmersiveMessage> messages = const [];
  List<InterruptedTurnDisplay> interruptions = const [];
  bool loading = true;
  bool sending = false;
  bool ending = false;
  bool nsfwRouting = false;
  String streamingReasoning = '';
  String streamingContent = '';
  TtsQueueState ttsState = TtsQueueState.idle;
  String? error;
  String? notice;
  ImmersiveMessage? incompleteReplyDraft;
  Map<String, Object?>? _finalModelRoute;
  String? incompleteReplyUserMessageId;
  ImmersiveMessage? _incompleteReplySourceUser;
  String? _incompleteReplyRaw;
  GenerationCancellationToken? _cancellation;
  bool _streamingDraftVisible = false;
  bool _lastFinalReplyUsedFallback = false;
  final TtsStructuredStreamParser _streamSpeechParser =
      TtsStructuredStreamParser();
  PlaybackIntent? _streamSpeechIntent;
  bool _streamSpeechEligible = false;
  bool _streamSpeechStarted = false;
  String? _streamSpeechOwnerId;
  String _allStreamingReasoning = '';
  Timer? _streamNotifyTimer;
  bool _disposed = false;

  String get _pendingReplySettingKey =>
      'immersive_pending_reply_${Uri.encodeComponent(roomId)}';
  String get _fallbackNoticeSettingKey =>
      'immersive_gemini_fallback_notice_${Uri.encodeComponent(roomId)}';

  bool get showStreamingDraft => sending && _streamingDraftVisible;

  List<ImmersiveTimelineItem> get timelineItems {
    final items = <ImmersiveTimelineItem>[
      for (final message in messages) ImmersiveTimelineItem.message(message),
      for (final interruption in interruptions)
        ImmersiveTimelineItem.interruption(interruption),
      if (incompleteReplyDraft != null)
        ImmersiveTimelineItem.message(incompleteReplyDraft!),
    ];
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  TtsPlaybackPhase ttsPhaseForMessage(String messageId) {
    if (ttsState.ownerId != messageId) return TtsPlaybackPhase.idle;
    return ttsState.phase;
  }

  Future<void> initialize() async {
    repository.stateFence = await db.captureBrainWorkFence();
    await _captureEntryForm();
    room = await repository.roomById(roomId);
    if (room == null) {
      error = '这个房间不存在或已经无法读取。';
    } else {
      final persistedNotice =
          (await db.getSetting(_fallbackNoticeSettingKey))?.trim() ?? '';
      if (persistedNotice.isNotEmpty) notice = persistedNotice;
      messages = await repository.messagesForRoom(roomId);
      interruptions = await repository.interruptionsForRoom(roomId);
      await _restoreIncompleteReplyDraft();
      if (!room!.isEnded && repository.stateFence != null) {
        await repository.activateRoom(roomId);
        room = await repository.inheritActiveSpecialStyleIfNeeded(roomId);
      }
    }
    loading = false;
    _safeNotify();
  }

  Future<bool> _canWrite() async {
    repository.stateFence ??= await db.captureBrainWorkFence();
    final fence = repository.stateFence;
    if (fence != null && await db.brainWorkFenceCurrent(fence)) return true;
    error = '当前设备处于待命、恢复中或状态已切换，请接管或重新打开房间后继续。';
    _safeNotify();
    return false;
  }

  Future<BrainWorkFence> _captureTurnFence() async {
    final entry = repository.stateFence;
    final held = await db.captureBrainWorkFence(leaseKey: 'immersive_room_lease');
    if (entry == null || held == null) throw const BrainWorkInvalidated();
    // Keep the entry's original identity even if a restore happened while the
    // lease snapshot was being read. Only the owned lease token is adopted.
    return BrainWorkFence(identity: Map.unmodifiable(entry.identity),
        expectedSettings: Map.unmodifiable(entry.expectedSettings),
        leaseKey: held.leaseKey, leaseToken: held.leaseToken);
  }

  Future<void> _writeRoomSetting(String key, String value) async {
    final fence = repository.stateFence;
    if (fence == null || !await db.setSettingsAtomically(
      {key: value}, workFence: fence,
    )) throw const BrainWorkInvalidated();
  }

  Future<void> reloadRoom() async {
    room = await repository.roomById(roomId);
    messages = await repository.messagesForRoom(roomId);
    interruptions = await repository.interruptionsForRoom(roomId);
    await _restoreIncompleteReplyDraft();
    _safeNotify();
  }

  Future<void> send(String rawText) => _send(rawText);

  Future<void> advanceScene() => _send(
        ImmersiveSceneAdvance.marker,
        sceneAdvance: true,
      );

  Future<void> _send(String rawText, {bool sceneAdvance = false}) async {
    if (!await _canWrite()) return;
    final text = rawText.trim();
    final currentRoom = room;
    if (text.isEmpty || sending || currentRoom == null || currentRoom.isEnded) {
      return;
    }
    if (incompleteReplyDraft != null) {
      error = '请先处理上一条截断回复：重新生成，或保留这段回复。';
      _safeNotify();
      return;
    }
    if (isReservedSystemInspectionCommand(text)) {
      error = null;
      notice = '请在普通聊天中检查系统';
      _safeNotify();
      return;
    }
    final apiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) {
      error = '请先到“更多”→“AI 与陪伴设置”填写必填的 DeepSeek API Key。';
      _safeNotify();
      return;
    }
    ImmersiveModelChoice selectedModel;
    try {
      selectedModel = await ImmersiveModelSelection.resolve(db, secureConfig: secureConfig);
    } catch (exception) {
      error = '无法使用所选沉浸模型：$exception';
      _safeNotify();
      return;
    }
    final ownsLease = await db.tryAcquireLocalLease(
      'immersive_room_lease',
      holdFor: const Duration(minutes: 10),
    );
    if (!ownsLease) {
      error = '另一个沉浸房间正在生成，请等那一轮结束。';
      _safeNotify();
      return;
    }

    try {
    final workFence = await _captureTurnFence();
    final historyBeforeTurn = List<ImmersiveMessage>.from(messages);
    await ttsPlayback.stop();
    final user = await repository.addMessage(
      roomId: roomId,
      role: 'user',
      content: text,
      formContextJson: _entryFormContext.encode(),
    );
    // Immersive turns share the same internal body channel as ordinary chat.
    // The room remains fictional, but a user-authored touch must not vanish
    // merely because this surface uses a different generation controller.
    if (!sceneAdvance) {
      await somaticEngine.captureUserTurn(
        turnId: user.id,
        text: text,
        now: user.createdAt,
      );
    }
    messages = [...messages, user];
    sending = true;
    nsfwRouting = true;
    streamingReasoning = '';
    streamingContent = '';
    _allStreamingReasoning = '';
    error = null;
    final cancellation = GenerationCancellationToken();
    _cancellation = cancellation;
    _streamingDraftVisible = true;
    _safeNotify();

    var committed = false;
    try {
      final endpoint = await secureConfig.readEndpoint();

      final finalProvider = selectedModel.provider;
      final finalApiKey = selectedModel.apiKey;
      final finalEndpoint = selectedModel.endpoint;
      final finalModelName = selectedModel.model;
      final routedRoom =
          (await repository.inheritActiveSpecialStyleIfNeeded(roomId))!;
      room = routedRoom;
      final route = await nsfwRouter.decide(
          model: await FirstChannelModel.read(db),
        apiKey: apiKey,
        endpoint: endpoint,
        room: routedRoom,
        latestUserText: sceneAdvance ? ImmersiveSceneAdvance.instruction : text,
        recent: historyBeforeTurn,
        cancellationToken: cancellation,
      );
      cancellation.throwIfCancelled();
      await repository.saveNsfwRoute(
        id: roomId,
        active: route.active,
        source: route.source,
      );
      room = await repository.roomById(roomId);
      nsfwRouting = false;
      _safeNotify();
      final request = await promptBuilder.build(
        room: room!,
        history: historyBeforeTurn,
        latestUserText: sceneAdvance ? ImmersiveSceneAdvance.instruction : text,
        nsfwActive: route.active,
        nsfwTurnDirective: route.turnDirective,
        formSnapshot: await _captureEntryForm(),
      );
      final profile = await FirstChannelModel.read(db);
      final effort = selectedModel.effort;
      _finalModelRoute = {'source': selectedModel.source.key, 'model': selectedModel.model,
        'provider': selectedModel.provider.storageValue, 'reason': 'selected'};
      await _configureStreamingSpeech(ownerId: 'stream:${user.id}');
      final finishReason = await _streamFinalRequest(
        internalApiKey: apiKey,
        internalEndpoint: endpoint,
        finalProvider: finalProvider,
        finalApiKey: finalApiKey,
        finalEndpoint: finalEndpoint,
        finalModelName: finalModelName,
        model: profile,
        effort: effort,
        request: request,
        cancellation: cancellation,
        displayReasoning: true,
        captureReasoning: true,
      );
      cancellation.throwIfCancelled();

      if (finalProvider.isGeminiRelay &&
          !_lastFinalReplyUsedFallback &&
          (FinalReplyFailurePolicy.isIncompleteFinishReason(finishReason) ||
              ImmersivePromptBuilder.shouldContinue(
                streamingContent,
                finishReason,
              ))) {
        throw _ImmersiveIncompleteReply(
          content: streamingContent,
          reasoning: _allStreamingReasoning,
          finishReason: finishReason,
        );
      }
      if (!finalProvider.isGeminiRelay && ImmersivePromptBuilder.shouldContinue(
        streamingContent,
        finishReason,
      )) {
        streamingContent += ImmersivePromptBuilder.continuationBoundary(
          streamingContent,
          finishReason,
        );
        await _streamRequest(
          apiKey: finalApiKey,
          endpoint: finalEndpoint,
          requestProvider: finalProvider,
          modelName: finalModelName,
          model: profile,
          effort: effort,
          request: ImmersivePromptBuilder.continuationMessages(
            request,
            streamingContent,
          ),
          cancellation: cancellation,
          displayReasoning: false,
          captureReasoning: false,
        );
        cancellation.throwIfCancelled();
      }
      if (streamingContent.trim().isEmpty) {
        throw const FormatException('模型没有返回可用的小说正文');
      }
      await _finishStreamingSpeech();
      cancellation.throwIfCancelled();
      final assistant = await repository.addAssistantReply(
        roomId: roomId,
        sourceUser: user,
        cancellation: cancellation,
        workFence: workFence,
        content: streamingContent,
        reasoningContent: _allStreamingReasoning,
        formContextJson: _entryFormContext.encode(),
        modelRoute: _finalModelRoute,
      );
      committed = true;

      _streamingDraftVisible = false;
      messages = [...messages, assistant];
      room = await repository.roomById(roomId);
      _safeNotify();
      var projectedAssistant = assistant;
      final selectedLanguage =
          ChatLanguage.tryParse(await db.getSetting('tts_language')) ??
              ChatLanguage.chinese;
      if (selectedLanguage != ChatLanguage.chinese) {
        try {
          projectedAssistant = await ensureLanguageVariant(
            assistant,
            selectedLanguage,
          );
        } catch (translationError) {
          final translationNotice =
              '外语版本生成失败，本次保留中文：$translationError';
          notice = notice == null
              ? translationNotice
              : '${notice!}\n$translationNotice';
        }
      }
      final speechLanguage = selectedLanguage == ChatLanguage.chinese ||
              _hasPlausibleLanguageVariant(
                projectedAssistant,
                selectedLanguage,
              )
          ? selectedLanguage
          : ChatLanguage.chinese;
      if ((_streamSpeechIntent?.valid ?? false) && !_streamSpeechStarted &&
          (await db.getSetting('tts_enabled')) != '0' &&
          (await db.getSetting('auto_tts')) != '0') {
        final emotion = await _ttsEmotionCueFor(assistant);
        unawaited(ttsPlayback.playText(
          projectedAssistant.contentFor(speechLanguage),
          intent: _streamSpeechIntent,
          manual: false,
          ownerId: assistant.id,
          emotion: emotion,
          language: speechLanguage,
        ));
      }
      unawaited(_maybeRefreshRollingState(
        apiKey: apiKey,
        endpoint: endpoint,
        model: profile,
      ));
    } on _ImmersiveIncompleteReply catch (incomplete) {
      await _preserveIncompleteReply(user: user, cancellation: cancellation,
        workFence: workFence, content: incomplete.content, reasoning: incomplete.reasoning,
        message: '第二通道回复已截断。当前文字尚未进入房间上下文或摘要，请选择“重新生成”或“保留这段回复”。');
    } on GenerationCancelledByUserException {
      if (!committed) await _finishStoppedTurn(user, workFence);
    } on BrainWorkInvalidated catch (invalidated) {
      if (!committed) await _abortStreamingSpeech();
      error = invalidated.toString();
    } catch (exception) {
      if (!committed && cancellation.isCancelled) {
        await _finishStoppedTurn(user, workFence);
      } else if (!committed && streamingContent.trim().isNotEmpty) {
        await _preserveIncompleteReply(user: user, cancellation: cancellation,
          workFence: workFence, content: streamingContent, reasoning: _allStreamingReasoning,
          message: '回复已截断。当前文字尚未进入房间上下文或摘要，请选择“重新生成”或“保留这段回复”。');
      } else {
        if (!committed) await _abortStreamingSpeech();
        error = '这一轮没有完整结束：$exception';
      }
    } finally {
      sending = false;
      nsfwRouting = false;
      _streamNotifyTimer?.cancel();
      _streamNotifyTimer = null;
      streamingReasoning = '';
      streamingContent = '';
      _allStreamingReasoning = '';
      _streamingDraftVisible = false;
      if (identical(_cancellation, cancellation)) _cancellation = null;
      _safeNotify();
    }
    } catch (exception) {
      sending = false;
      nsfwRouting = false;
      error = '这一轮未能开始: $exception';
      _safeNotify();
    } finally {
      await db.releaseLocalLease('immersive_room_lease');
    }
  }

  Future<String> _streamFinalRequest({
    required String internalApiKey,
    required String internalEndpoint,
    required ChatApiProvider finalProvider,
    required String finalApiKey,
    required String finalEndpoint,
    required String finalModelName,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> request,
    required GenerationCancellationToken cancellation,
    required bool displayReasoning,
    required bool captureReasoning,
  }) async {
    _lastFinalReplyUsedFallback = false;
    final finalRoute = FinalReplyRoute(secondChannelEnabled: finalProvider.isGeminiRelay);
    if (!finalRoute.useSecondChannel) {
      return _streamRequest(
        apiKey: finalApiKey,
        endpoint: finalEndpoint,
        requestProvider: finalProvider,
        modelName: finalModelName,
        model: model,
        effort: effort,
        request: request,
        cancellation: cancellation,
        displayReasoning: displayReasoning,
        captureReasoning: captureReasoning,
      );
    }
    Object? lastError;
    if (finalApiKey.isNotEmpty) {
      for (var attempt = 1;
          attempt <= FinalReplyFailurePolicy.maxGeminiAttempts;
          attempt++) {
        try {
          final finishReason = await _streamRequest(
            apiKey: finalApiKey,
            endpoint: finalEndpoint,
            requestProvider: finalProvider,
            modelName: finalModelName,
            model: model,
            effort: effort,
            request: request,
            cancellation: cancellation,
            displayReasoning: displayReasoning,
            captureReasoning: captureReasoning,
          );
          if (streamingContent.trim().isEmpty) {
            throw const EmptyFinalReplyException();
          }
          return finishReason;
        } catch (error) {
          if (error is GenerationCancelledByUserException) rethrow;
          if (streamingContent.trim().isNotEmpty) {
            throw _ImmersiveIncompleteReply(
              content: streamingContent,
              reasoning: _allStreamingReasoning,
              finishReason: 'stream_incomplete',
            );
          }
          lastError = error;
        }
        if (attempt >= FinalReplyFailurePolicy.maxGeminiAttempts ||
            !FinalReplyFailurePolicy.isTransient(lastError!)) {
          break;
        }
        streamingReasoning = '';
        streamingContent = '';
        _allStreamingReasoning = '';
        _safeNotify();
        await Future<void>.delayed(FinalReplyFailurePolicy.retryDelay);
        cancellation.throwIfCancelled();
      }
    } else {
      lastError = const FormatException('missing_gemini_final_reply_key');
    }
    streamingReasoning = '';
    streamingContent = '';
    _allStreamingReasoning = '';
    notice =
        '第二通道调用失败（${FinalReplyFailurePolicy.userCategory(lastError!)}），本轮已由 DeepSeek 兜底。';
    await _writeRoomSetting(_fallbackNoticeSettingKey, notice!);
    finalRoute.recordFailure(lastError!);
    _lastFinalReplyUsedFallback = true;
    _finalModelRoute = {'source': 'first', 'model': model.apiName,
      'provider': ChatApiProvider.deepSeek.storageValue, 'reason': 'second_channel_failure'};
    _safeNotify();
    return _streamRequest(
      apiKey: internalApiKey,
      endpoint: internalEndpoint,
      model: model,
      effort: effort,
      request: request,
      cancellation: cancellation,
      displayReasoning: displayReasoning,
      captureReasoning: captureReasoning,
    );
  }

  Future<String> _streamRequest({
    required String apiKey,
    required String endpoint,
    ChatApiProvider? requestProvider,
    String? modelName,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> request,
    required GenerationCancellationToken cancellation,
    required bool displayReasoning,
    required bool captureReasoning,
  }) async {
    var finishReason = '';
    var sawTerminalSignal = false;
    await for (final delta in client.streamChat(
      apiKey: apiKey,
      model: model,
      effort: effort,
      messages: request,
      endpoint: endpoint,
      requestProvider: requestProvider,
      modelName: modelName,
      thinking: true,
      // Narrative and reasoning share the output budget. Keep provider defaults
      // like ordinary chat; existing partial-draft/continuation rules still apply.
      cancellationToken: cancellation,
      usageLane: 'immersive_reply',
    )) {
      cancellation.throwIfCancelled();
      if (delta.reasoning.isNotEmpty) {
        _allStreamingReasoning = mergePersistedReasoning(
          _allStreamingReasoning,
          delta.reasoning,
          capture: captureReasoning,
        );
        if (displayReasoning) streamingReasoning += delta.reasoning;
      }
      if (delta.content.isNotEmpty) {
        streamingContent += delta.content;
        await _consumeStreamingSpeech(delta.content);
      }
      if (delta.finishReason != null) finishReason = delta.finishReason!;
      if (delta.done || delta.finishReason != null) sawTerminalSignal = true;
      if (delta.content.isNotEmpty ||
          (displayReasoning && delta.reasoning.isNotEmpty)) {
        _scheduleStreamNotify();
      }
    }
    _flushStreamNotify();
    if (!sawTerminalSignal) {
      throw GenerationStreamIncompleteException(
        reasoning: _allStreamingReasoning,
        content: streamingContent,
      );
    }
    return finishReason;
  }

  Future<void> _finishStoppedTurn(ImmersiveMessage user, BrainWorkFence workFence) async {
    await _abortStreamingSpeech();
    try {
      await repository.interruptUserMessageForDisplay(
          roomId: roomId, messageId: user.id, workFence: workFence,
          expectedSourceUser: user);
      messages = await repository.messagesForRoom(roomId);
      interruptions = await repository.interruptionsForRoom(roomId);
      error = null;
    } on BrainWorkInvalidated catch (invalidated) {
      // An obsolete room attempt may not remove a restored/replaced user turn.
      error = invalidated.toString();
    }
  }

  Future<void> _preserveIncompleteReply({
    required ImmersiveMessage user,
    required GenerationCancellationToken cancellation,
    required BrainWorkFence workFence,
    required String content,
    required String reasoning,
    required String message,
  }) async {
    try {
      await _abortStreamingSpeech();
      await _saveIncompleteReplyDraft(sourceUser: user,
          cancellation: cancellation, workFence: workFence,
          content: content, reasoning: reasoning);
      notice = message;
      error = null;
    } on GenerationCancelledByUserException {
      await _finishStoppedTurn(user, workFence);
    } on BrainWorkInvalidated catch (invalidated) {
      // A rejected assistant cannot re-enter the same room as a new draft.
      error = invalidated.toString();
    }
  }

  Future<void> _saveIncompleteReplyDraft({
    required ImmersiveMessage sourceUser,
    required GenerationCancellationToken cancellation,
    required BrainWorkFence workFence,
    required String content,
    required String reasoning,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final createdAt = DateTime.now();
    final userMessageId = sourceUser.id;
    final draft = ImmersiveMessage(
      id: 'pending:$roomId:$userMessageId',
      roomId: roomId,
      role: 'assistant',
      content: trimmed,
      reasoningContent: reasoning.trim(),
      createdAt: createdAt,
      formContextJson: _entryFormContext.encode(),
    );
    final raw = jsonEncode(<String, Object?>{
        'room_id': roomId,
        'user_message_id': userMessageId,
        'source_user': _sourceUserSnapshot(sourceUser),
        'content': trimmed,
        'reasoning': reasoning.trim(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'form_context_json': draft.formContextJson,
        if (_finalModelRoute != null) 'model_route': _finalModelRoute,
      });
    await repository.saveIncompleteReply(roomId: roomId, sourceUser: sourceUser,
        cancellation: cancellation, workFence: workFence, rawDraft: raw);
    incompleteReplyUserMessageId = userMessageId;
    _incompleteReplySourceUser = sourceUser;
    incompleteReplyDraft = draft;
    _incompleteReplyRaw = raw;
  }

  static Map<String, Object?> _sourceUserSnapshot(ImmersiveMessage user) => {
    'id': user.id, 'room_id': user.roomId, 'role': user.role,
    'content': user.content, 'reasoning_content': user.reasoningContent,
    'form_context_json': user.formContextJson,
    'created_at': user.createdAt.millisecondsSinceEpoch,
  };

  Future<void> _restoreIncompleteReplyDraft() async {
    final raw = await db.getSetting(_pendingReplySettingKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final data = (jsonDecode(raw) as Map).cast<String, Object?>();
      if (data['room_id'] != roomId) return;
      final content = data['content']?.toString().trim() ?? '';
      final userMessageId = data['user_message_id']?.toString() ?? '';
      if (content.isEmpty || userMessageId.isEmpty) return;
      incompleteReplyUserMessageId = userMessageId;
      _incompleteReplyRaw = raw;
      final source = data['source_user'];
      if (source is Map) {
        _incompleteReplySourceUser = ImmersiveMessage.fromDb(
            Map<String, Object?>.from(source));
      } else {
        // Legacy drafts carry only a user ID. The visible draft is explicitly
        // confirmed now; this snapshot protects this confirmation's wait, and
        // is not proof of the source content at the historical generation.
        _incompleteReplySourceUser = messages.where((message) =>
            message.id == userMessageId && message.isUser).firstOrNull;
      }
      if (_incompleteReplySourceUser?.id != userMessageId ||
          _incompleteReplySourceUser?.roomId != roomId ||
          _incompleteReplySourceUser?.isUser != true) {
        _incompleteReplySourceUser = null;
      }
      incompleteReplyDraft = ImmersiveMessage(
        id: 'pending:$roomId:$userMessageId',
        roomId: roomId,
        role: 'assistant',
        content: content,
        reasoningContent: data['reasoning']?.toString().trim() ?? '',
        formContextJson: data['form_context_json'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (data['created_at'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
      notice ??= '有一条截断回复尚未处理；它还没有进入房间上下文或摘要。';
    } catch (_) {
      if (repository.stateFence != null && await _canWrite()) {
        await _clearIncompleteReplyDraft();
      }
    }
  }

  Future<void> _clearIncompleteReplyDraft() async {
    incompleteReplyDraft = null;
    incompleteReplyUserMessageId = null;
    _incompleteReplySourceUser = null;
    _incompleteReplyRaw = null;
    await _writeRoomSetting(_pendingReplySettingKey, '');
  }

  Map<String, Object?>? _draftModelRoute(String raw) {
    try {
      final route = (jsonDecode(raw) as Map)['model_route'];
      if (route is! Map || route['model'] is! String) return null;
      return Map<String, Object?>.from(route);
    } catch (_) { return null; }
  }

  Future<void> confirmIncompleteReply() async {
    if (!await _canWrite()) return;
    final draft = incompleteReplyDraft;
    if (draft == null || sending) return;
    final sourceUser = _incompleteReplySourceUser;
    final expectedDraft = _incompleteReplyRaw;
    if (sourceUser == null || expectedDraft == null) {
      error = '找不到这份草稿对应的用户消息，请重新打开房间后再确认。';
      _safeNotify();
      return;
    }
    final internalApiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (internalApiKey.isEmpty) {
      error = '确认后需要启动正常的房间整理，请先填写 DeepSeek API Key。';
      _safeNotify();
      return;
    }
    final ownsLease = await db.tryAcquireLocalLease(
      'immersive_room_lease',
      holdFor: const Duration(minutes: 2),
    );
    if (!ownsLease) {
      error = '另一个沉浸房间正在写入，请稍后再确认。';
      _safeNotify();
      return;
    }
    final cancellation = GenerationCancellationToken();
    _cancellation = cancellation;
    sending = true;
    error = null;
    _safeNotify();
    try {
      final workFence = await _captureTurnFence();
      final assistant = await repository.addAssistantReply(
        roomId: roomId,
        sourceUser: sourceUser,
        cancellation: cancellation,
        workFence: workFence,
        expectedDraft: expectedDraft,
        modelRoute: _draftModelRoute(expectedDraft),
        content: draft.content,
        reasoningContent: draft.reasoningContent,
        // A restored draft belongs to its original entry. Missing legacy
        // metadata remains unknown even if the current entry form is known.
        formContextJson: draft.formContextJson,
      );

      // The durable draft was consumed with the assistant transaction.
      incompleteReplyDraft = null;
      incompleteReplyUserMessageId = null;
      _incompleteReplySourceUser = null;
      _incompleteReplyRaw = null;
      messages = await repository.messagesForRoom(roomId);
      room = await repository.roomById(roomId);
      notice = '已确认截断回复；它现在会进入房间上下文与后续摘要。';
      final endpoint = await secureConfig.readEndpoint();
      final model =
          DeepSeekModelProfile.fromApiName(await db.getSetting('model'));
      unawaited(_maybeRefreshRollingState(
        apiKey: internalApiKey,
        endpoint: endpoint,
        model: model,
      ));
      if ((await db.getSetting('tts_enabled')) != '0' &&
          (await db.getSetting('auto_tts')) != '0') {
        final language =
            ChatLanguage.tryParse(await db.getSetting('tts_language')) ??
                ChatLanguage.chinese;
        unawaited(speakMessage(assistant, language: language));
      }
    } on GenerationCancelledByUserException {
      // Stopping confirmation keeps the previously visible draft and user turn.
      error = null;
    } catch (exception) {
      error = '确认这条回复失败：$exception';
    } finally {
      sending = false;
      if (identical(_cancellation, cancellation)) _cancellation = null;
      await db.releaseLocalLease('immersive_room_lease');
      _safeNotify();
    }
  }

  Future<void> regenerateIncompleteReply({bool leaseAlreadyHeld = false}) async {
    if (!await _canWrite()) {
      return;
    }
    final userMessageId = incompleteReplyUserMessageId;
    if (userMessageId == null || sending || room?.isEnded == true) {
      return;
    }
    final user = _incompleteReplySourceUser ?? messages.cast<ImmersiveMessage?>().firstWhere(
          (item) => item?.id == userMessageId && item!.isUser,
          orElse: () => null,
        );
    if (user == null) {
      error = '找不到这份草稿对应的用户消息。';
      _safeNotify();
      return;
    }
    final internalApiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (internalApiKey.isEmpty) {
      error = '请先填写必填的 DeepSeek API Key。';
      _safeNotify();
      return;
    }
    final ownsLease = leaseAlreadyHeld ||
        await db.tryAcquireLocalLease(
          'immersive_room_lease',
          holdFor: const Duration(minutes: 10),
        );
    if (!ownsLease) {
      error = '另一个沉浸房间正在生成，请稍后再试。';
      _safeNotify();
      return;
    }
    try {
    final workFence = await _captureTurnFence();
    await _clearIncompleteReplyDraft();
    await ttsPlayback.stop();
    sending = true;
    nsfwRouting = true;
    streamingReasoning = '';
    streamingContent = '';
    _allStreamingReasoning = '';
    error = null;
    final persistedFallback =
        (await db.getSetting(_fallbackNoticeSettingKey))?.trim() ?? '';
    notice = persistedFallback.isEmpty ? null : persistedFallback;
    final cancellation = GenerationCancellationToken();
    _cancellation = cancellation;
    _streamingDraftVisible = true;
    _safeNotify();
    var committed = false;
    try {
      final internalEndpoint = await secureConfig.readEndpoint();
      final selectedModel = await ImmersiveModelSelection.resolve(db, secureConfig: secureConfig);
      final finalProvider = selectedModel.provider;
      final finalApiKey = selectedModel.apiKey;
      final finalEndpoint = selectedModel.endpoint;
      final finalModelName = selectedModel.model;
      final routedRoom =
          (await repository.inheritActiveSpecialStyleIfNeeded(roomId))!;
      room = routedRoom;
      final historyBeforeTurn = messages
          .where((item) => item.createdAt.isBefore(user.createdAt))
          .toList(growable: false);
      final route = await nsfwRouter.decide(
          model: await FirstChannelModel.read(db),
        apiKey: internalApiKey,
        endpoint: internalEndpoint,
        room: routedRoom,
        latestUserText: user.content,
        recent: historyBeforeTurn,
        cancellationToken: cancellation,
      );
      await repository.saveNsfwRoute(
        id: roomId,
        active: route.active,
        source: route.source,
      );
      room = await repository.roomById(roomId);
      nsfwRouting = false;
      final request = await promptBuilder.build(
        room: room!,
        history: historyBeforeTurn,
        latestUserText: user.content,
        nsfwActive: route.active,
        nsfwTurnDirective: route.turnDirective,
        formSnapshot: await _captureEntryForm(),
      );
      final profile = await FirstChannelModel.read(db);
      final effort = selectedModel.effort;
      _finalModelRoute = {'source': selectedModel.source.key, 'model': selectedModel.model,
        'provider': selectedModel.provider.storageValue, 'reason': 'selected'};
      await _configureStreamingSpeech(ownerId: 'stream:${user.id}');
      final finishReason = await _streamFinalRequest(
        internalApiKey: internalApiKey,
        internalEndpoint: internalEndpoint,
        finalProvider: finalProvider,
        finalApiKey: finalApiKey,
        finalEndpoint: finalEndpoint,
        finalModelName: finalModelName,
        model: profile,
        effort: effort,
        request: request,
        cancellation: cancellation,
        displayReasoning: true,
        captureReasoning: true,
      );
      if (finalProvider.isGeminiRelay &&
          !_lastFinalReplyUsedFallback &&
          (FinalReplyFailurePolicy.isIncompleteFinishReason(finishReason) ||
              ImmersivePromptBuilder.shouldContinue(
                streamingContent,
                finishReason,
              ))) {
        throw _ImmersiveIncompleteReply(
          content: streamingContent,
          reasoning: _allStreamingReasoning,
          finishReason: finishReason,
        );
      }
      if (streamingContent.trim().isEmpty) {
        throw const FormatException('模型没有返回可用的小说正文');
      }
      await _finishStreamingSpeech();
      cancellation.throwIfCancelled();
      await repository.addAssistantReply(
        roomId: roomId,
        sourceUser: user,
        cancellation: cancellation,
        workFence: workFence,
        content: streamingContent,
        reasoningContent: _allStreamingReasoning,
        formContextJson: _entryFormContext.encode(),
        modelRoute: _finalModelRoute,
      );
      committed = true;

      messages = await repository.messagesForRoom(roomId);
      room = await repository.roomById(roomId);
      unawaited(_maybeRefreshRollingState(
        apiKey: internalApiKey,
        endpoint: internalEndpoint,
        model: profile,
      ));
    } on _ImmersiveIncompleteReply catch (incomplete) {
      await _preserveIncompleteReply(user: user, cancellation: cancellation,
        workFence: workFence, content: incomplete.content, reasoning: incomplete.reasoning,
        message: '第二通道回复已截断。当前文字尚未进入房间上下文或摘要，请选择“重新生成”或“保留这段回复”。');
    } on GenerationCancelledByUserException {
      if (!committed) await _finishStoppedTurn(user, workFence);
    } on BrainWorkInvalidated catch (invalidated) {
      if (!committed) await _abortStreamingSpeech();
      error = invalidated.toString();
    } catch (exception) {
      if (!committed && cancellation.isCancelled) {
        await _finishStoppedTurn(user, workFence);
      } else if (!committed && streamingContent.trim().isNotEmpty) {
        await _preserveIncompleteReply(user: user, cancellation: cancellation,
          workFence: workFence, content: streamingContent, reasoning: _allStreamingReasoning,
          message: '回复再次异常中断并已截断。当前文字尚未进入房间上下文或摘要，请选择“重新生成”或“保留这段回复”。');
      } else {
        if (!committed) await _abortStreamingSpeech();
        error = '重新生成失败：$exception';
      }
    } finally {
      sending = false;
      nsfwRouting = false;
      streamingReasoning = '';
      streamingContent = '';
      _allStreamingReasoning = '';
      _streamingDraftVisible = false;
      if (identical(_cancellation, cancellation)) _cancellation = null;
      _safeNotify();
    }
    } catch (exception) {
      sending = false;
      nsfwRouting = false;
      error = '重新生成未能开始: $exception';
      _safeNotify();
    } finally {
      // A delegated regeneration borrows its caller's lease. Releasing it here
      // would let a new owner enter before the caller's own finally releases.
      if (!leaseAlreadyHeld) await db.releaseLocalLease('immersive_room_lease');
    }
  }

  String? get latestAssistantMessageId {
    if (incompleteReplyDraft != null) return incompleteReplyDraft!.id;
    for (final message in messages.reversed) {
      if (message.isAssistant) return message.id;
    }
    return null;
  }

  Future<void> regenerateLatestReply(ImmersiveMessage assistant) async {
    if (!await _canWrite()) return;
    if (!assistant.isAssistant || sending || room?.isEnded == true) return;
    if (assistant.id == incompleteReplyDraft?.id) {
      await regenerateIncompleteReply();
      return;
    }
    final internalApiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (internalApiKey.isEmpty) {
      error = '请先填写必填的 DeepSeek API Key。';
      _safeNotify();
      return;
    }
    final ownsLease = await db.tryAcquireLocalLease(
      'immersive_room_lease',
      holdFor: const Duration(minutes: 10),
    );
    if (!ownsLease) {
      error = '另一个沉浸房间正在生成，请稍后再试。';
      _safeNotify();
      return;
    }
    try {
    final userMessageId =
        await repository.removeLatestAssistantForRegeneration(
      roomId: roomId,
      assistantMessageId: assistant.id,
    );
    if (userMessageId == null) {
      error = '只能重新生成当前最新且尚未归入滚动摘要的回复。';
      _safeNotify();
      return;
    }
    await ttsPlayback.stop();
    messages = await repository.messagesForRoom(roomId);
    incompleteReplyUserMessageId = userMessageId;
    notice = null;
    error = null;
    _safeNotify();
    await regenerateIncompleteReply(leaseAlreadyHeld: true);
    } catch (exception) {
      sending = false;
      nsfwRouting = false;
      error = '重新生成未能开始: $exception';
      _safeNotify();
    } finally {
      await db.releaseLocalLease('immersive_room_lease');
    }
  }

  Future<void> stop() async {
    _cancellation?.cancel();
  }

  void dismissNotice() {
    notice = null;
    final fence = repository.stateFence;
    if (fence != null) {
      unawaited(db.setSettingsAtomically(
        {_fallbackNoticeSettingKey: ''}, workFence: fence,
      ).then<void>((_) {}).catchError((Object _) {}));
    }
    _safeNotify();
  }

  @visibleForTesting
  static bool isReservedSystemInspectionCommand(String rawText) =>
      rawText.trimLeft().startsWith('【检查系统】');

  @visibleForTesting
  static String mergePersistedReasoning(
    String current,
    String delta, {
    required bool capture,
  }) =>
      capture ? '$current$delta' : current;

  Future<void> speakMessage(
    ImmersiveMessage message, {
    ChatLanguage language = ChatLanguage.chinese,
  }) async {
    if (!message.isAssistant || message.content.trim().isEmpty) return;
    final playbackIntent = ttsPlayback.createIntent(ownerId: message.id);
    var projected = message;
    if (language != ChatLanguage.chinese &&
        !_hasPlausibleLanguageVariant(message, language)) {
      if (message.id == incompleteReplyDraft?.id) {
        final apiKey = (await secureConfig.readApiKey())?.trim() ?? '';
        if (apiKey.isEmpty) {
          throw const MessageLanguageVariantException(
            '请先填写必填的 DeepSeek API Key。',
          );
        }
        final translated = await languageVariantService.gateway.translate(
          model: await FirstChannelModel.read(db),
          apiKey: apiKey,
          endpoint: await secureConfig.readEndpoint(),
          source: ChatSegmentCodec.parseAssistantText(message.content),
          target: language,
        );
        projected = message.copyWith(
          languageVariants: <ChatLanguage, ChatLanguageVariant>{
            ...message.languageVariants,
            language: ChatLanguageVariant(
              messageId: message.id,
              language: language,
              content: ChatSegmentCodec.immersiveDisplayText(translated),
              segments: translated,
            ),
          },
        );
        incompleteReplyDraft = projected;
        _safeNotify();
      } else {
        projected = await ensureLanguageVariant(message, language);
      }
    }
    if (!playbackIntent.valid) return;
    final speechSegments = projected.segmentsFor(language);
    final content = (speechSegments.isNotEmpty
            ? ChatSegmentCodec.immersiveDisplayText(speechSegments)
            : projected.contentFor(language))
        .trim();
    if (content.isEmpty) return;
    await db.setSetting('tts_language', language.key);
    final emotion = await _ttsEmotionCueFor(message);
    await ttsPlayback.playText(
      content,
      intent: playbackIntent,
      manual: true,
      ownerId: message.id,
      emotion: emotion,
      language: language,
    );
  }

  Future<ImmersiveMessage> ensureLanguageVariant(
    ImmersiveMessage message,
    ChatLanguage language,
  ) async {
    if (language == ChatLanguage.chinese ||
        _hasPlausibleLanguageVariant(message, language)) {
      return message;
    }
    final variant = await languageVariantService.ensure(
      message: message,
      language: language,
    );
    final updated = message.copyWith(
      languageVariants: <ChatLanguage, ChatLanguageVariant>{
        ...message.languageVariants,
        language: variant,
      },
    );
    messages = messages
        .map((item) => item.id == message.id ? updated : item)
        .toList(growable: false);
    _safeNotify();
    return updated;
  }

  bool _hasPlausibleLanguageVariant(
    ImmersiveMessage message,
    ChatLanguage language,
  ) {
    final variant = message.languageVariants[language];
    return variant != null &&
        MessageLanguageVariantDecoder.isPlausibleVariant(variant, language);
  }

  Future<TtsEmotionCue> _ttsEmotionCueFor(ImmersiveMessage message) async {
    return _ttsEmotionCueForText(message.content);
  }

  Future<TtsEmotionCue> _ttsEmotionCueForText(String text) async {
    final resolved = await EmotionClassifierService.instance.resolve(
      rawTag: '',
      visibleText: text,
      envelopeStatus: EmotionEnvelopeStatus.missing,
    );
    return TtsEmotionCue(
      key: resolved.key,
      label: resolved.label,
      confidence: resolved.confidence,
      source: resolved.source,
    );
  }

  Future<void> _configureStreamingSpeech({required String ownerId}) async {
    _streamSpeechIntent = ttsPlayback.createIntent(ownerId: ownerId,
      formForPlayback: _entryFormContext.isKnown ? _entryFormContext.form == 'q' : null);
    _streamSpeechParser.reset();
    _streamSpeechStarted = false;
    _streamSpeechOwnerId = ownerId;
    final language =
        ChatLanguage.tryParse(await db.getSetting('tts_language')) ??
            ChatLanguage.chinese;
    final enabled = (await db.getSetting('tts_enabled')) != '0' &&
        (await db.getSetting('auto_tts')) != '0';
    _streamSpeechEligible = language == ChatLanguage.chinese && enabled && (_streamSpeechIntent?.valid ?? false);
    if (!enabled) { _streamSpeechIntent?.cancel(); await ttsPlayback.stop(); }
  }

  Future<void> _consumeStreamingSpeech(String delta) async {
    final intent = _streamSpeechIntent;
    if (!_streamSpeechEligible || intent == null || !intent.valid || delta.isEmpty) return;
    final units = _streamSpeechParser.add(delta);
    if (units.isEmpty) return;
    if (!_streamSpeechStarted) {
      final emotion = await _ttsEmotionCueForText(streamingContent);
      if (!intent.valid) return;
      await ttsPlayback.beginStream(
        intent: intent,
        manual: false,
        ownerId: _streamSpeechOwnerId,
        emotion: emotion,
        language: ChatLanguage.chinese,
      );
      if (!intent.valid) return;
      _streamSpeechStarted = true;
    }
    for (final unit in units) {
      ttsPlayback.addStructuredUnit(unit.text, role: unit.role);
    }
  }

  Future<void> _finishStreamingSpeech() async {
    final intent = _streamSpeechIntent;
    if (!_streamSpeechEligible || intent == null || !intent.valid) return;
    final tail = _streamSpeechParser.finish();
    if (tail.isNotEmpty && !_streamSpeechStarted) {
      final emotion = await _ttsEmotionCueForText(streamingContent);
      if (!intent.valid) return;
      await ttsPlayback.beginStream(
        intent: intent,
        manual: false,
        ownerId: _streamSpeechOwnerId,
        emotion: emotion,
        language: ChatLanguage.chinese,
      );
      if (!intent.valid) return;
      _streamSpeechStarted = true;
    }
    for (final unit in tail) {
      ttsPlayback.addStructuredUnit(unit.text, role: unit.role);
    }
    if (_streamSpeechStarted) ttsPlayback.endStream();
  }

  Future<void> _abortStreamingSpeech() async {
    _streamSpeechParser.reset();
    _streamSpeechEligible = false;
    _streamSpeechIntent?.cancel();
    await ttsPlayback.stop();
    _streamSpeechIntent = null;
    _streamSpeechStarted = false;
    _streamSpeechOwnerId = null;
  }

  Future<void> stopSpeech() => _abortStreamingSpeech();

  Future<void> setNsfwActive(bool active) async {
    final current = room;
    if (sending || ending || current == null || current.isEnded) return;
    await repository.setNsfwManualOverride(roomId, active);
    room = await repository.roomById(roomId);
    _safeNotify();
  }

  Future<void> pinCurrentSpecialStyle() async {
    if (sending || ending || room == null || room!.isEnded) return;
    room = await repository.pinCurrentSpecialStyle(roomId);
    _safeNotify();
  }

  Future<void> disableSpecialStyle() async {
    if (sending || ending || room == null || room!.isEnded) return;
    room = await repository.disableSpecialStyle(roomId);
    _safeNotify();
  }

  Future<void> pause() async {
    if (sending || ending) return;
    await repository.pauseRoom(roomId);
    room = await repository.roomById(roomId);
    _safeNotify();
  }

  Future<void> rename(String title) async {
    if (sending || ending || room == null) return;
    await repository.renameRoom(roomId, title);
    room = await repository.roomById(roomId);
    _safeNotify();
  }

  Future<bool> deleteRoom() async {
    if (sending || ending || room == null) return false;
    await ttsPlayback.stop();
    await _clearIncompleteReplyDraft();
    await _writeRoomSetting(_fallbackNoticeSettingKey, '');
    await repository.deleteRoom(roomId);
    room = null;
    messages = const [];
    interruptions = const [];
    _safeNotify();
    return true;
  }

  Future<void> updateDetails({
    required String title,
    required String entryContext,
    required String novelRules,
  }) async {
    if (sending || ending) return;
    await repository.updateRoomDetails(
      id: roomId,
      title: title,
      entryContext: entryContext,
      novelRules: novelRules,
    );
    room = await repository.roomById(roomId);
    _safeNotify();
  }

  Future<bool> endRoom() async {
    if (!await _canWrite()) return false;
    if (sending || ending || room == null || room!.isEnded) return false;
    if (incompleteReplyDraft != null) {
      error = '请先处理待确认的截断回复，再结束房间。';
      _safeNotify();
      return false;
    }
    ending = true;
    error = null;
    _safeNotify();
    try {
      await repository.endRoomLocally(roomId);
      room = await repository.roomById(roomId);
      return room?.isEnded == true;
    } catch (_) {
      error = '房间未能结束，原始记录仍完整保留，请稍后重试。';
      return false;
    } finally {
      ending = false;
      _safeNotify();
    }
  }

  Future<void> _maybeRefreshRollingState({
    required String apiKey,
    required String endpoint,
    required DeepSeekModelProfile model,
  }) async {
    try {
      final current = await repository.roomById(roomId);
      final allMessages = await repository.messagesForRoom(roomId);
      if (current == null || allMessages.length - current.summarizedMessageCount < 14) {
        return;
      }
      final summarizeUntil =
          (allMessages.length - 8).clamp(0, allMessages.length).toInt();
      if (summarizeUntil <= current.summarizedMessageCount) return;
      final source = allMessages.sublist(
        current.summarizedMessageCount,
        summarizeUntil,
      );
      final result = await client.jsonCompletion(
        apiKey: apiKey,
        model: model,
        endpoint: endpoint,
        thinking: false,
        // This is a bounded JSON compaction task, not the visible narrative.
        maxTokens: 1600,
        usageLane: 'immersive_summary',
        messages: [
          {
            'role': 'system',
            'content': '''只输出 JSON：{"rolling_summary":"按事件顺序合并旧摘要与新增剧情，去掉重复感官和重复动作，保留变化、承诺与未完成事件","scene_ledger":"当前地点、时间、人物、姿势、衣物、接触点、阶段、身体状态、未完成事件"}。不得把虚构房间写成现实事实。摘要和现场账提及用户时统一写“用户”，不得写成“他”；不得替用户新增台词、主动动作、内心、态度、同意、意图或决定。可以记录用户明确输入的事实，以及原文已经出现的生理和被动身体反馈。当时形态标签只说明该条历史发生时的情境，未知不可倒推；两种形态属于同一人，经历与成长共用，不将一次变身提炼为永久人格。''',
          },
          {
            'role': 'user',
            'content': '''旧摘要：${current.rollingSummary}
旧现场账：${current.sceneLedger}

需要吸收的原文：
${_summaryTranscript(source, maxCharacters: 22000)}''',
          },
        ],
      );
      final summary = result['rolling_summary']?.toString().trim() ?? '';
      final ledger = result['scene_ledger']?.toString().trim() ?? '';
      if (summary.isEmpty || ledger.isEmpty) return;
      await repository.saveRollingState(
        roomId: roomId,
        rollingSummary: summary,
        sceneLedger: ledger,
        summarizedMessageCount: summarizeUntil,
      );
      room = await repository.roomById(roomId);
      _safeNotify();
    } catch (_) {
      // Rolling compaction is best-effort. Raw room messages stay authoritative.
    }
  }

  static String _summaryTranscript(
    List<ImmersiveMessage> source, {
    required int maxCharacters,
  }) {
    final selected = <ImmersiveMessage>[];
    var used = 0;
    for (final message in source.reversed) {
      final cost = message.content.length + message.historicalFormLabel.length + 10;
      if (used + cost > maxCharacters && selected.isNotEmpty) {
        break;
      }
      selected.add(message);
      used += cost;
    }
    return selected.reversed
        .map(
          (message) =>
              '${message.isUser ? '用户输入' : 'AI正文'}'
              '〔${message.historicalFormLabel}〕：${message.content}',
        )
        .join('\n\n');
  }

  void _scheduleStreamNotify() {
    if (_disposed || _streamNotifyTimer != null) return;
    _streamNotifyTimer = Timer(const Duration(milliseconds: 16), () {
      _streamNotifyTimer = null;
      _safeNotify();
    });
  }

  void _flushStreamNotify() {
    final pending = _streamNotifyTimer;
    if (pending == null) return;
    pending.cancel();
    _streamNotifyTimer = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _streamNotifyTimer?.cancel();
    _cancellation?.cancel();
    unawaited(ttsPlayback.stop());
    client.close();
    super.dispose();
  }
}

class _ImmersiveIncompleteReply implements Exception {
  const _ImmersiveIncompleteReply({
    required this.content,
    required this.reasoning,
    required this.finishReason,
  });

  final String content;
  final String reasoning;
  final String finishReason;
}

class ImmersiveTimelineItem {
  const ImmersiveTimelineItem._({
    required this.createdAt,
    this.message,
    this.interruption,
  });

  factory ImmersiveTimelineItem.message(ImmersiveMessage message) =>
      ImmersiveTimelineItem._(
        createdAt: message.createdAt,
        message: message,
      );

  factory ImmersiveTimelineItem.interruption(
    InterruptedTurnDisplay interruption,
  ) =>
      ImmersiveTimelineItem._(
        createdAt: interruption.createdAt,
        interruption: interruption,
      );

  final DateTime createdAt;
  final ImmersiveMessage? message;
  final InterruptedTurnDisplay? interruption;

  bool get isInterruption => interruption != null;
}
