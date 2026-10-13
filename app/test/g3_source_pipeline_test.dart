import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/self/dream_material.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SourceConfig extends SecureConfig {
  _SourceConfig({this.beforeKey}) : super.forTesting(const FlutterSecureStorage());
  final Future<void> Function()? beforeKey;
  @override Future<String?> readApiKey() async { await beforeKey?.call(); return 'test-key'; }
  @override Future<String> readEndpoint() async => 'https://invalid.example';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() async { await db.closeForTesting(); });
  ChatMessage message(int i, {String? content}) => ChatMessage(id: 'u-$i',
    role: 'user', content: content ?? '真实事件材料 $i',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000 + i));
  Future<void> seed() async { for (var i = 0; i < 14; i++) { await db.insertMessage(message(i)); } }
  http.Response answer() => http.Response(jsonEncode({'choices': [{'message': {
    'content': jsonEncode({'summary': '已经核对的历史概况', 'key_points': ['历史材料']})},
    'finish_reason': 'stop'}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});

  test('atomic collection and local settings guard reject old material without partial values', () async {
    await db.insertMessage(message(0));
    final fence = (await db.captureBrainWorkFence())!;
    final material = await db.readSourceSnapshot(workFence: fence,
      read: (txn) => ConversationSourceStore.captureMaterial(txn, 'u-0'));
    expect(material!.message.content, '真实事件材料 0');
    await db.insertMessage(message(0, content: '人工改后的原文'));
    expect(await db.setSettingsAtomically({'truth': '旧推断', 'projection': '旧投影'},
      workFence: fence, sourceGuard: material.source.matches), isFalse);
    expect(await db.getSetting('truth'), isNull);
    expect(await db.getSetting('projection'), isNull);
    final fresh = await db.readSourceSnapshot(workFence: fence,
      read: (txn) => ConversationSourceStore.captureMaterial(txn, 'u-0'));
    expect(await db.setSettingsAtomically({'truth': '新推断', 'projection': '新投影'},
      workFence: fence, sourceGuard: fresh!.source.matches), isTrue);
  });

  test('fence extension never blesses an old same-millisecond reset', () async {
    await db.setSettingsAtomically({'conversation_context_reset_at': '10', 'conversation_context_reset_count': '1'});
    final fence = (await db.captureBrainWorkFence(settingKeys: const [
      'conversation_context_reset_at', 'conversation_context_reset_count']))!;
    await db.setSetting('wish_state', 'v2');
    final extended = await db.extendBrainWorkFence(fence, settingKeys: ['wish_state']);
    expect(extended!.expectedSettings['wish_state'], 'v2');
    expect(extended.expectedSettings['conversation_context_reset_count'], '1');
    await db.setSetting('conversation_context_reset_count', '2');
    expect(await db.extendBrainWorkFence(fence, settingKeys: ['wish_state']), isNull);
    var called = false;
    expect(await db.readSourceSnapshot(workFence: fence, read: (txn) async { called = true; return 'bad'; }), isNull);
    expect(called, isFalse);
  });

  test('real summary provider failure keeps its durable batch for a successful next attempt', () async {
    await seed();
    var calls = 0;
    final client = DeepSeekClient(client: MockClient((request) async {
      if (++calls == 1) return http.Response('unavailable', 503);
      return answer();
    }));
    final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
    try {
      await expectLater(extractor.consolidateIfNeeded(apiKey: 'test', endpoint: 'https://invalid.example'), throwsA(anything));
      expect(await db.recentConversationSummaries(), isEmpty);
      expect(await (await db.database).query('conversation_summary_sources', where: "state = 'pending'"), hasLength(14));
      await extractor.consolidateIfNeeded(apiKey: 'test', endpoint: 'https://invalid.example');
      expect(calls, 2);
      expect(await db.recentConversationSummaries(), hasLength(1));
      expect(await (await db.database).query('conversation_summary_sources', where: "state = 'covered'"), hasLength(14));
    } finally { client.close(); }
  });

  for (final mutation in ['source', 'reset', 'expired_lease']) {
    test('real summary request rejects $mutation changed while provider owns the old transcript', () async {
      await seed();
      final client = DeepSeekClient(client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect('${body['messages']}', contains('真实事件材料 0'));
        if (mutation == 'source') {
          await db.insertMessage(message(0, content: '生成期间更正原材料'));
        } else if (mutation == 'reset') {
          await db.setSetting('conversation_context_reset_count', 'new-reset');
        } else {
          final lease = (await db.getSetting('conversation_summary_lease_until'))!;
          await db.setSetting('conversation_summary_lease_until', '${lease.split('|').first}|1');
        }
        return answer();
      }));
      try {
        await MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db))
          .consolidateIfNeeded(apiKey: 'test', endpoint: 'https://invalid.example');
        expect(await db.recentConversationSummaries(), isEmpty);
        expect(await (await db.database).query('conversation_summary_sources', where: "state = 'covered'"), isEmpty);
      } finally { client.close(); }
    });
  }

  test('Dream collection background exposes only known source events without changing source hashes', () async {
    await db.insertMemory(kind: 'ai_self', content: '我喜欢安静地看云', importance: .8, source: 'old-unknown');
    await db.insertMemory(kind: 'ai_self', content: '我喜欢温暖的灯光', importance: .8,
      source: 'verified', sourceObservedAt: DateTime.fromMillisecondsSinceEpoch(1000));
    final material = await DreamMaterial.collect(db, {}, DateTime.now(), weekly: true);
    final prior = material.background.where((row) => row['kind'] == 'prior_memory_interpretation').toList();
    expect(prior, hasLength(2));
    final unknown = prior.singleWhere((row) => '${row['text']}'.contains('看云'));
    expect(unknown['original_record_at'], isNull);
    expect(unknown['source_time_known'], isFalse);
    expect(unknown['evidence_allowed'], isFalse);
    final known = prior.singleWhere((row) => '${row['text']}'.contains('灯光'));
    expect(known['original_record_at'], 1000);
    expect(known['source_time_known'], isTrue);
    expect(known['evidence_allowed'], isFalse);
  });

  for (final mutation in ['before_capture', 'during_provider', 'none']) {
    test('real extraction $mutation retains original source time or rejects changed material', () async {
      await db.setSetting('post_turn_queue_enabled', '0');
      for (final key in ['daily_continuity_enabled', 'memory_fading_enabled',
        'memory_consolidation_enabled', 'relationship_continuity_enabled', 'personality_learning_enabled']) {
        await db.setSetting(key, '0');
      }
      final user = message(0, content: '我的书桌是橡木做的');
      final assistant = ChatMessage(id: 'a', role: 'assistant', content: '记住了橡木书桌',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000));
      await db.insertMessage(user); await db.insertMessage(assistant);
      var calls = 0;
      Future<void> change() => db.insertMessage(message(0, content: '刚刚更正为金属书桌'));
      final client = DeepSeekClient(client: MockClient((request) async {
        calls++;
        if (mutation == 'during_provider') await change();
        return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({
          'memories': [{'kind': 'user_profile', 'content': '用户的书桌是橡木做的',
            'importance': .8, 'confidence': .95, 'subject_key': 'user.desk.material',
            'actor': 'user', 'semantic': 'current_fact', 'temporal_scope': 'stable', 'action': 'append'}]
        })}, 'finish_reason': 'stop'}]}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db),
        secureConfig: _SourceConfig(beforeKey: mutation == 'before_capture' ? change : null));
      try {
        final operation = extractor.extractFromTurn(user: user, assistant: assistant);
        if (mutation == 'before_capture') {
          await expectLater(operation, throwsA(anything));
          expect(calls, 0, reason: 'old material must be rejected before buying a model response');
        } else { await operation; expect(calls, 1); }
        final memories = await db.listMemories();
        if (mutation == 'none') {
          expect(memories, hasLength(1));
          expect(memories.single.evidenceTimeKnown, isTrue);
          expect(memories.single.lastEvidenceAt, user.createdAt);
        } else {
          expect(memories, isEmpty);
          expect(await (await db.database).query('memory_evidence'), isEmpty);
        }
      } finally { client.close(); }
    });
  }

  test('present invalid time capability cannot downgrade to legacy unknown admission', () async {
    final client = DeepSeekClient(client: MockClient((_) async => throw StateError('no model')));
    final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
    final proposals = [{'kind': 'user_profile', 'content': '书桌材质橡木', 'importance': .8,
      'subject_key': 'user.desk.material'}];
    try {
      await extractor.applyMemoryProposals(proposals, 'a', userText: '书桌材质橡木', userMessageId: 'u',
        localSnapshots: {}, localTimeSources: {}, requireTimeSources: true, knowledgeReferenceActive: false);
      expect(await db.listMemories(), isEmpty);
      await extractor.applyMemoryProposals(proposals, 'a', userText: '书桌材质橡木', userMessageId: 'u',
        localSnapshots: {}, knowledgeReferenceActive: false);
      expect((await db.listMemories()).single.evidenceTimeKnown, isFalse);
    } finally { client.close(); }
  });
}
