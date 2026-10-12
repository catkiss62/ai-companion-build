import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/memory/memory_grounding_policy.dart';
import 'package:ai_companion_localfirst/core/memory/memory_revision.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/personality/form_context_snapshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late ChatMessage originalUser, originalAssistant, user, assistant;
  const channel = MethodChannel('ai_companion/system');
  final at = DateTime(2026, 10, 12, 15);

  ChatMessage message(String id, String role, String content, DateTime time, bool q) =>
      ChatMessage(id: id, role: role, content: content, createdAt: time,
        formContextJson: FormContextSnapshot.fromForm(qForm: q, now: time,
            kind: role == 'user' ? 'user_received' : 'reply_generation').encode());

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-only'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            call.method == 'runtimeProcessEpoch' ? 'memory-revision-test' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    originalUser = message('original-user', 'user', '我们一起整理了花盆', at, true);
    originalAssistant = message('original-assistant', 'assistant',
        '我们整理了2个花盆', at.add(const Duration(seconds: 1)), true);
    user = message('correction-user', 'user', '其实一直是4个花盆，之前记错了',
        at.add(const Duration(hours: 1)), false);
    assistant = message('correction-assistant', 'assistant', '明白，一直是4个花盆',
        at.add(const Duration(hours: 1, seconds: 1)), false);
    for (final m in [originalUser, originalAssistant, user, assistant]) {
      await db.insertMessage(m);
    }
    for (final key in ['daily_continuity_enabled', 'memory_fading_enabled',
      'memory_consolidation_enabled', 'relationship_continuity_enabled',
      'personality_learning_enabled']) {
      await db.setSetting(key, '0');
    }
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<MemoryItem> byId(String id) async => MemoryItem.fromDb(
      (await (await db.database).query('memory_items', where: 'id = ?',
        whereArgs: [id])).single);

  Future<MemoryItem> seed({bool shared = false, bool pinned = false,
    String subject = 'user.garden.pot_count', String content = '院子里有2个花盆'}) async {
    await db.insertMemory(kind: shared ? 'shared_experience' : 'user_profile',
      content: content, importance: .8, confidence: .95, pinned: pinned,
      semanticType: shared ? 'shared_experience' : 'current_fact',
      subjectKey: subject, source: 'conversation_turn:${originalAssistant.id}',
      sourceUserMessageId: originalUser.id, sourceAssistantMessageId: originalAssistant.id,
      sourceContextJson: MemorySourceContext.capture(originalUser, originalAssistant));
    return (await db.listMemories()).firstWhere((m) => m.content == content);
  }

  Future<bool> revise(MemoryItem old, {MemoryRevisionSnapshot? snapshot,
    String action = 'correct', String reason = 'correction',
    String content = '院子里一直有4个花盆', String quote = '其实一直是4个花盆',
    String? subject, String? target}) => db.insertMemory(kind: old.kind,
      content: content, importance: .8, confidence: .95,
      semanticType: old.semanticType, subjectKey: subject ?? old.subjectKey,
      source: 'conversation_turn:${assistant.id}', evidenceMode: action,
      revisionKind: reason, targetMemoryId: target ?? old.id,
      expectedTarget: snapshot ?? MemoryRevisionSnapshot.capture(old),
      userEvidenceQuote: quote, sourceUserMessageId: user.id,
      sourceAssistantMessageId: assistant.id,
      sourceContextJson: MemorySourceContext.capture(user, assistant));

  Map<String, dynamic> proposal(MemoryItem old, {String action = 'correct',
    String reason = 'correction', String? quote}) => {
      'kind': old.kind, 'semantic': old.semanticType, 'action': action,
      'revision_kind': reason, 'target_id': old.id, 'subject_key': old.subjectKey,
      'content': '院子里一直有4个花盆', 'confidence': .95, 'importance': .8,
      'user_evidence_quote': quote ?? '其实一直是4个花盆',
    };

  test('correction retires a wrong claim without asserting it was once true', () async {
    final old = await seed();
    expect(await revise(old), isTrue);
    final historical = await byId(old.id);
    final current = (await db.listMemories()).single;
    expect(historical.content, '院子里有2个花盆');
    expect(historical.source, 'conversation_turn:${originalAssistant.id}');
    expect(historical.status, 'superseded');
    expect(historical.supersessionReason, 'correction');
    expect(historical.supersededBy, current.id);
    expect(current.revisionOf, old.id);
    expect(current.content, '院子里一直有4个花盆');
    expect(current.factVersion, old.factVersion + 1);
    expect(MemoryGroundingPolicy.formatForPrompt(historical), contains('不证明过去成立'));
    final evidence = await db.memoryEvidenceFor(old.id);
    expect(evidence.any((e) => e['relation'] == 'correction_to:${current.id}' &&
        e['evidence_text'] == '其实一直是4个花盆'), isTrue);
    expect((await db.messageById(originalAssistant.id))!.content, originalAssistant.content);
  });

  test('later change and independent contexts have different outcomes', () async {
    final old = await seed();
    final changedUser = message(user.id, 'user', '以前有2个，现在买了2个，一共有4个花盆', user.createdAt, false);
    await (await db.database).update('messages', {'content': changedUser.content},
        where: 'id = ?', whereArgs: [user.id]);
    expect(await revise(old, action: 'replace', reason: 'change',
        content: '院子里现在有4个花盆', quote: '现在买了2个'), isTrue);
    expect((await byId(old.id)).supersessionReason, 'change');
    expect(MemoryGroundingPolicy.formatForPrompt(await byId(old.id)), contains('事实后来改变'));
    await db.insertMemory(kind: 'user_profile', content: '室内有2个花盆',
        importance: .8, confidence: .95, subjectKey: 'user.indoor.pot_count',
        evidenceMode: 'append', revisionKind: 'context');
    expect((await db.listMemories()).where((m) => m.isCurrentFact), hasLength(2));
    // Unqualified same-subject append must not replace the current value.
    await db.insertMemory(kind: 'user_profile', content: '某个场景有6个花盆',
        importance: .8, confidence: .95, subjectKey: old.subjectKey,
        evidenceMode: 'append', revisionKind: 'context');
    expect((await db.listMemories()).where((m) => m.isCurrentFact), hasLength(2));
    expect((await db.listMemories()).singleWhere((m) => m.content.contains('6个')).isInference, isTrue);
  });

  test('shared experience correction preserves original and correcting turns/forms', () async {
    final old = await seed(shared: true, subject: '', content: '我们一起整理了2个花盆');
    expect(await revise(old, content: '我们一起整理了花盆，实际有4个花盆'), isTrue);
    final current = (await db.listMemories()).single;
    expect(current.isSharedExperience, isTrue);
    final sources = await db.recallExperienceSources([current]);
    expect(sources.map((m) => m.id), [originalUser.id, originalAssistant.id, user.id, assistant.id]);
    final sourceText = MemorySourceContext.format(current.sourceContextJson);
    expect(sourceText, contains('原经历来源'));
    expect(sourceText, contains('小豆丁'));
    expect(sourceText, contains('修订来源'));
    expect(sourceText, contains('正常本体'));
    await (await db.database).delete('messages');
    expect(MemorySourceContext.format((await byId(current.id)).sourceContextJson), sourceText);
    expect((await db.relevantHistoricalMemories('花盆')).map((m) => m.id), contains(old.id));
  });

  test('legacy assistant-bound sources recover only a durable exact pair', () async {
    final old = await seed(shared: true, content: '我们一起整理了2个花盆');
    await (await db.database).update('memory_items', {
      'source_user_message_id': '', 'source_assistant_message_id': '',
    }, where: 'id = ?', whereArgs: [old.id]);
    expect(await db.recallExperienceSources([await byId(old.id)]), isEmpty);
    await db.enqueuePostTurnJob(userMessageId: originalUser.id, assistantMessageId: originalAssistant.id);
    expect((await db.recallExperienceSources([await byId(old.id)])).map((m) => m.id),
        [originalUser.id, originalAssistant.id]);
  });

  test('wrong target, evidence, subject, mode and pinned rows cannot be revised', () async {
    final old = await seed();
    expect(await revise(old, target: 'missing'), isFalse);
    expect(await revise(old, quote: '用户没有说过这句话'), isFalse);
    expect(await revise(old, subject: 'user.other.pots'), isFalse);
    expect(await revise(old, action: 'replace', reason: 'correction'), isFalse);
    expect(await revise(old, action: 'append', reason: 'correction'), isFalse);
    await db.updateMemoryItem(id: old.id, content: old.content, importance: .8,
        confidence: .95, tags: [], pinned: true);
    expect(await revise(await byId(old.id)), isFalse);
    expect((await db.listMemories()).single.content, old.content);
    expect((await db.memoryEvidenceFor(old.id)), hasLength(1));
  });

  test('confirmation of identical inference wording requires its local version', () async {
    final old = await seed(content: '院子里有4个花盆');
    await (await db.database).update('memory_items', {'semantic_type': 'inference'},
        where: 'id = ?', whereArgs: [old.id]);
    final inference = await byId(old.id);
    expect(await db.insertMemory(kind: inference.kind, content: inference.content,
        importance: .8, confidence: .95, subjectKey: inference.subjectKey,
        evidenceMode: 'append'), isFalse);
    expect(await db.insertMemory(kind: inference.kind, content: inference.content,
        importance: .8, confidence: .95, subjectKey: inference.subjectKey,
        evidenceMode: 'replace', revisionKind: 'change', targetMemoryId: inference.id,
        expectedTarget: MemoryRevisionSnapshot.capture(inference),
        source: 'conversation_turn:${assistant.id}', userEvidenceQuote: '其实一直是4个花盆',
        sourceUserMessageId: user.id, sourceAssistantMessageId: assistant.id), isTrue);
    expect((await db.listMemories()).single.isCurrentFact, isTrue);
    expect((await byId(old.id)).supersessionReason, 'confirmation');
    expect(MemoryGroundingPolicy.formatForPrompt(await byId(old.id)), contains('不证明旧推断过去已成立'));
  });

  test('exact source pairing survives a long generation retry and malformed form metadata is unknown', () async {
    final old = await seed(shared: true, content: '我们一起整理了2个花盆');
    await (await db.database).update('messages', {
      'created_at': originalAssistant.createdAt.add(const Duration(hours: 2)).millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [originalAssistant.id]);
    expect((await db.recallExperienceSources([old])).map((m) => m.id),
        [originalUser.id, originalAssistant.id]);
    expect(MemorySourceContext.format('{"user":{"form_context_json":3,"created_at":"bad"}}'),
        contains('未知'));
  });

  test('stale work cannot overwrite a manual edit or a newer replacement', () async {
    final old = await seed();
    final snapshot = MemoryRevisionSnapshot.capture(old);
    await db.updateMemoryItem(id: old.id, content: '用户手工核对：有8个花盆',
        importance: .8, confidence: .95, tags: []);
    expect(await revise(old, snapshot: snapshot), isFalse);
    final edited = await byId(old.id);
    expect(await revise(edited), isTrue);
    expect(await revise(old, snapshot: snapshot, content: '延迟提案：有3个花盆'), isFalse);
    expect((await db.listMemories()).single.content, '院子里一直有4个花盆');
  });

  test('accepted replay is idempotent and stale maintenance cannot archive its history', () async {
    final old = await seed();
    final checked = old.retentionCheckedAt ?? old.updatedAt;
    expect(await revise(old), isTrue);
    expect(await revise(old), isTrue);
    expect((await (await db.database).query('memory_items')), hasLength(2));
    expect(await db.updateMemoryRetentionIfUnchanged(id: old.id,
        expectedCheckedAt: checked, expectedUpdatedAt: old.updatedAt,
        retentionScore: 0, checkedAt: DateTime.now(), status: 'archived'), isFalse);
    expect((await byId(old.id)).status, 'superseded');
    expect((await db.memoryEvidenceFor(old.id)), hasLength(2));
  });

  for (final hasSnapshot in [true, false]) {
    test('denied correction cannot route through reinforce/duplicate (snapshot=$hasSnapshot)', () async {
      final old = await seed();
      final client = DeepSeekClient();
      try {
        final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
        await extractor.applyMemoryProposals([
          // Put the bypass first to prove execution order is not an escape.
          {...proposal(old), 'action': 'reinforce', 'revision_kind': '', 'content': old.content},
          proposal(old, quote: '没有这句证据'),
          {...proposal(old), 'action': 'append', 'revision_kind': '', 'target_id': '',
            'subject_key': '', 'content': old.content},
        ], assistant.id, userText: user.content, userMessageId: user.id,
            localSnapshots: hasSnapshot ? {old.id: MemoryRevisionSnapshot.capture(old).toJson()} : null,
            knowledgeReferenceActive: false);
        expect((await db.listMemories()).single.id, old.id);
        expect((await byId(old.id)).evidenceCount, 1);
        expect((await db.memoryEvidenceFor(old.id)), hasLength(1));
        expect(int.parse((await db.getSetting('memory_revision_rejected_count'))!), 3);
      } finally { client.close(); }
    });
  }

  test('model cannot replace the local pre-request version token while it is waiting', () async {
    final old = await seed();
    await db.setSetting('post_turn_queue_enabled', '0');
    var calls = 0;
    final client = DeepSeekClient(client: MockClient((request) async {
      calls++;
      await db.updateMemoryItem(id: old.id, content: '人工更新为8个花盆',
          importance: .8, confidence: .95, tags: []);
      // Pretend the model returns the new token. The extractor must replace it
      // with the older local capability captured before this request.
      final forged = MemoryRevisionSnapshot.capture(await byId(old.id));
      return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({
        'memories': [proposal(old)],
        '_local_memory_revision_snapshots_v1': {old.id: forged.toJson()},
      })}, 'finish_reason': 'stop'}]}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    try {
      await MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db))
          .extractFromTurn(user: user, assistant: assistant);
      expect(calls, 1);
      expect((await db.listMemories()).single.content, '人工更新为8个花盆');
      expect(await db.getSetting('memory_revision_rejected_count'), '1');
    } finally { client.close(); }
  });

  test('archive roundtrip retains revision chain, evidence and source form snapshots', () async {
    final old = await seed(shared: true, content: '我们一起整理了2个花盆');
    expect(await revise(old, content: '我们一起整理了花盆，实际有4个花盆'), isTrue);
    final current = (await db.listMemories()).single;
    final backup = await db.exportAll();
    await db.importAll(Map<String, dynamic>.from(backup));
    expect((await byId(old.id)).supersessionReason, 'correction');
    expect((await byId(current.id)).revisionOf, old.id);
    expect((await byId(current.id)).sourceContextJson, current.sourceContextJson);
    final evidence = await db.memoryEvidenceFor(current.id);
    expect(evidence.single['source_context_json'], MemorySourceContext.capture(user, assistant));
  });
}
