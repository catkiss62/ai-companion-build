import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/first_channel_model.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_arrangements.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_live_share_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/tts/proactive_speech_delivery.dart';
import 'package:ai_companion_localfirst/core/tts/emotion_sound_service.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';

class _BlockedKey extends SecureConfig {
  _BlockedKey() : super.forTesting(const FlutterSecureStorage());
  final entered = Completer<void>();
  final key = Completer<String?>();
  @override Future<String?> readApiKey() {
    if (!entered.isCompleted) entered.complete();
    return key.future;
  }
}

class _StoppedSound extends EmotionSoundService {
  _StoppedSound(AppDatabase db) : super(db: db);
  final entered = Completer<void>();
  final release = Completer<void>();
  @override Future<void> stop() {
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const system = MethodChannel('ai_companion/system');
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    messenger.setMockMethodCallHandler(system, (c) async =>
        c.method == 'runtimeProcessEpoch' ? 'stability378' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async {
    await db.closeForTesting();
    messenger.setMockMethodCallHandler(system, null);
  });

  final invalidSnapshots = <Object?>[
    {'data': [{'slot': 2, 'inventory': []}]},
    jsonEncode({'slot': 2, 'balance': 0}),
    {'data': jsonEncode({'slot': 2, 'balance': 0})},
    [{'slot': 1, 'inventory': []}, {'snapshot': {'slot_id': 2, 'balance': 0}}],
    {'data': {'ok': false, 'message': 'temporarily unavailable'}},
    {'data': {'ok': true, 'error': false}},
    {'result': [{'errors': ['offline'], 'inventory': []}]},
  ];
  for (var index = 0; index < invalidSnapshots.length; index++) {
    test('real unknown-dispatch reconciliation rejects nested wrong identity/ack/refusal $index', () async {
      final activity = CedarToyActivityStore(db);
      await activity.recordGuide(gameId: 'bar', guide: '每游戏5槽，slot=1-5，cmd status serve');
      final execution = await activity.beginExecution(gameId: 'bar', action: 'cmd');
      expect(await activity.admitRemoteDispatch(gameId: 'bar', action: 'cmd',
          params: {'command': 'serve new', 'slot': 1}, executionId: execution), true);
      await activity.resolveRemoteDispatch(gameId: 'bar', executionId: execution,
          action: 'cmd', authoritative: true, params: {'command': 'status', 'slot': 1},
          outcome: McpToolOutcome(content: [], isError: false, structuredContent: invalidSnapshots[index]));
      expect(await activity.unresolvedWrite('bar'), isNotNull);
      await activity.resolveRemoteDispatch(gameId: 'bar', executionId: execution,
          action: 'cmd', authoritative: true, params: {'command': 'status', 'slot': 1},
          outcome: const McpToolOutcome(content: [], isError: false,
            structuredContent: {'data': [{'slot': 1, 'inventory': [], 'balance': 0}]}));
      expect(await activity.unresolvedWrite('bar'), isNull);
    });
  }
  test('entity slots are not confused with the save envelope', () {
    expect(CedarStateSnapshotPolicy.accepts(const McpToolOutcome(content: [], isError: false,
      structuredContent: {'slot': 1, 'inventory': [{'slot': 2, 'name': 'item'}]}), {'slot': 1}), true);
  });

  test('full target/fingerprint survives long display JSON and query is absent from final reports/shares', () async {
    final activity = CedarToyActivityStore(db);
    await activity.recordGuide(gameId: 'bar', guide: '每游戏5槽，slot=1-5，cmd status serve');
    final params = <String, Object?>{'padding': List.filled(2500, 'x').join(), 'slot': 4, 'command': 'status'};
    final session = await activity.recordPlay(gameId: 'bar', action: 'cmd', submittedParams: params,
      mode: CedarParticipationMode.solo, nextActor: 'companion', shareLevel: 'quiet', invitationApproved: true,
      outcome: const McpToolOutcome(content: [], isError: false, structuredContent: {'balance': 0}));
    final event = session.events.last;
    expect(event.inputJson.length, lessThan(jsonEncode(params).length));
    final restored = CedarGameSession.fromJson(session.toJson());
    expect(CedarArrangementScope.slotForEvent(restored, restored.events.last), '4');
    expect(restored.repeatsUnchangedRead('cmd', params), true);
    expect(restored.repeatsUnchangedRead('cmd', {...params, 'slot': 3}), false);
    expect(CedarLiveSharePolicy.evidence(restored, DateTime.now()), isEmpty);
    final old = CedarGameEvent(id: 'old', kind: 'outcome', summary: '成功', createdAt: DateTime.now(),
      action: 'cmd', inputJson: '{"padding":"unfinished');
    expect(CedarArrangementScope.slotForEvent(restored, old), '');
    final task = <String, dynamic>{'id': 'read-only-task', 'gameId': 'bar', 'sessionId': session.id,
      'startedAt': 1, 'progressCount': 0};
    final sql = await db.database;
    await sql.transaction((txn) => CedarTimedPlayTaskStore.finishInTransaction(txn, task,
      usedMs: 1000, reason: 'budget_complete', now: DateTime.now()));
    final report = (await CedarTimedPlayTaskStore(db).pendingReports()).single;
    expect(report['progressCount'], 0);
    expect(report['reason'], 'no_progress');
  });

  test('stop during real Key preflight prevents commit without cancelling a later external turn', () async {
    final secure = _BlockedKey();
    final chat = ChatController(db: db, secureConfig: secure, externalRecoveryOrchestrator: true);
    final sending = chat.sendText('尚未提交', requestedMessageId: 'old');
    await secure.entered.future;
    expect(chat.generationActive, true);
    await chat.cancelCurrentGeneration();
    final later = await db.createGenerationTurn(user: ChatMessage(id: 'new', role: 'user',
      content: '另一窗口的新消息', createdAt: DateTime.now()), assistantMessageId: 'a-new',
      model: 'deepseek-flash', reasoningEffort: 'high');
    secure.key.complete('fixture');
    expect(await sending, false);
    expect(await db.messageById('old'), isNull);
    expect((await db.generationJobById(later.id))!.status, 'pending');
    chat.dispose();
  });

  test('delayed old audio stop cannot cancel a newer cross-window job', () async {
    final old = await db.createGenerationTurn(user: ChatMessage(id: 'old-u', role: 'user',
      content: '旧消息', createdAt: DateTime.now()), assistantMessageId: 'old-a',
      model: 'deepseek-flash', reasoningEffort: 'high');
    final sound = _StoppedSound(db);
    final chat = ChatController(db: db, emotionSoundService: sound, externalRecoveryOrchestrator: true);
    await chat.syncExternalMessages();
    expect(chat.generationJobId, old.id);
    final stop = chat.cancelCurrentGeneration();
    await sound.entered.future;
    final newer = await db.createGenerationTurn(user: ChatMessage(id: 'new-u', role: 'user',
      content: '新窗口的新消息', createdAt: DateTime.now()), assistantMessageId: 'new-a',
      model: 'deepseek-flash', reasoningEffort: 'high');
    sound.release.complete(); await stop;
    expect((await db.generationJobById(old.id))!.status, 'cancelled_by_user');
    expect((await db.generationJobById(newer.id))!.status, 'pending');
    chat.dispose();
  });

  test('job records isolate first/final effort and archived work connections survive changes', () async {
    await db.setSettingsAtomically({'deepseek_reasoning_effort': 'max', 'reasoning_effort': 'low'});
    final job = await db.createGenerationTurn(user: ChatMessage(id: 'u', role: 'user',
      content: '测试', createdAt: DateTime.now()), assistantMessageId: 'a', model: 'custom-first', reasoningEffort: 'high');
    expect(job.reasoningEffort, 'max');
    expect(await db.getSetting('generation_final_effort_v1:${job.id}'), 'low');
    await db.setSetting('reasoning_effort', 'high');
    expect(await db.getSetting('generation_final_effort_v1:${job.id}'), 'low');
    expect((await FirstChannelModel.readEffort(db)).apiName, 'max');
    final secure = SecureConfig.instance;
    await secure.writeWorkConfiguration(independent: true, apiKey: 'work-one', endpoint: 'https://one.invalid/chat');
    final first = (await secure.workConnection())!;
    await secure.writeWorkConfiguration(independent: true, apiKey: 'work-two', endpoint: 'https://two.invalid/chat');
    final resumed = (await secure.workConnection(profileId: first.id))!;
    expect(resumed.apiKey, 'work-one');
    expect(resumed.endpoint, 'https://one.invalid/chat');
    expect((await secure.workConnection())!.apiKey, 'work-two');
    expect(await secure.workConnection(profileId: 'missing'), isNull);
  });

  Future<ChatMessage> proactive(String id, {int offset = 0}) async {
    final message = ChatMessage(id: id, role: 'assistant', content: '主动消息', isProactive: true,
      createdAt: DateTime.now().add(Duration(seconds: offset)));
    await db.insertMessage(message);
    return message;
  }
  test('App and overlay claim only one speech; failed preparation can retry on next open', () async {
    final message = await proactive('p');
    final app = ProactiveSpeechDelivery(db), overlay = ProactiveSpeechDelivery(db);
    final entered = Completer<void>(), result = Completer<bool>();
    var calls = 0;
    final first = app.deliver(message, play: () { calls++; entered.complete(); return result.future; });
    await entered.future;
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), isNot('p'));
    await overlay.deliver(message, play: () async { calls++; return true; });
    expect(calls, 1);
    result.complete(false); await first;
    await overlay.deliver(message, play: () async { calls++; return true; });
    expect(calls, 2);
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), 'p');
    await app.deliver(message, play: () async { calls++; return true; });
    expect(calls, 2);
  });
  test('manual Stop consumes its captured message; late old completion cannot consume a newer claim', () async {
    final old = await proactive('old');
    final app = ProactiveSpeechDelivery(db), overlay = ProactiveSpeechDelivery(db);
    final entered = Completer<void>(), result = Completer<bool>();
    final first = app.deliver(old, play: () { entered.complete(); return result.future; });
    await entered.future;
    await app.stopRequested();
    result.complete(false); await first;
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), 'old');
    final newer = await proactive('new', offset: 1);
    await overlay.deliver(newer, play: () async => true);
    await app.deliver(old, play: () async => throw StateError('stale message must not play'));
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), 'new');
  });
  test('late old speech completion cannot replace the newer delivery record', () async {
    final old = await proactive('old-inflight');
    final first = ProactiveSpeechDelivery(db), second = ProactiveSpeechDelivery(db);
    final entered = Completer<void>(), finished = Completer<bool>();
    final running = first.deliver(old, play: () { entered.complete(); return finished.future; });
    await entered.future;
    final newer = await proactive('new-inflight', offset: 1);
    await second.deliver(newer, play: () async => true);
    finished.complete(true); await running;
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), newer.id);
  });

  test('hidden page and thrown preparation never consume a proactive message', () async {
    final message = await proactive('hidden');
    final speech = ProactiveSpeechDelivery(db);
    var calls = 0;
    await speech.deliver(message, canStart: () => false, play: () async { calls++; return true; });
    expect(calls, 0);
    await speech.deliver(message, play: () async => throw StateError('no audio'));
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), isNot(message.id));
    await speech.deliver(message, play: () async => true);
    expect(await db.getSetting(ProactiveSpeechDelivery.spokenKey), message.id);
  });
}
