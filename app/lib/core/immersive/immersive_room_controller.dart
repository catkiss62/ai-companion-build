import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../models/immersive_room.dart';
import '../storage/secure_config.dart';
import '../tts/tts_playback_queue.dart';
import '../tts/tts_service.dart';
import 'immersive_nsfw_router.dart';
import 'immersive_prompt_builder.dart';
import 'immersive_room_repository.dart';

class ImmersiveRoomController extends ChangeNotifier {
  ImmersiveRoomController({
    required this.roomId,
    AppDatabase? db,
    DeepSeekClient? client,
    SecureConfig? secureConfig,
  })  : db = db ?? AppDatabase.instance,
        client = client ?? DeepSeekClient(),
        secureConfig = secureConfig ?? SecureConfig.instance {
    repository = ImmersiveRoomRepository(this.db);
    promptBuilder = ImmersivePromptBuilder(this.db);
    nsfwRouter = ImmersiveNsfwRouter(this.client);
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
  late final ImmersivePromptBuilder promptBuilder;
  late final ImmersiveNsfwRouter nsfwRouter;
  late final TtsService ttsService;
  late final TtsPlaybackQueue ttsPlayback;

  ImmersiveRoom? room;
  List<ImmersiveMessage> messages = const [];
  bool loading = true;
  bool sending = false;
  bool ending = false;
  bool nsfwRouting = false;
  String streamingReasoning = '';
  String streamingContent = '';
  TtsQueueState ttsState = TtsQueueState.idle;
  String? error;
  GenerationCancellationToken? _cancellation;
  bool _streamingDraftVisible = false;
  String _allStreamingReasoning = '';
  Timer? _streamNotifyTimer;
  bool _disposed = false;

  bool get showStreamingDraft => sending && _streamingDraftVisible;

  TtsPlaybackPhase ttsPhaseForMessage(String messageId) {
    if (ttsState.ownerId != messageId) return TtsPlaybackPhase.idle;
    return ttsState.phase;
  }

  Future<void> initialize() async {
    room = await repository.roomById(roomId);
    if (room == null) {
      error = '这个房间不存在或已经无法读取。';
    } else {
      messages = await repository.messagesForRoom(roomId);
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
    _safeNotify();
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    final currentRoom = room;
    if (text.isEmpty || sending || currentRoom == null || currentRoom.isEnded) {
      return;
    }
    final apiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) {
      error = '请先到“更多”→“AI 与陪伴设置”填写 DeepSeek API Key。';
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
      var finishReason = await _streamRequest(
        apiKey: apiKey,
        endpoint: endpoint,
        model: profile,
        effort: effort,
        request: request,
        cancellation: cancellation,
        displayReasoning: true,
      );
      cancellation.throwIfCancelled();

      final fastForward = text.contains('[动作加速]') || text.contains('[场景快进]');
      final minimum = fastForward ? 400 : 1000;
      if (_visibleCharacterCount(streamingContent) < minimum &&
          (finishReason.isEmpty || finishReason == 'stop' || finishReason == 'length')) {
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
      if ((await db.getSetting('tts_enabled')) != '0' &&
          (await db.getSetting('auto_tts')) != '0') {
        unawaited(ttsPlayback.playText(
          assistant.content,
          manual: false,
          ownerId: assistant.id,
        ));
      }
      unawaited(_maybeRefreshRollingState(
        apiKey: apiKey,
        endpoint: endpoint,
        model: profile,
      ));
    } on GenerationCancelledByUserException {
      await _commitVisiblePartial();
      committed = true;
      error = null;
    } catch (exception) {
      if (!committed) await _commitVisiblePartial();
      error = '这一轮没有完整结束：$exception';
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

  Future<String> _streamRequest({
    required String apiKey,
    required String endpoint,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> request,
    required GenerationCancellationToken cancellation,
    required bool displayReasoning,
  }) async {
    var finishReason = '';
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
        _allStreamingReasoning += delta.reasoning;
        if (displayReasoning) streamingReasoning += delta.reasoning;
      }
      if (delta.content.isNotEmpty) {
        streamingContent += delta.content;
      }
      if (delta.finishReason != null) finishReason = delta.finishReason!;
      if (delta.content.isNotEmpty ||
          (displayReasoning && delta.reasoning.isNotEmpty)) {
        _scheduleStreamNotify();
      }
    }
    _flushStreamNotify();
    return finishReason;
  }

  Future<void> _commitVisiblePartial() async {
    final content = streamingContent.trim();
    if (content.isEmpty) return;
    final assistant = await repository.addMessage(
      roomId: roomId,
      role: 'assistant',
      content: content,
      reasoningContent: _allStreamingReasoning,
    );
    messages = [...messages, assistant];
  }

  Future<void> stop() async {
    _cancellation?.cancel();
  }

  Future<void> speakMessage(ImmersiveMessage message) async {
    if (!message.isAssistant || message.content.trim().isEmpty) return;
    await ttsPlayback.playText(
      message.content,
      manual: true,
      ownerId: message.id,
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
    await repository.deleteRoom(roomId);
    room = null;
    messages = const [];
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
    final apiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) {
      error = '结束房间前需要用 DeepSeek 整理归档，请先填写 API Key。';
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

  static int _visibleCharacterCount(String value) =>
      value.runes
          .where((rune) => String.fromCharCode(rune).trim().isNotEmpty)
          .length;

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
