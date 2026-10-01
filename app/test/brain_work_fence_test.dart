import 'dart:async';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_repository.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_reflection_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _WaitingReflection extends SimulatedPhoneReflectionGenerator {
  final started = Completer<void>();
  final result = Completer<({String self, String user})?>();
  @override
  Future<({String self, String user})?> tarot({
    required Map<String, Object?> cards,
  }) {
    started.complete();
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  const lease = 'calendar_reminder_followup_lease_until';
  setUp(() async => db = await AppDatabase.createForTesting(databaseFactoryFfi));
  tearDown(() async => db.closeForTesting());

  Future<BrainWorkFence> capture() async {
    expect(await db.tryAcquireLocalLease(lease), isTrue);
    return (await db.captureBrainWorkFence(leaseKey: lease))!;
  }

  ChatMessage message(String text) => ChatMessage(
    id: 'calendar-reminder:test', role: 'assistant', content: text,
    createdAt: DateTime.now(),
  );

  test('late reminder and settings cannot cross a real database restore', () async {
    final backup = await db.exportAll();
    final fence = await capture();
    await db.importAll(backup, runtimeSettingOverrides: {lease: '0'});
    expect(await db.insertBackgroundMessage(message('旧结果'), fence), isFalse);
    expect(await db.setSettingsAtomically({'phone': '旧结果'}, workFence: fence), isFalse);
    expect(await db.messageById('calendar-reminder:test'), isNull);
    expect(await db.getSetting('phone'), isNull);
  });

  test('a delivered reminder is never replaced by a repeated callback', () async {
    final fence = await capture();
    expect(await db.insertBackgroundMessage(message('第一次'), fence), isTrue);
    expect(await db.insertBackgroundMessage(message('第二次'), fence), isTrue);
    expect((await db.messageById('calendar-reminder:test'))!.content, '第一次');
  });

  for (final changed in [
    {'active_brain': '0'}, {'transfer_lock': '1'},
    {'snapshot_recovery_pending_v1': 'transaction'},
    {'state_generation': '999'}, {'runtime_state_epoch_v1': 'new'},
    {lease: 'another-owner|9999999999999'},
  ]) {
    test('write fence rejects ${changed.keys.single}', () async {
      final fence = await capture();
      await db.setSettingsAtomically(changed);
      expect(await db.insertBackgroundMessage(message('旧结果'), fence), isFalse);
      expect(await db.setSettingsAtomically({'phone': '旧结果'}, workFence: fence), isFalse);
    });
  }

  test('a lease renewal preserves ownership, expiry prevents a late commit', () async {
    final fence = await capture();
    await db.renewLocalLease(lease);
    expect(await db.brainWorkFenceCurrent(fence), isTrue);
    await db.renewLocalLease(lease, holdFor: Duration.zero);
    expect(await db.insertBackgroundMessage(message('过期结果'), fence), isFalse);
  });

  test('an actual in-flight phone generator cannot overwrite restored content', () async {
    final backup = await db.exportAll();
    final generator = _WaitingReflection();
    final phone = SimulatedPhoneRepository(db, reflectionGenerator: generator);
    final running = phone.refreshIfDue();
    await generator.started.future;
    await db.importAll(backup, runtimeSettingOverrides: {
      'simulated_phone_refresh_lease_until': '0',
      'simulated_phone_tarot_json': '[]',
    });
    generator.result.complete((self: '旧状态自己的牌', user: '旧状态用户的牌'));
    await running;
    expect(await db.getSetting('simulated_phone_tarot_json'), '[]');
    expect(await db.isLocalLeaseHeld('simulated_phone_refresh_lease_until'), isFalse);
  });

  test('standby refresh creates no tarot projection or generation request', () async {
    await db.setSetting('active_brain', '0');
    final generator = _WaitingReflection();
    await SimulatedPhoneRepository(db, reflectionGenerator: generator).refreshIfDue();
    expect(generator.started.isCompleted, isFalse);
    expect(await db.getSetting('simulated_phone_tarot_json'), isNull);
  });

  test('standby can read an immersive room, but all durable writes are rejected', () async {
    final rooms = ImmersiveRoomRepository(db);
    final room = await rooms.createRoom(title: '房间', openingScene: '', inheritCurrentChat: false);
    final user = await rooms.addMessage(roomId: room.id, role: 'user', content: '原文');
    await db.setSetting('active_brain', '0');
    expect((await rooms.roomById(room.id))!.title, '房间');
    for (final write in <Future<void> Function()>[
      () async { await rooms.createRoom(title: '不允许', openingScene: '', inheritCurrentChat: false); },
      () => rooms.activateRoom(room.id),
      () => rooms.pauseRoom(room.id),
      () => rooms.renameRoom(room.id, '不允许'),
      () => rooms.deleteRoom(room.id),
      () async { await rooms.addMessage(roomId: room.id, role: 'assistant', content: '不允许'); },
      () async { await rooms.interruptUserMessageForDisplay(roomId: room.id, messageId: user.id); },
      () => rooms.saveRollingState(roomId: room.id, rollingSummary: '不允许', sceneLedger: '', summarizedMessageCount: 1),
      () => rooms.endRoom(roomId: room.id, archiveSummary: '不允许', sceneLedger: '', sharedMemories: []),
    ]) {
      await expectLater(write(), throwsA(isA<BrainWorkInvalidated>()));
    }
    expect((await rooms.roomById(room.id))!.status, 'active');
    expect((await rooms.messagesForRoom(room.id)).length, 1);
  });

  test('immersive preparation failure always releases the generation lease', () async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-key'});
    final rooms = ImmersiveRoomRepository(db);
    final room = await rooms.createRoom(title: '房间', openingScene: '', inheritCurrentChat: false);
    final controller = ImmersiveRoomController(roomId: room.id, db: db);
    await controller.initialize();
    final sql = await db.database;
    await sql.execute("CREATE TRIGGER fail_room_message BEFORE INSERT ON immersive_messages "
        "BEGIN SELECT RAISE(ABORT, 'injected preparation failure'); END");
    await controller.send('测试准备失败');
    expect(controller.error, contains('未能开始'));
    expect(controller.sending, isFalse);
    expect(await db.isLocalLeaseHeld('immersive_room_lease'), isFalse);
    expect(await db.tryAcquireLocalLease('immersive_room_lease'), isTrue);
    await db.releaseLocalLease('immersive_room_lease');
    controller.dispose();
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a controller repository captured before restore cannot write afterwards', () async {
    final rooms = ImmersiveRoomRepository(db);
    final room = await rooms.createRoom(title: '房间', openingScene: '', inheritCurrentChat: false);
    rooms.stateFence = await db.captureBrainWorkFence();
    final backup = await db.exportAll();
    await db.importAll(backup, runtimeSettingOverrides: {'state_generation': '999'});
    await expectLater(rooms.addMessage(roomId: room.id, role: 'assistant', content: '旧正文'),
        throwsA(isA<BrainWorkInvalidated>()));
    expect(await rooms.messagesForRoom(room.id), isEmpty);
  });
}
