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
import '../emotion/emotion_classifier_service.dart';
import '../emotion/emotion_contract.dart';
import '../models/chat_language_variant.dart';
import '../models/generation_job.dart';
import '../models/immersive_room.dart';
import '../somatic/somatic_engine.dart';
import '../storage/secure_config.dart';
import '../tts/tts_playback_queue.dart';
import '../tts/tts_provider.dart';
import '../tts/tts_service.dart';
import 'immersive_message_language_variant_service.dart';
import 'immersive_nsfw_router.dart';
import 'immersive_prompt_builder.dart';
import 'immersive_room_repository.dart';

class ImmersiveRoomController extends ChangeNotifier {
  ImmersiveRoomController({
    required this.roomId,
    AppDatabase? db,
    DeepSeekClient? client,
    SecureConfig? secureConfig,
    MessageLanguageVariantGateway? languageVariantGateway,
  })  : db = db ?? AppDatabase.instance,
        client = client ?? DeepSeekClient(),
        secureConfig = secureConfig ?? SecureConfig.instance {
    repository = ImmersiveRoomRepository(this.db);
    languageVariantService = ImmersiveMessageLanguageVariantService(
      store: RepositoryImmersiveMessageLanguageVariantStore(repository),
      gateway: languageVariantGateway ??
          DeepSeekMessageLanguageVariantGateway(client: this.client),
      apiKeyLoader: this.secureConfig.readApiKey,
      endpointLoader: this.secureConfig.readEndpoint,
    );
    promptBuilder = ImmersivePromptBuilder(this.db);
    nsfwRouter = ImmersiveNsfwRouter(this.client);
    somaticEngine = SomaticEngine(this.db);
    ttsService = TtsService(db: this.db);
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
  final DeepSeekClient client;
  final SecureConfig secureConfig;
  late final ImmersiveRoomRepository repository;
  late final ImmersiveMessageLanguageVariantService languageVariantService;
  late final ImmersivePromptBuilder promptBuilder;
  late final ImmersiveNsfwRouter nsfwRouter;
  late final SomaticEngine somaticEngine;
  late final TtsService ttsService;
  late final TtsPlaybackQueue ttsPlayback;

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
  String? incompleteReplyUserMessageId;
  GenerationCancellationToken? _cancellation;
  bool _streamingDraftVisible = false;
  bool _lastFinalReplyUsedFallback = false;
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
      if (!room!.isEnded) {
        await repository.activateRoom(roomId);
        room = await repository.inheritActiveSpecialStyleIfNeeded(roomId);
      }
    }
    loading = false;
    _safeNotify();
  }

  Future<void> reloadRoom() async {
    room = await repository.roomById(roomId);
    messages = await repository.messagesForRoom(roomId);
    interruptions = await repository.interruptionsForRoom(roomId);
    await _restoreIncompleteReplyDraft();
    _safeNotify();
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    final currentRoom = room;
    if (text.isEmpty || sending || currentRoom == null || currentRoom.isEnded) {
      return;
    }
    if (incompleteReplyDraft != null) {
      error = '请先处理上一条未完整回复：重新生成，或确认当前文字。';
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
    final ownsLease = await db.tryAcquireLocalLease(
      'immersive_room_lease',
      holdFor: const Duration(minutes: 10),
    );
    if (!ownsLease) {
      error = '另一个沉浸房间正在生成，请等那一轮结束。';
      _safeNotify();
      return;
    }

    final historyBeforeTurn = List<ImmersiveMessage>.from(messages);
    await ttsPlayback.stop();
    final user = await repository.addMessage(
      roomId: roomId,
      role: 'user',
      content: text,
    );
    // Immersive turns share the same internal body channel as ordinary chat.
    // The room remains fictional, but a user-authored touch must not vanish
    // merely because this surface uses a different generation controller.
    await somaticEngine.captureUserTurn(
      turnId: user.id,
      text: text,
      now: user.createdAt,
    );
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
      final finalProvider = await secureConfig.readChatProvider();
      final finalApiKey =
          (await secureConfig.readFinalReplyApiKey())?.trim() ?? '';
      final finalEndpoint = await secureConfig.readFinalReplyEndpoint();
      final routedRoom =
          (await repository.inheritActiveSpecialStyleIfNeeded(roomId))!;
      room = routedRoom;
      final route = await nsfwRouter.decide(
        apiKey: apiKey,
        endpoint: endpoint,
        room: routedRoom,
        latestUserText: text,
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
        latestUserText: text,
        nsfwActive: route.active,
        nsfwTurnDirective: route.turnDirective,
      );
      final profile = DeepSeekModelProfile.fromApiName(
        await db.getSetting('model'),
      );
      final effort = ReasoningEffort.fromApiName(
        await db.getSetting('reasoning_effort'),
      );
      final finishReason = await _streamFinalRequest(
        internalApiKey: apiKey,
        internalEndpoint: endpoint,
        finalProvider: finalProvider,
        finalApiKey: finalApiKey,
        finalEndpoint: finalEndpoint,
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
          apiKey: apiKey,
          endpoint: endpoint,
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
      final assistant = await repository.addMessage(
        roomId: roomId,
        role: 'assistant',
        content: streamingContent,
        reasoningContent: _allStreamingReasoning,
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
      if ((await db.getSetting('tts_enabled')) != '0' &&
          (await db.getSetting('auto_tts')) != '0') {
        final emotion = await _ttsEmotionCueFor(assistant);
        unawaited(ttsPlayback.playText(
          projectedAssistant.contentFor(speechLanguage),
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
      await _saveIncompleteReplyDraft(
        userMessageId: user.id,
        content: incomplete.content,
        reasoning: incomplete.reasoning,
      );
      notice = 'Gemini 回复未完整结束。当前文字尚未进入房间上下文或摘要，请选择“重新生成”或“确认回复”。';
      error = null;
    } on GenerationCancelledByUserException {
      await repository.interruptUserMessageForDisplay(
        roomId: roomId,
        messageId: user.id,
      );
      messages = await repository.messagesForRoom(roomId);
      interruptions = await repository.interruptionsForRoom(roomId);
      error = null;
    } catch (exception) {
      if (!committed && streamingContent.trim().isNotEmpty) {
        await _saveIncompleteReplyDraft(
          userMessageId: user.id,
          content: streamingContent,
          reasoning: _allStreamingReasoning,
        );
        notice = '回复连接异常中断。当前文字尚未进入房间上下文或摘要，请选择“重新生成”或“确认回复”。';
        error = null;
      } else {
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
      await db.releaseLocalLease('immersive_room_lease');
      _safeNotify();
    }
  }

  Future<String> _streamFinalRequest({
    required String internalApiKey,
    required String internalEndpoint,
    required ChatApiProvider finalProvider,
    required String finalApiKey,
    required String finalEndpoint,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> request,
    required GenerationCancellationToken cancellation,
    required bool displayReasoning,
    required bool captureReasoning,
  }) async {
    _lastFinalReplyUsedFallback = false;
    if (!finalProvider.isGeminiRelay) {
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
    Object? lastError;
    if (finalApiKey.isNotEmpty) {
      for (var attempt = 1;
          attempt <= FinalReplyFailurePolicy.maxGeminiAttempts;
          attempt++) {
        try {
          final finishReason = await _streamRequest(
            apiKey: finalApiKey,
            endpoint: finalEndpoint,
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
        'Gemini 调用失败（${FinalReplyFailurePolicy.userCategory(lastError!)}），本轮已由 DeepSeek 兜底。';
    await db.setSetting(_fallbackNoticeSettingKey, notice!);
    _lastFinalReplyUsedFallback = true;
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
      thinking: true,
      maxTokens: 6000,
      cancellationToken: cancellation,
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

  Future<void> _saveIncompleteReplyDraft({
    required String userMessageId,
    required String content,
    required String reasoning,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final createdAt = DateTime.now();
    incompleteReplyUserMessageId = userMessageId;
    incompleteReplyDraft = ImmersiveMessage(
      id: 'pending:$roomId:$userMessageId',
      roomId: roomId,
      role: 'assistant',
      content: trimmed,
      reasoningContent: reasoning.trim(),
      createdAt: createdAt,
    );
    await db.setSetting(
      _pendingReplySettingKey,
      jsonEncode(<String, Object?>{
        'room_id': roomId,
        'user_message_id': userMessageId,
        'content': trimmed,
        'reasoning': reasoning.trim(),
        'created_at': createdAt.millisecondsSinceEpoch,
      }),
    );
  }

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
      incompleteReplyDraft = ImmersiveMessage(
        id: 'pending:$roomId:$userMessageId',
        roomId: roomId,
        role: 'assistant',
        content: content,
        reasoningContent: data['reasoning']?.toString().trim() ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (data['created_at'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
      notice ??= '有一条未完整回复尚未确认；它还没有进入房间上下文或摘要。';
    } catch (_) {
      await _clearIncompleteReplyDraft();
    }
  }

  Future<void> _clearIncompleteReplyDraft() async {
    incompleteReplyDraft = null;
    incompleteReplyUserMessageId = null;
    await db.setSetting(_pendingReplySettingKey, '');
  }

  Future<void> confirmIncompleteReply() async {
    final draft = incompleteReplyDraft;
    if (draft == null || sending) return;
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
    sending = true;
    error = null;
    _safeNotify();
    try {
      final assistant = await repository.addMessage(
        roomId: roomId,
        role: 'assistant',
        content: draft.content,
        reasoningContent: draft.reasoningContent,
      );
      await _clearIncompleteReplyDraft();
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
    } catch (exception) {
      error = '确认这条回复失败：$exception';
    } finally {
      sending = false;
      await db.releaseLocalLease('immersive_room_lease');
      _safeNotify();
    }
  }

  Future<void> regenerateIncompleteReply() async {
    final userMessageId = incompleteReplyUserMessageId;
    if (userMessageId == null || sending || room?.isEnded == true) return;
    final user = messages.cast<ImmersiveMessage?>().firstWhere(
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
    final ownsLease = await db.tryAcquireLocalLease(
      'immersive_room_lease',
      holdFor: const Duration(minutes: 10),
    );
    if (!ownsLease) {
      error = '另一个沉浸房间正在生成，请稍后再试。';
      _safeNotify();
      return;
    }
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
    try {
      final internalEndpoint = await secureConfig.readEndpoint();
      final finalProvider = await secureConfig.readChatProvider();
      final finalApiKey =
          (await secureConfig.readFinalReplyApiKey())?.trim() ?? '';
      final finalEndpoint = await secureConfig.readFinalReplyEndpoint();
      final routedRoom =
          (await repository.inheritActiveSpecialStyleIfNeeded(roomId))!;
      room = routedRoom;
      final historyBeforeTurn = messages
          .where((item) => item.createdAt.isBefore(user.createdAt))
          .toList(growable: false);
      final route = await nsfwRouter.decide(
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
      );
      final profile = DeepSeekModelProfile.fromApiName(
        await db.getSetting('model'),
      );
      final effort = ReasoningEffort.fromApiName(
        await db.getSetting('reasoning_effort'),
      );
      final finishReason = await _streamFinalRequest(
        internalApiKey: internalApiKey,
        internalEndpoint: internalEndpoint,
        finalProvider: finalProvider,
        finalApiKey: finalApiKey,
        finalEndpoint: finalEndpoint,
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
      await repository.addMessage(
        roomId: roomId,
        role: 'assistant',
        content: streamingContent,
        reasoningContent: _allStreamingReasoning,
      );
      messages = await repository.messagesForRoom(roomId);
      room = await repository.roomById(roomId);
      unawaited(_maybeRefreshRollingState(
        apiKey: internalApiKey,
        endpoint: internalEndpoint,
        model: profile,
      ));
    } on _ImmersiveIncompleteReply catch (incomplete) {
      await _saveIncompleteReplyDraft(
        userMessageId: user.id,
        content: incomplete.content,
        reasoning: incomplete.reasoning,
      );
      notice = 'Gemini 回复仍未完整结束。当前文字尚未进入房间上下文或摘要。';
    } catch (exception) {
      if (streamingContent.trim().isNotEmpty) {
        await _saveIncompleteReplyDraft(
          userMessageId: user.id,
          content: streamingContent,
          reasoning: _allStreamingReasoning,
        );
        notice = '回复再次异常中断。当前文字尚未进入房间上下文或摘要。';
      } else {
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
      await db.releaseLocalLease('immersive_room_lease');
      _safeNotify();
    }
  }

  Future<void> stop() async {
    _cancellation?.cancel();
  }

  void dismissNotice() {
    notice = null;
    unawaited(db.setSetting(_fallbackNoticeSettingKey, ''));
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
    await ttsPlayback.stop();
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
              content: ChatSegmentCodec.displayText(translated),
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
    final content = projected.contentFor(language).trim();
    if (content.isEmpty) return;
    await db.setSetting('tts_language', language.key);
    final emotion = await _ttsEmotionCueFor(message);
    await ttsPlayback.playText(
      content,
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
    final resolved = await EmotionClassifierService.instance.resolve(
      rawTag: '',
      visibleText: message.content,
      envelopeStatus: EmotionEnvelopeStatus.missing,
    );
    return TtsEmotionCue(
      key: resolved.key,
      label: resolved.label,
      confidence: resolved.confidence,
      source: resolved.source,
    );
  }

  Future<void> stopSpeech() => ttsPlayback.stop();

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
    await db.setSetting(_fallbackNoticeSettingKey, '');
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
    if (sending || ending || room == null || room!.isEnded) return false;
    if (incompleteReplyDraft != null) {
      error = '请先处理待确认的截断回复，再整理结束房间。';
      _safeNotify();
      return false;
    }
    final apiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) {
        error = '结束房间前需要用所选聊天模型整理归档，请先填写 API Key。';
      _safeNotify();
      return false;
    }
    ending = true;
    error = null;
    _safeNotify();
    try {
      final transcript = _summaryTranscript(messages, maxCharacters: 26000);
      final result = await client.jsonCompletion(
        apiKey: apiKey,
        model: DeepSeekModelProfile.fromApiName(await db.getSetting('model')),
        endpoint: await secureConfig.readEndpoint(),
        thinking: false,
        maxTokens: 2200,
        messages: [
          {
            'role': 'system',
            'content': '''你在整理一个已经结束的独立沉浸房间。只输出 JSON：
{"archive_summary":"供房间归档继续回看的剧情摘要","scene_ledger":"结束时的地点、人物、姿势、衣物、当前阶段、身体状态和未完成事件","shared_memories":["0至3条可让普通聊天知道的简短共同经历"]}
archive_summary 和 scene_ledger 中提及用户时统一写“用户”，不得写成“他”或替用户新增台词、主动动作、内心、态度、同意、意图和决定。可以记录原文中已经发生的用户输入，以及由AI行为直接造成、原文已经写出的生理或被动身体反馈。
archive_summary 可以相对详细但去除重复描写。shared_memories 只保留真正重要的共同经历、稳定偏好、关系变化或约定；不得把临时姿势、角色身份、露骨动作流水账或虚构场景当成现实事实。没有值得共享的内容就返回空数组。''',
          },
          {
            'role': 'user',
            'content': '''房间标题：${room!.title}
本房间固定特殊风格：${room!.specialStyleKey.isEmpty ? '无' : room!.specialStyleKey}（只作为临时体验来源，不是永久AI Self或现实身体）
已有滚动摘要：${room!.rollingSummary}
已有现场账：${room!.sceneLedger}

房间原文：
$transcript''',
          },
        ],
      );
      final archive = result['archive_summary']?.toString().trim() ?? '';
      if (archive.isEmpty) throw const FormatException('归档摘要为空');
      final ledger = result['scene_ledger']?.toString().trim() ?? '';
      final rawMemories = result['shared_memories'];
      final shared = rawMemories is List
          ? rawMemories
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .take(3)
              .toList(growable: false)
          : const <String>[];
      await repository.endRoom(
        roomId: roomId,
        archiveSummary: archive,
        sceneLedger: ledger,
        sharedMemories: shared,
      );
      room = await repository.roomById(roomId);
      return true;
    } catch (exception) {
      error = '房间没有结束：归档整理失败，原始记录仍完整保留。$exception';
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
        maxTokens: 1600,
        messages: [
          {
            'role': 'system',
            'content': '''只输出 JSON：{"rolling_summary":"按事件顺序合并旧摘要与新增剧情，去掉重复感官和重复动作，保留变化、承诺与未完成事件","scene_ledger":"当前地点、时间、人物、姿势、衣物、接触点、阶段、身体状态、未完成事件"}。不得把虚构房间写成现实事实。摘要和现场账提及用户时统一写“用户”，不得写成“他”；不得替用户新增台词、主动动作、内心、态度、同意、意图或决定。可以记录用户明确输入的事实，以及原文已经出现的生理和被动身体反馈。''',
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
      if (used + message.content.length > maxCharacters && selected.isNotEmpty) {
        break;
      }
      selected.add(message);
      used += message.content.length;
    }
    return selected.reversed
        .map(
          (message) =>
              '${message.isUser ? '用户输入' : 'AI正文'}：${message.content}',
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
