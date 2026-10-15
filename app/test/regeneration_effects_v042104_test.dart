import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/database/derived_source_store.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() => db.closeForTesting());
  test('regeneration preserves remote effects and user facts but withdraws old expressions', () async {
    final now = DateTime.now();
    final user = ChatMessage(id: 'u', role: 'user', content: '我喜欢花', createdAt: now);
    final pending = await db.createGenerationTurn(user: user, assistantMessageId: 'a',
      model: 'deepseek-v4-flash', reasoningEffort: 'high');
    final running = (await db.claimGenerationJob(pending.id))!;
    final attempt = (await db.captureGenerationAttemptFence(running))!;
    final effects = TurnExecutionStore(db);
    const payload = {'game': 'test', 'action': 'play'};
    expect(await effects.reserveRemoteEffect(attempt, payload), isNull);
    await effects.completeRemoteEffect('u', payload, outcome: '远端已执行', failed: false);
    final assistant = ChatMessage(id: 'a', role: 'assistant', content: '我选择了红门', createdAt: now.add(const Duration(seconds: 1)));
    expect(await db.completeGenerationJobIfCurrent(jobId: running.id, runToken: running.runToken, assistant: assistant), isTrue);
    await db.insertMemory(kind: 'ai_self', content: '选择了红门', importance: .8,
      source: 'conversation_turn:a@r0', sourceUserMessageId: 'u', sourceAssistantMessageId: 'a',
      sourceContextJson: jsonEncode({'dependency': 'assistant_basis'}));
    await db.insertMemory(kind: 'user_profile', content: '用户喜欢花', importance: .8,
      source: 'conversation_turn:a@r0', sourceUserMessageId: 'u', sourceAssistantMessageId: 'a',
      sourceContextJson: jsonEncode({'dependency': 'user_basis'}));
    final sql = await db.database;
    final original = (await ConversationSourceStore.captureMessage(sql, 'a'))!;
    await db.insertConversationSummary(fromAt: now, toAt: assistant.createdAt, summary: '她选择了红门');
    final summary = (await sql.query('conversation_summaries')).single;
    await DerivedSourceStore.link(sql, kind: 'summary', ownerId: summary['id'] as String,
      sourceId: 'a', revision: 0, role: 'assistant_basis');
    final reopened = (await db.restartLatestCompletedReply('a'))!;
    expect(reopened.assistantSourceRevision, 1);
    expect((await effects.remoteEffect('u'))!['outcome'], '远端已执行');
    expect((await db.listMemories()).map((m) => m.content), contains('用户喜欢花'));
    expect((await db.listMemories()).map((m) => m.content), isNot(contains('选择了红门')));
    expect(await db.recentConversationSummaries(), isEmpty);
    final retry = (await db.claimGenerationJob(reopened.id))!;
    expect(await db.completeGenerationJobIfCurrent(jobId: retry.id, runToken: retry.runToken,
      assistant: assistant.copyWith(sourceRevision: 1)), isTrue);
    expect(await original.matches(sql), isFalse);
    expect((await ConversationSourceStore.captureMessage(sql, 'a'))!.revision, 1);
  });
  test('unresolved dispatch is durable and never admitted again by elapsed time', () async {
    final pending = await db.createGenerationTurn(user: ChatMessage(id: 'u', role: 'user', content: '玩一局', createdAt: DateTime.now()),
      assistantMessageId: 'a', model: 'deepseek-v4-flash', reasoningEffort: 'high');
    final running = (await db.claimGenerationJob(pending.id))!;
    final attempt = (await db.captureGenerationAttemptFence(running))!;
    final store = TurnExecutionStore(db);
    expect(await store.reserveRemoteEffect(attempt, const {'action': 'play'}), isNull);
    final repeated = await store.reserveRemoteEffect(attempt, const {'action': 'play'});
    expect(repeated!['state'], 'dispatching');
    expect((await store.reserveRemoteEffect(attempt, const {'action': 'different'}))!['state'], 'conflict');
  });
}
