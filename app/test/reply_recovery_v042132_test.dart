import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_recovery.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/platform/overlay_generation_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  const channel = MethodChannel('ai_companion/system');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    messenger.setMockMethodCallHandler(channel,
      (call) async => call.method == 'runtimeProcessEpoch' ? 'live-process' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async {
    await db.closeForTesting();
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<String> running() async {
    final pending = await db.createGenerationTurn(
      user: ChatMessage(id: 'u', role: 'user', content: '继续', createdAt: DateTime.now()),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    expect(await db.claimGenerationJob(pending.id), isNotNull);
    return pending.id;
  }

  test('recent orphan is reclaimable now, but only after exclusive lease acquisition', () async {
    final id = await running();
    final before = (await db.generationJobById(id))!;
    expect(await db.claimGenerationJob(id), isNull);
    await db.setSetting('chat_turn_lease',
      'dead-process:00000000-0000-0000-0000-000000000001|${DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch}');
    expect(await db.nextGenerationRecoveryDelay(), Duration.zero);
    expect(await db.tryAcquireLocalLease('chat_turn_lease', holdFor: const Duration(seconds: 30)), isTrue);
    final after = (await db.claimGenerationJob(id))!;
    expect(after.runToken, isNot(before.runToken));
    expect(after.attempts, before.attempts + 1);
    expect(await db.isGenerationRunCurrent(id, runToken: before.runToken), isFalse);
    expect(await db.isGenerationRunCurrent(id, runToken: after.runToken), isTrue);
    await db.releaseLocalLease('chat_turn_lease');
  });

  test('live execution is not reclaimed by a recovery wake', () async {
    final id = await running();
    final token = (await db.generationJobById(id))!.runToken;
    expect(await db.tryAcquireLocalLease('chat_turn_lease', holdFor: const Duration(seconds: 30)), isTrue);
    final client = DeepSeekClient();
    try {
      final recovery = DurableGenerationRecovery(db: db,
        runner: DurableGenerationRunner(db: db, client: client));
      expect(await recovery.recoverOne(), isFalse);
      expect((await db.generationJobById(id))!.runToken, token);
      final delay = await db.nextGenerationRecoveryDelay();
      expect(delay, isNotNull);
      expect(delay!.inMilliseconds, inInclusiveRange(1, 30000));
    } finally {
      client.close();
      await db.releaseLocalLease('chat_turn_lease');
    }
  });

  test('expired engine lease recovers without waiting for checkpoint age', () async {
    final id = await running();
    await db.setSetting('chat_turn_lease',
      'live-process:00000000-0000-0000-0000-000000000002|1');
    expect(await db.nextGenerationRecoveryDelay(), Duration.zero);
    expect(await db.tryAcquireLocalLease('chat_turn_lease'), isTrue);
    expect(await db.claimGenerationJob(id), isNotNull);
    await db.releaseLocalLease('chat_turn_lease');
  });

  test('replaced lease and user Stop still fence recent running attempts', () async {
    final id = await running();
    expect(await db.tryAcquireLocalLease('chat_turn_lease'), isTrue);
    await db.setSetting('chat_turn_lease',
      'live-process:00000000-0000-0000-0000-000000000003|${DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch}');
    expect(await db.claimGenerationJob(id), isNull);
    await db.cancelGenerationJobByUser(id);
    expect(await db.claimGenerationJob(id), isNull);
    expect(await db.nextGenerationRecoveryDelay(), isNull);
  });

  for (final status in ['failed', 'retry_wait', 'pending', 'awaiting_confirmation']) {
    test('overlay preserves $status instead of inventing active thinking', () {
      final snapshot = OverlayGenerationSnapshot(
        sending: status == 'retry_wait' || status == 'pending', cancelling: false,
        reasoning: '', content: '', runtimePhase: status, statusText: '状态提示');
      expect(snapshot.phase, status);
      expect(snapshot.toChannelMap()['status_text'], '状态提示');
      if (status == 'failed') expect(snapshot.toChannelMap()['sending'], isFalse);
    });
  }
}
