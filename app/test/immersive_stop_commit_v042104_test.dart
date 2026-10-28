import 'package:ai_companion_localfirst/core/ai/final_reply_route.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/models/immersive_room.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _barrierTimeout = Duration(seconds: 10);

/// A failed or prematurely completed operation cannot leave the test waiting
/// for a signal it will never emit. Errors from either future still fail the test.
Future<void> _waitForBarrier(
    Future<void> signal, Future<void> operation, String phase) async {
  await Future.any<void>([
    signal,
    operation.then<void>((_) {
      throw StateError('$phase: operation completed before reaching the barrier');
    }),
  ]).timeout(_barrierTimeout);
}

/// Call only after releasing the gate, including from finally. Observe both
/// futures together so one failure cannot skip cleanup of the other operation.
/// A secondary cleanup error must not replace an already propagating body error.
Future<void> _settleBarrierOperations(Future<void> operation,
    {Future<void>? blocker, bool preservePrimaryError = false}) async {
  try {
    await Future.wait<void>([
      if (blocker != null) blocker,
      operation,
    ]).timeout(_barrierTimeout);
  } catch (_) {
    if (!preservePrimaryError) rethrow;
  }
}

class _ReplyClient extends DeepSeekClient {
  _ReplyClient({this.truncate = false});
  final bool truncate;
  @override
  Stream<DeepSeekDelta> streamChat({
    required String apiKey, required DeepSeekModelProfile model,
    required ReasoningEffort effort, required List<Map<String, Object?>> messages,
    String endpoint = DeepSeekClient.defaultEndpoint, ChatApiProvider? requestProvider,
    String? modelName, bool thinking = true, int? maxTokens,
    List<Map<String, Object?>> tools = const [], String? toolChoice,
    GenerationCancellationToken? cancellationToken,
    Duration requestTimeout = const Duration(seconds: 120),
    String usageLane = 'unclassified', String usageExecutionId = '',
    FinalReplyRoute? finalReplyRoute, SecureConfig? thirdChannelSecure,
    GenerationCancellationToken? thirdCancellationToken,
    Future<bool> Function()? thirdChannelCurrent,
  }) async* {
    yield const DeepSeekDelta(content: '她轻轻点头。');
    if (!truncate) yield const DeepSeekDelta(done: true, finishReason: 'stop');
  }
}

/// Keeps production repository admission/SQLite writes. Only operation timing
/// is controlled; no success result, ownership decision or transaction is faked.
class _ObservedRepository extends ImmersiveRoomRepository {
  _ObservedRepository(super.db, {super.beforeAssistantCommit, super.beforeDraftCommit});
  Future<void> Function()? beforeSubmission;
  Future<void> Function()? afterCommit;
  Future<void> Function()? beforeDraftSubmission;
  final draftSubmitted = Completer<void>();
  final submitted = Completer<void>();
  @override
  Future<ImmersiveMessage> addAssistantReply({
    required String roomId, required ImmersiveMessage sourceUser,
    required GenerationCancellationToken cancellation, required BrainWorkFence workFence,
    required String content,
    String reasoningContent = '', String formContextJson = '', String? expectedDraft,
    Map<String, Object?>? modelRoute,
  }) async {
    await beforeSubmission?.call();
    final pending = super.addAssistantReply(roomId: roomId, sourceUser: sourceUser,
      cancellation: cancellation, workFence: workFence, content: content, reasoningContent: reasoningContent,
      formContextJson: formContextJson, expectedDraft: expectedDraft, modelRoute: modelRoute);
    submitted.complete();
    final message = await pending;
    await afterCommit?.call();
    return message;
  }
  @override
  Future<void> saveIncompleteReply({required String roomId,
    required ImmersiveMessage sourceUser, required GenerationCancellationToken cancellation,
    required BrainWorkFence workFence, required String rawDraft}) async {
    await beforeDraftSubmission?.call();
    final pending = super.saveIncompleteReply(roomId: roomId, sourceUser: sourceUser,
      cancellation: cancellation, workFence: workFence, rawDraft: rawDraft);
    draftSubmitted.complete();
    await pending;
  }

}

/// Observes the real nested controller calls after the delegate returns but
/// before the owning regenerateLatestReply finally can run.
class _DelegationObservedController extends ImmersiveRoomController {
  _DelegationObservedController({required super.roomId, required super.db,
    required super.client, this.forceEarlyReturn = false});
  final bool forceEarlyReturn;
  String? leaseAtDelegateReturn;
  bool? acquiredBetweenOwners;
  @override
  Future<void> regenerateIncompleteReply({bool leaseAlreadyHeld = false}) async {
    if (forceEarlyReturn) FlutterSecureStorage.setMockInitialValues({});
    await super.regenerateIncompleteReply(leaseAlreadyHeld: leaseAlreadyHeld);
    leaseAtDelegateReturn = await db.getSetting('immersive_room_lease');
    acquiredBetweenOwners = await db.tryAcquireLocalLease('immersive_room_lease');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late ImmersiveRoomRepository repository;
  late ImmersiveRoom room;
  final controllers = <ImmersiveRoomController>[];
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture-key'});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting('tts_enabled', '0');
    repository = ImmersiveRoomRepository(db);
    room = await repository.createRoom(title: 'Stop 事务测试', openingScene: '', inheritCurrentChat: false);
    await repository.setNsfwManualOverride(room.id, false);
  });
  tearDown(() async {
    for (final controller in controllers) { controller.dispose(); }
    controllers.clear();
    await db.closeForTesting();
    FlutterSecureStorage.setMockInitialValues({});
  });
  String draftKey() => 'immersive_pending_reply_${Uri.encodeComponent(room.id)}';
  Future<void> roomMarker() async {
    await (await db.database).update('immersive_rooms', {'updated_at': 42},
      where: 'id = ?', whereArgs: [room.id]);
  }
  Future<ImmersiveMessage> seedDraft({bool withSource = true}) async {
    final user = await repository.addMessage(roomId: room.id, role: 'user', content: '原始请求');
    await db.setSetting(draftKey(), jsonEncode({
      'room_id': room.id, 'user_message_id': user.id, 'content': '可见截断草稿。',
      'reasoning': '', 'created_at': 5,
      if (withSource) 'source_user': {
        'id': user.id, 'room_id': user.roomId, 'role': 'user', 'content': user.content,
        'reasoning_content': user.reasoningContent, 'form_context_json': user.formContextJson,
        'created_at': user.createdAt.millisecondsSinceEpoch,
      },
    }));
    return user;
  }
  Future<ImmersiveRoomController> controllerFor(_ObservedRepository observed,
      {bool truncate = false}) async {
    final controller = ImmersiveRoomController(roomId: room.id, db: db,
      client: _ReplyClient(truncate: truncate), roomRepository: observed);
    controllers.add(controller);
    await controller.initialize();
    return controller;
  }
  Future<void> start(ImmersiveRoomController controller, String path) => switch (path) {
    'send' => controller.send('新的用户请求'),
    'regenerate' => controller.regenerateIncompleteReply(),
    'regenerateLatest' => controller.regenerateLatestReply(controller.messages.last),
    _ => controller.confirmIncompleteReply(),
  };
  Future<void> seedExisting(String path) async {
    if (path == 'send') return;
    if (path != 'regenerateLatest') {
      await seedDraft();
      return;
    }
    final user = await repository.addMessage(roomId: room.id, role: 'user', content: '已完成回复的用户请求');
    final assistant = await repository.addMessage(roomId: room.id, role: 'assistant', content: '即将被重新生成的回复。');
    final sql = await db.database;
    // Explicit chronology avoids timestamp ties in the legacy regeneration query.
    await sql.update('immersive_messages', {'created_at': 2}, where: 'id = ?', whereArgs: [user.id]);
    await sql.update('immersive_messages', {'created_at': 3}, where: 'id = ?', whereArgs: [assistant.id]);
  }

  for (final path in ['send', 'regenerate', 'regenerateLatest', 'confirm']) {
    for (final cut in ['queued', 'afterWrites']) {
      test('$path: Stop at $cut rolls back assistant, room timestamp and draft consumption', () async {
        // An unrelated earlier accepted fact must survive this turn's Stop.
        final prior = await repository.addMessage(roomId: room.id, role: 'assistant', content: '已经发生的房间事实。');
        await (await db.database).update('immersive_messages', {'created_at': 1},
          where: 'id = ?', whereArgs: [prior.id]);
        await seedExisting(path);
        final initialDraft = await db.getSetting(draftKey());
        final entered = Completer<void>();
        final release = Completer<void>();
        Future<void>? blocking;
        final observed = _ObservedRepository(db, beforeAssistantCommit: cut == 'afterWrites'
          ? (txn) async {
              final tentative = await txn.query('immersive_messages', where: "room_id = ? AND role = 'assistant'", whereArgs: [room.id]);
              expect(tentative, hasLength(2));
              if (path == 'confirm') {
                expect((await txn.query('settings', where: 'key = ?', whereArgs: [draftKey()])).single['value'], '');
              }
              entered.complete();
              await release.future.timeout(_barrierTimeout);
            }
          : null);
        observed.beforeSubmission = () async {
          if (cut == 'queued') {
            final sql = await db.database;
            blocking = sql.transaction((txn) async {
              await txn.update('immersive_rooms', {'updated_at': 42}, where: 'id = ?', whereArgs: [room.id]);
              entered.complete();
              await release.future.timeout(_barrierTimeout);
            });
            await _waitForBarrier(entered.future, blocking!, 'SQLite predecessor');
          } else {
            await roomMarker();
          }
        };
        final controller = await controllerFor(observed);
        final pending = start(controller, path);
        var bodyFailed = false;
        try {
          await _waitForBarrier(observed.submitted.future, pending, 'assistant submission');
          await _waitForBarrier(entered.future, pending, 'transaction writes');
          await controller.stop().timeout(_barrierTimeout); // synchronously signals; DB queue is still held
          release.complete();
          await _settleBarrierOperations(pending, blocker: blocking);
          final messages = await repository.messagesForRoom(room.id);
          expect(messages.where((message) => message.isAssistant).map((message) => message.id), [prior.id]);
          expect((await repository.roomById(room.id))!.updatedAt.millisecondsSinceEpoch, 42);
          if (path == 'confirm') {
            expect(await db.getSetting(draftKey()), initialDraft);
            expect(controller.incompleteReplyDraft, isNotNull);
            expect(messages.where((message) => message.isUser), hasLength(1));
            expect(await repository.interruptionsForRoom(room.id), isEmpty);
          } else {
            expect(messages.where((message) => message.isUser), isEmpty);
            expect(await repository.interruptionsForRoom(room.id), hasLength(1));
            expect(await db.getSetting(draftKey()) ?? '', '');
          }
          expect(controller.error, isNull);
        } catch (_) {
          bodyFailed = true;
          rethrow;
        } finally {
          if (!release.isCompleted) release.complete();
          await _settleBarrierOperations(pending, blocker: blocking,
            preservePrimaryError: bodyFailed);
        }
      });
    }
    test('$path: a committed reply survives Stop before the controller receives it', () async {
      await seedExisting(path);
      final committed = Completer<void>();
      final release = Completer<void>();
      final observed = _ObservedRepository(db)..afterCommit = () async {
        committed.complete();
        await release.future.timeout(_barrierTimeout);
      };
      final controller = await controllerFor(observed);
      final pending = start(controller, path);
      var bodyFailed = false;
      try {
        await _waitForBarrier(committed.future, pending, 'assistant committed');
        await controller.stop().timeout(_barrierTimeout);
        release.complete();
        await _settleBarrierOperations(pending);
        final messages = await repository.messagesForRoom(room.id);
        expect(messages.where((message) => message.isUser), hasLength(1));
        expect(messages.where((message) => message.isAssistant), hasLength(1));
        expect(await repository.interruptionsForRoom(room.id), isEmpty);
        expect(await db.getSetting(draftKey()) ?? '', '');
        expect(controller.error, isNull);
      } catch (_) {
        bodyFailed = true;
        rethrow;
      } finally {
        if (!release.isCompleted) release.complete();
        await _settleBarrierOperations(pending,
          preservePrimaryError: bodyFailed);
      }
    });
  }

  for (final change in ['sourceContent', 'sourceDeleted', 'endedRoom', 'restoredSameRoomId', 'draftReplaced']) {
    test('confirmation refuses $change after admission without half-consuming the draft', () async {
      final source = await seedDraft();
      final originalDraft = await db.getSetting(draftKey());
      final observed = _ObservedRepository(db)..beforeSubmission = () async {
        await roomMarker();
        final sql = await db.database;
        switch (change) {
          case 'sourceContent':
            await sql.update('immersive_messages', {'content': '改过的同 ID 来源'}, where: 'id = ?', whereArgs: [source.id]);
            break;
          case 'sourceDeleted':
            await sql.delete('immersive_messages', where: 'id = ?', whereArgs: [source.id]);
            break;
          case 'endedRoom':
            await sql.update('immersive_rooms', {'status': 'ended'}, where: 'id = ?', whereArgs: [room.id]);
            break;
          case 'restoredSameRoomId':
            // Same room/user rows are present, but restoration changed identity.
            await db.setSetting('runtime_state_epoch_v1', 'restored-epoch');
            break;
          case 'draftReplaced':
            await db.setSetting(draftKey(), 'new-draft-owned-by-another-operation');
            break;
        }
      };
      final controller = await controllerFor(observed);
      await controller.confirmIncompleteReply();
      expect((await repository.messagesForRoom(room.id)).where((message) => message.isAssistant), isEmpty);
      expect((await repository.roomById(room.id))!.updatedAt.millisecondsSinceEpoch, 42);
      expect(await db.getSetting(draftKey()), change == 'draftReplaced' ? 'new-draft-owned-by-another-operation' : originalDraft);
      expect(controller.incompleteReplyDraft, isNotNull);
      expect(controller.error, isNotNull);
    });
  }

  for (final earlyReturn in [false, true]) {
    test('latest regeneration ${earlyReturn ? 'early return' : 'completion'} retains its lease until the owning call returns', () async {
      await seedExisting('regenerateLatest');
      final controller = _DelegationObservedController(roomId: room.id, db: db,
        client: _ReplyClient(), forceEarlyReturn: earlyReturn);
      controllers.add(controller);
      await controller.initialize();
      await controller.regenerateLatestReply(controller.messages.last);
      expect(controller.leaseAtDelegateReturn, isNotNull);
      expect(controller.leaseAtDelegateReturn, isNot('0'));
      expect(controller.acquiredBetweenOwners, isFalse);
      expect(await db.getSetting('immersive_room_lease'), '0');
      expect(await db.tryAcquireLocalLease('immersive_room_lease'), isTrue);
      final nextFence = await db.captureBrainWorkFence(leaseKey: 'immersive_room_lease');
      expect(nextFence, isNotNull);
      expect(await nextFence!.matches(await db.database), isTrue);
      await db.releaseLocalLease('immersive_room_lease');
    });
  }

  for (final path in ['send', 'regenerate']) {
    for (final relay in [false, true]) {
      for (final cut in ['queued', 'afterWrites']) {
        test('$path ${relay ? 'relay' : 'internal'} truncated catch: late Stop at draft $cut cannot save a new confirmable reply', () async {
          if (path == 'regenerate') await seedDraft();
          await db.setSetting('immersive_model_source_v1', relay ? 'second' : 'first');
          FlutterSecureStorage.setMockInitialValues({
            'deepseek_api_key': 'fixture-key',
            if (relay) 'aiwangyou_final_reply_model': 'gemini-fixture',
            if (relay) 'chat_api_provider': 'aiwangyou_gemini',
            if (relay) 'aiwangyou_gemini_api_key': 'fixture-relay-key',
          });
          final entered = Completer<void>();
          final release = Completer<void>();
          Future<void>? blocking;
          final observed = _ObservedRepository(db, beforeDraftCommit: cut == 'afterWrites'
            ? (txn) async {
                expect((await txn.query('settings', where: 'key = ?', whereArgs: [draftKey()])).single['value'], isNotEmpty);
                entered.complete();
                await release.future.timeout(_barrierTimeout);
              }
            : null);
          observed.beforeDraftSubmission = () async {
            if (cut == 'queued') {
              blocking = (await db.database).transaction((txn) async {
                entered.complete();
                await release.future.timeout(_barrierTimeout);
              });
              await _waitForBarrier(entered.future, blocking!, 'SQLite predecessor');
            }
          };
          final controller = ImmersiveRoomController(roomId: room.id, db: db,
            client: _ReplyClient(truncate: true), roomRepository: observed);
          controllers.add(controller);
          await controller.initialize();
          final pending = start(controller, path);
          var bodyFailed = false;
          try {
            await _waitForBarrier(observed.draftSubmitted.future, pending, 'draft submission');
            await _waitForBarrier(entered.future, pending, 'transaction writes');
            await controller.stop().timeout(_barrierTimeout);
            release.complete();
            await _settleBarrierOperations(pending, blocker: blocking);
            expect(await db.getSetting(draftKey()) ?? '', '');
            expect(controller.incompleteReplyDraft, isNull);
            expect(await repository.messagesForRoom(room.id), isEmpty);
            expect(await repository.interruptionsForRoom(room.id), hasLength(1));
            expect(controller.error, isNull);
          } catch (_) {
            bodyFailed = true;
            rethrow;
          } finally {
            if (!release.isCompleted) release.complete();
            await _settleBarrierOperations(pending, blocker: blocking,
              preservePrimaryError: bodyFailed);
          }
        });
      }
    }
    for (final change in ['sourceContent', 'endedRoom', 'restoredSameRoomId']) {
      test('$path rejects $change without converting the rejected assistant into a draft', () async {
        if (path == 'regenerate') await seedDraft();
        final observed = _ObservedRepository(db)..beforeSubmission = () async {
          if (change == 'sourceContent') {
            await (await db.database).update('immersive_messages', {'content': '新来源'},
              where: "room_id = ? AND role = 'user'", whereArgs: [room.id]);
          } else if (change == 'endedRoom') {
            await (await db.database).update('immersive_rooms', {'status': 'ended'},
              where: 'id = ?', whereArgs: [room.id]);
          } else {
            await db.setSetting('runtime_state_epoch_v1', 'restored-epoch');
          }
        };
        final controller = await controllerFor(observed);
        await start(controller, path);
        expect((await repository.messagesForRoom(room.id)).where((message) => message.isAssistant), isEmpty);
        expect(await db.getSetting(draftKey()) ?? '', '');
        expect(controller.incompleteReplyDraft, isNull);
        expect(controller.error, isNotNull);
      });
    }
  }

  for (final path in ['send', 'regenerate']) {
    for (final phase in ['assistant', 'draft']) {
      for (final change in ['sourceContent', 'endedRoom', 'newUser', 'newAssistant']) {
        test('$path $phase: Stop cannot clean a $change source that changed ahead in the SQLite queue', () async {
          await seedExisting(path);
          final entered = Completer<void>();
          final release = Completer<void>();
          Future<void>? blocking;
          final observed = _ObservedRepository(db);
          var expectedMessages = <Map<String, Object?>>[];
          Future<void> holdChangedSource() async {
            blocking = (await db.database).transaction((txn) async {
              if (change == 'sourceContent') {
                await txn.update('immersive_messages', {'content': '同 ID 的新来源'},
                  where: "room_id = ? AND role = 'user'", whereArgs: [room.id]);
              } else if (change == 'endedRoom') {
                await txn.update('immersive_rooms', {'status': 'ended'},
                  where: 'id = ?', whereArgs: [room.id]);
              } else {
                await txn.insert('immersive_messages', {
                  'id': 'independent-next-message', 'room_id': room.id,
                  'role': change == 'newUser' ? 'user' : 'assistant',
                  'content': '后来独立落地的消息，不属于旧生成任务',
                  'created_at': DateTime.now().millisecondsSinceEpoch + 1000,
                });
              }
              await txn.update('immersive_rooms', {'updated_at': 42},
                where: 'id = ?', whereArgs: [room.id]);
              expectedMessages = await txn.query('immersive_messages',
                where: 'room_id = ?', whereArgs: [room.id], orderBy: 'id ASC');
              entered.complete();
              await release.future.timeout(_barrierTimeout);
            });
            await _waitForBarrier(entered.future, blocking!, 'SQLite predecessor');
          }
          if (phase == 'assistant') {
            observed.beforeSubmission = holdChangedSource;
          } else {
            observed.beforeDraftSubmission = holdChangedSource;
          }
          final controller = await controllerFor(observed, truncate: phase == 'draft');
          final pending = start(controller, path);
          var bodyFailed = false;
          try {
            await _waitForBarrier(
              phase == 'assistant' ? observed.submitted.future : observed.draftSubmitted.future,
              pending, '$phase submission');
            await controller.stop().timeout(_barrierTimeout);
            release.complete();
            await _settleBarrierOperations(pending, blocker: blocking);
            expect(await (await db.database).query('immersive_messages',
              where: 'room_id = ?', whereArgs: [room.id], orderBy: 'id ASC'), expectedMessages);
            expect(await repository.interruptionsForRoom(room.id), isEmpty);
            expect((await repository.roomById(room.id))!.updatedAt.millisecondsSinceEpoch, 42);
            expect(await db.getSetting(draftKey()) ?? '', '');
            expect(controller.incompleteReplyDraft, isNull);
            expect(controller.error, isNotNull);
          } catch (_) {
            bodyFailed = true;
            rethrow;
          } finally {
            if (!release.isCompleted) release.complete();
            await _settleBarrierOperations(pending, blocker: blocking,
              preservePrimaryError: bodyFailed);
          }
        });
      }
    }
  }

  for (final path in ['send', 'regenerate', 'confirm']) {
    for (final phase in ['assistant', if (path != 'confirm') 'draft']) {
      for (final change in ['replaced', 'expired']) {
        test('$path $phase rejects a $change lease while queued without touching its source or consuming a draft', () async {
          await seedExisting(path);
          final initialDraft = await db.getSetting(draftKey());
          final entered = Completer<void>();
          final release = Completer<void>();
          Future<void>? blocking;
          final observed = _ObservedRepository(db);
          Future<void> holdChangedLease() async {
            blocking = (await db.database).transaction((txn) async {
              final held = await BrainWorkFence.value(txn, 'immersive_room_lease');
              final replacement = change == 'expired'
                  ? '${held.substring(0, held.lastIndexOf('|'))}|1'
                  : 'different-owner|${DateTime.now().millisecondsSinceEpoch + 600000}';
              await txn.update('settings', {'value': replacement},
                where: 'key = ?', whereArgs: ['immersive_room_lease']);
              await txn.update('immersive_rooms', {'updated_at': 42},
                where: 'id = ?', whereArgs: [room.id]);
              entered.complete();
              await release.future.timeout(_barrierTimeout);
            });
            await _waitForBarrier(entered.future, blocking!, 'SQLite predecessor');
          }
          if (phase == 'assistant') {
            observed.beforeSubmission = holdChangedLease;
          } else {
            observed.beforeDraftSubmission = holdChangedLease;
          }
          final controller = await controllerFor(observed, truncate: phase == 'draft');
          final pending = start(controller, path);
          var bodyFailed = false;
          try {
            await _waitForBarrier(
              phase == 'assistant' ? observed.submitted.future : observed.draftSubmitted.future,
              pending, '$phase submission');
            release.complete();
            await _settleBarrierOperations(pending, blocker: blocking);
            final messages = await repository.messagesForRoom(room.id);
            expect(messages.where((message) => message.isUser), hasLength(1));
            expect(messages.where((message) => message.isAssistant), isEmpty);
            expect(await repository.interruptionsForRoom(room.id), isEmpty);
            expect((await repository.roomById(room.id))!.updatedAt.millisecondsSinceEpoch, 42);
            expect(await db.getSetting(draftKey()) ?? '', path == 'confirm' ? initialDraft : '');
            expect(controller.incompleteReplyDraft, path == 'confirm' ? isNotNull : isNull);
            expect(controller.error, isNotNull);
          } catch (_) {
            bodyFailed = true;
            rethrow;
          } finally {
            if (!release.isCompleted) release.complete();
            await _settleBarrierOperations(pending, blocker: blocking,
              preservePrimaryError: bodyFailed);
          }
        });
      }
    }
  }

  test('new truncated draft persists its original source across reopen, not a fresh edited user', () async {
    final generating = ImmersiveRoomController(roomId: room.id, db: db, client: _ReplyClient(truncate: true));
    controllers.add(generating);
    await generating.initialize();
    await generating.send('原请求');
    final raw = (await db.getSetting(draftKey()))!;
    final saved = jsonDecode(raw) as Map;
    final source = saved['source_user'] as Map;
    expect(source['content'], '原请求');
    await (await db.database).update('immersive_messages', {'content': '后来改写'},
      where: 'id = ?', whereArgs: [source['id']]);
    final reopened = await controllerFor(_ObservedRepository(db));
    await reopened.confirmIncompleteReply();
    expect((await repository.messagesForRoom(room.id)).where((message) => message.isAssistant), isEmpty);
    expect(await db.getSetting(draftKey()), raw);
    expect(reopened.error, isNotNull);
  });

  test('legacy visible draft confirmation captures only the source at load time', () async {
    final source = await seedDraft(withSource: false);
    await (await db.database).update('immersive_messages', {'content': '载入前的当前内容'},
      where: 'id = ?', whereArgs: [source.id]);
    final controller = await controllerFor(_ObservedRepository(db));
    await controller.confirmIncompleteReply();
    expect(controller.error, isNull);
    expect((await repository.messagesForRoom(room.id)).last.content, '可见截断草稿。');
    expect(await db.getSetting(draftKey()), '');
  });
}
