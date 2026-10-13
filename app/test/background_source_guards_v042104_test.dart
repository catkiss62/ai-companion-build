import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/reflection/deep_reflection_engine.dart';
import 'package:ai_companion_localfirst/core/reflection/deep_reflection_store.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_game_evidence.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _limit = Duration(seconds: 10);
typedef _Review = Future<Map<String, dynamic>?> Function(Map<String, Object?> material);
Future<void> _arrived(Completer<void> signal, Future<dynamic> operation) =>
    Future.any<void>([signal.future, operation.then<void>((_) {
      if (!signal.isCompleted) throw StateError('Operation ended before reviewer/barrier');
    })]).timeout(_limit);

Future<void> _duringReview({required Future<bool> Function(_Review) start,
  required Future<void> Function() mutate, required Map<String, dynamic> response,
  String? sourceId, bool succeeds = false}) async {
  final entered = Completer<void>();
  final released = Completer<Map<String, dynamic>?>();
  final operation = start((material) {
    if (sourceId != null) {
      expect((material['sources'] as List).whereType<Map>().map((s) => s['id']), contains(sourceId));
    }
    entered.complete();
    return released.future;
  });
  var failed = false;
  try {
    await _arrived(entered, operation);
    await mutate();
    released.complete(response);
    expect(await operation.timeout(_limit), succeeds);
  } catch (_) { failed = true; rethrow; }
  finally {
    if (!released.isCompleted) released.complete(null);
    try { await operation.timeout(_limit); } catch (_) { if (!failed) rethrow; }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late DateTime now;
  setUp(() async {
    now = DateTime.now();
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() => db.closeForTesting());
  ChatMessage user({String text = '我觉得可以保留不确定，不用马上下结论'}) =>
    ChatMessage(id: 'source', role: 'user', content: text,
      createdAt: now.subtract(const Duration(minutes: 1)));
  String rp() => const WorldBookTurnContext(roleplaySessionId: 'fiction').encode();
  MessageAttachment photo() => MessageAttachment(id: 'photo', messageId: 'source',
    kind: 'image', originalPath: '/old/photo', thumbnailPath: '/old/thumb',
    byteSize: 1, width: 1, height: 1, mimeType: 'image/png', source: 'user_upload',
    visionStatus: 'completed', visionSummary: '这里有一朵白色花朵', createdAt: now);
  Future<void> seedWish({String route = 'user'}) async {
    final store = WishStore(db);
    await store.initialize();
    expect(await store.save([CompanionWish(id: 'w', goal: '想看看这朵白色的花',
      reason: '好奇花朵的形状', route: route, criterion: '收到可识别白色花朵的照片',
      completionKind: route == 'game' ? 'game_result' : 'user_photo', gameId: 'white_room',
      createdAt: now.subtract(const Duration(hours: 2)), updatedAt: now.subtract(const Duration(hours: 2)),
      lastIntentionAt: now.subtract(const Duration(hours: 2)), lastIntentionSource: 'wish_creation')],
      expected: await db.getSetting(WishStore.stateKey) ?? '',
      fence: (await db.captureBrainWorkFence())!), isTrue);
  }
  Future<Map<String, String?>> wishState() async => {
    for (final key in [WishStore.stateKey, WishStore.activeKey, WishStore.completedKey,
      WishStore.archivedKey, WishEngine.fingerprintKey]) key: await db.getSetting(key),
  };
  Map<String, dynamic> completedPhoto() => {'updates': [{
    'id': 'w', 'state': 'completed', 'evidence_id': 'photo:source:photo',
    'quote': '白色花朵', 'same_target': true, 'observed': true, 'confidence': .95,
  }]};
  Map<String, dynamic> topic() => {'topic': {
    'question': '暂时解释不了的选择，怎样才算理解了它？',
    'prior_view': '以为每个选择都需要立刻得到解释',
    'tension': '保留不确定改变了我原来的理解',
    'why_user': '想知道你怎样面对暂时不清楚的选择',
    'source_id': 'chat:source', 'source_quote': '可以保留不确定', 'suitable': true,
  }};
  Future<void> seedWeb({String semantic = 'valid', Duration age = const Duration(days: 3)}) async {
    await (await db.database).insert('public_web_candidates', {
      'id': 'web', 'fingerprint': 'web', 'title': '读到不同的理解', 'summary': '保留不确定也可以继续探索',
      'page_body': '原始网页正文，以及完整的上下文。', 'url': 'https://example.com/read',
      'source_domain': 'example.com', 'provider': 'fixture', 'drive_key': 'curiosity',
      'intent_action': 'read', 'action_run_id': 'fixture', 'discovered_at': now.subtract(age).millisecondsSinceEpoch,
      'expires_at': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'read_at': now.subtract(age).millisecondsSinceEpoch, 'read_state': 'verified',
      'semantic_state': semantic, 'lifecycle_state': 'shared',
    });
  }

  test('durable RP pair outside candidate window excludes unmarked user text and photo', () async {
    final created = await db.createGenerationTurn(user: user().copyWith(attachments: [photo()]), assistantMessageId: 'paired',
      model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(created.id))!;
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      assistant: ChatMessage(id: 'paired', role: 'assistant', content: '角色扮演里的回答',
        worldBookContextJson: rp(), createdAt: now.subtract(const Duration(days: 15)))), isTrue);
    expect(await WishEngine(db).collect(now), isEmpty);
    expect(await DeepReflectionEngine(db).collect(now), isEmpty);
    var calls = 0;
    await WishEngine(db, reviewer: (_) async { calls++; return {'updates': []}; }).maybeRefresh(now: now);
    await DeepReflectionEngine(db, reviewer: (_) async { calls++; return {'topic': null}; }).maybePrepare(now: now);
    expect(calls, 0);
    await db.insertMessage(ChatMessage(id: 'ordinary', role: 'assistant', isProactive: true,
      content: '独立的真实思考仍然可以保留', createdAt: now.subtract(const Duration(seconds: 1))));
    expect((await WishEngine(db).collect(now)).map((e) => e.id), ['chat:ordinary']);
    expect((await DeepReflectionEngine(db).collect(now)).map((e) => e['id']), ['chat:ordinary']);
  });

  for (final change in ['suffix', 'vision', 'attachmentOwner', 'pairedRoleplay', 'resetCount', 'restore']) {
    test('Wish rejects $change after original photo/text material without writing projections or success', () async {
      await seedWish();
      final original = user(text: '${'原' * 900}可以保留不确定');
      await db.insertMessageWithAttachments(original, [photo()]);
      final before = await wishState();
      await _duringReview(start: (review) => WishEngine(db, reviewer: review).maybeRefresh(now: now),
        sourceId: 'photo:source:photo', response: completedPhoto(), mutate: () async {
          final sql = await db.database;
          if (change == 'suffix') {
            await db.insertMessage(user(text: '${'原' * 900}同样裁切片段后面的新含义'));
          } else if (change == 'vision') {
            await sql.update('message_attachments', {'vision_summary': '实际是另一种东西'}, where: 'id = ?', whereArgs: ['photo']);
          } else if (change == 'attachmentOwner') {
            await db.insertMessage(ChatMessage(id: 'other', role: 'user', content: '另一条消息', createdAt: now));
            await sql.update('message_attachments', {'message_id': 'other'}, where: 'id = ?', whereArgs: ['photo']);
          } else if (change == 'pairedRoleplay') {
            await db.insertMessage(ChatMessage(id: 'reply', role: 'assistant', content: '角色里的回答',
              createdAt: now, worldBookContextJson: rp()));
          } else if (change == 'resetCount') {
            await db.setSetting('conversation_context_reset_count', '1');
          } else {
            await db.importAll(await db.exportAll());
          }
        });
      expect(await wishState(), before);
    });
  }
  test('media path maintenance preserves the same source and permits photo completion', () async {
    await seedWish(); await db.insertMessageWithAttachments(user(), [photo()]);
    await _duringReview(start: (review) => WishEngine(db, reviewer: review).maybeRefresh(now: now),
      response: completedPhoto(), sourceId: 'photo:source:photo', succeeds: true,
      mutate: () async { await (await db.database).update('message_attachments',
        {'original_path': '/new/photo', 'thumbnail_path': '/new/thumb'}, where: 'id = ?', whereArgs: ['photo']); });
    expect((await WishStore(db).load()).single.state, 'completed');
    expect(await db.getSetting(WishEngine.fingerprintKey), isNotEmpty);
  });
  for (final kind in ['web', 'thought', 'receipt', 'catalog', 'guide', 'memory']) {
    test('Wish final snapshot checks actual $kind input', () async {
      await seedWish(route: 'game');
      await db.insertMessage(user());
      final sql = await db.database;
      String? selected;
      if (kind == 'web') { await seedWeb(semantic: 'history_only'); selected = 'web:web'; }
      if (kind == 'thought') {
        await sql.insert('thoughts', {'id': 't', 'text': '关于花朵的真实灵感', 'drive_key': 'curiosity',
          'kind': 'flit', 'strength': .8, 'born_at': now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch, 'lifecycle_state': 'active'});
        selected = 'thought:t';
      }
      if (kind == 'receipt') {
        await db.setSetting(WishGameEvidence.key, WishGameEvidence.append(raw: '', wishes: await WishStore(db).load(),
          gameId: 'white_room', eventId: 'e', action: 'look', input: '{}', output: '看见真实结果',
          at: now.subtract(const Duration(minutes: 1))));
        selected = 'game:white_room:e';
      }
      if (kind == 'guide') {
        await db.setSetting(CedarToyActivityStore.stateSettingKey, jsonEncode({'sessions': [
          {'id': 's', 'game_id': 'white_room', 'guide_complete': true, 'guide': '实际读过的完整指南'}]}));
      }
      if (kind == 'memory') {
        expect(await db.insertMemory(kind: 'shared_experience', content: '我们讨论过留住不确定的空间',
          importance: .8, tags: const []), isTrue);
        await sql.update('memory_items', {'semantic_type': 'shared_experience', 'attention_state': 'closed',
          'recall_policy': 'reminiscence', 'spontaneous_salience': .9, 'fact_state': 'historical_fact',
          'created_at': now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch});
        selected = 'memory:${(await sql.query('memory_items')).single['id']}';
      }
      final before = await wishState();
      await _duringReview(start: (review) => WishEngine(db, reviewer: (material) {
        if (kind == 'guide') expect(material['known_game_guides'], isNotEmpty);
        return review(material);
      }).maybeRefresh(now: now), sourceId: selected, response: {'updates': []}, mutate: () async {
        if (kind == 'web') await sql.delete('public_web_candidates', where: 'id = ?', whereArgs: ['web']);
        if (kind == 'thought') await sql.update('thoughts', {'lifecycle_state': 'dormant'}, where: 'id = ?', whereArgs: ['t']);
        if (kind == 'receipt') await db.setSetting(WishGameEvidence.key, '[]');
        if (kind == 'catalog') await db.setSetting(CedarToyActivityStore.catalogSettingKey, '{"changed":true}');
        if (kind == 'guide') await db.setSetting(CedarToyActivityStore.stateSettingKey, '{}');
        if (kind == 'memory') await sql.update('memory_items', {'recall_policy': 'explicit_only'});
      });
      expect(await wishState(), before);
    });
  }
  test('read inspiration keeps fourteen days, accepts Wish history only, and ignores share expiry', () async {
    await seedWeb(semantic: 'history_only');
    expect((await WishEngine(db).collect(now)).map((s) => s.id), ['web:web']);
    expect(await DeepReflectionEngine(db).collect(now), isEmpty);
    await (await db.database).update('public_web_candidates', {'semantic_state': 'valid'});
    expect((await DeepReflectionEngine(db).collect(now)).map((s) => s['id']), ['web:web']);
  });
  for (final semanticChange in [false, true]) {
    test('Wish game source ${semanticChange ? 'rejects a changed outcome' : 'survives heartbeat maintenance'}', () async {
      await seedWish(route: 'game');
      final session = <String, Object?>{'id': 's', 'game_id': 'white_room', 'events': [
        CedarGameEvent(id: 'outcome', kind: 'outcome', action: 'look', inputJson: '{}',
          summary: '看见白色花朵', createdAt: now.subtract(const Duration(minutes: 1))).toJson(),
      ]};
      await db.setSetting(CedarToyActivityStore.stateSettingKey, jsonEncode({'sessions': [session]}));
      final before = await wishState();
      await _duringReview(start: (review) => WishEngine(db, reviewer: review).maybeRefresh(now: now),
        sourceId: 'game:white_room:outcome', succeeds: !semanticChange, response: {'updates': [{
          'id': 'w', 'state': 'completed', 'evidence_id': 'game:white_room:outcome',
          'quote': '看见白色花朵', 'same_target': true, 'observed': true, 'confidence': .95,
        }]}, mutate: () async {
          if (semanticChange) {
            ((session['events'] as List).single as Map)['summary'] = '原结果已经被更正';
          } else {
            session['updated_at'] = now.millisecondsSinceEpoch;
            session['next_action_at'] = now.add(const Duration(minutes: 5)).millisecondsSinceEpoch;
          }
          await db.setSetting(CedarToyActivityStore.stateSettingKey, jsonEncode({'sessions': [session]}));
        });
      if (semanticChange) {
        expect(await wishState(), before);
      } else {
        expect((await WishStore(db).load()).single.state, 'completed');
      }
    });
  }

  for (final failure in ['throw', 'null', 'empty', 'invalid']) {
    test('Reflection $failure retains same material for retry after thirteen hours', () async {
      await db.insertMessage(user());
      var calls = 0;
      final engine = DeepReflectionEngine(db, reviewer: (_) async {
        calls++;
        if (failure == 'throw') throw StateError('offline');
        if (failure == 'null') return null;
        if (failure == 'empty') return {};
        return {'topic': {'suitable': true, 'question': '坏结构'}};
      });
      expect(await engine.maybePrepare(now: now), isFalse);
      expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNull);
      await engine.maybePrepare(now: now.add(const Duration(hours: 1)));
      expect(calls, 1);
      await engine.maybePrepare(now: now.add(const Duration(hours: 13)));
      expect(calls, 2);
      expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNull);
      expect(await db.getSetting(DeepReflectionStore.stateKey), isNull);
    });
  }
  test('valid topic null deduplicates successful evaluation and survives export import', () async {
    await db.insertMessage(user()); var calls = 0;
    final engine = DeepReflectionEngine(db, reviewer: (_) async { calls++; return {'topic': null}; });
    await engine.maybePrepare(now: now);
    final fingerprint = await db.getSetting(DeepReflectionEngine.sourcesKey);
    expect(fingerprint, isNotEmpty);
    await db.importAll(await db.exportAll());
    await engine.maybePrepare(now: now.add(const Duration(hours: 13)));
    expect(calls, 1);
    expect(await db.getSetting(DeepReflectionEngine.sourcesKey), fingerprint);
  });
  test('a successful topic keeps the three day generation gap even after pause and restore', () async {
    await db.insertMessage(user());
    var calls = 0;
    final engine = DeepReflectionEngine(db, reviewer: (_) async {
      calls++;
      if (calls == 1) return topic();
      final next = topic();
      (next['topic'] as Map).addAll({'question': '新的经历怎样改变对不确定的理解？',
        'new_angle': '这次加入了先尝试再解释的新认识', 'source_id': 'chat:new-source'});
      return next;
    });
    expect(await engine.maybePrepare(now: now), isTrue);
    final state = jsonDecode((await db.getSetting(DeepReflectionStore.stateKey))!) as Map;
    (state['topic'] as Map)['phase'] = 'paused';
    await db.setSetting(DeepReflectionStore.stateKey, jsonEncode(state));
    await db.insertMessage(ChatMessage(id: 'new-source', role: 'user',
      content: '后来发现可以保留不确定，先尝试再理解也有意义', createdAt: now.add(const Duration(days: 1))));
    await db.importAll(await db.exportAll());
    final pausedRaw = await db.getSetting(DeepReflectionStore.stateKey);
    expect(await engine.maybePrepare(now: now.add(const Duration(days: 2))), isFalse);
    expect(calls, 1);
    expect(await db.getSetting(DeepReflectionStore.stateKey), pausedRaw);
    expect(await engine.maybePrepare(now: now.add(const Duration(days: 3, hours: 1))), isTrue,
      reason: 'calls=$calls diagnostic=${await db.getSetting(DeepReflectionStore.diagnosticKey)} sources=${await engine.collect(now.add(const Duration(days: 3, hours: 1)))}');
    expect(calls, 2);
    final saved = jsonDecode((await db.getSetting(DeepReflectionStore.stateKey))!) as Map;
    expect(saved['topic']['source_id'], 'chat:new-source');
    expect(saved['history'], hasLength(1));
    expect(saved['history'][0]['phase'], 'paused');
  });
  for (final change in ['suffix', 'roleplay', 'deleted', 'web', 'dream']) {
    test('Reflection $change after model input rejects topic history and completed fingerprint', () async {
      await db.insertMessage(user(text: '我觉得可以保留不确定${'原' * 900}旧后缀'));
      if (change == 'web') await seedWeb();
      if (change == 'dream') {
        final row = (await (await db.database).query('messages', where: 'id = ?', whereArgs: ['source'])).single;
        final source = DreamStore.chatSource(row)!;
        await db.setSetting(DreamStore.stateKey, jsonEncode({'insights': [
          {'id': 'understanding', 'stance': 'tentative', 'understanding': '可以保留暂时不确定的看法',
            'choice': '', 'uncertainty': '', 'evidence': [{'id': source.id, 'fingerprint': source.fingerprint}]}]}));
      }
      await _duringReview(start: (review) => DeepReflectionEngine(db, reviewer: (material) {
        if (change == 'dream') expect(material['current_self_understanding'], contains('保留暂时不确定'));
        return review(material);
      }).maybePrepare(now: now), sourceId: 'chat:source', response: topic(), mutate: () async {
        final sql = await db.database;
        if (change == 'suffix') await db.insertMessage(user(text: '我觉得可以保留不确定${'原' * 900}新后缀'));
        if (change == 'roleplay') await sql.update('messages', {'worldbook_context_json': rp()}, where: 'id = ?', whereArgs: ['source']);
        if (change == 'deleted') await sql.delete('messages', where: 'id = ?', whereArgs: ['source']);
        if (change == 'web') await sql.delete('public_web_candidates', where: 'id = ?', whereArgs: ['web']);
        if (change == 'dream') await db.setSetting(DreamStore.stateKey, '{}');
      });
      expect(await db.getSetting(DeepReflectionStore.stateKey), isNull);
      expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNull);
    });
  }
  for (final change in ['interaction', 'source', 'reset']) {
  test('Reflection final transaction refuses queued $change after preliminary checks', () async {
    await db.insertMessage(user());
    final entered = Completer<void>(), release = Completer<void>();
    Future<void>? blocker;
    final sql = await db.database;
    final operation = DeepReflectionEngine(db, reviewer: (_) async => topic(), beforeCommit: () async {
      blocker = sql.transaction((txn) async {
        if (change == 'interaction') {
          await txn.insert('interaction_sessions', {'id': 'new-session', 'kind': 'roleplay', 'title': '新场景',
            'status': 'active', 'started_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch});
        } else if (change == 'source') {
          await txn.update('messages', {'content': '原先的来源内容已经被改写'}, where: 'id = ?', whereArgs: ['source']);
        } else {
          await txn.insert('settings', {'key': 'conversation_context_reset_count', 'value': '1'},
            conflictAlgorithm: ConflictAlgorithm.replace);
        }
        entered.complete(); await release.future.timeout(_limit);
      });
      await _arrived(entered, blocker!);
    }).maybePrepare(now: now);
    var failed = false;
    try {
      await _arrived(entered, operation);
      release.complete();
      expect(await operation.timeout(_limit), isFalse);
      if (change == 'interaction') expect(await db.activeInteractionSession(), isNotNull);
      if (change == 'source') expect((await sql.query('messages', where: 'id = ?',
        whereArgs: ['source'])).single['content'], '原先的来源内容已经被改写');
      if (change == 'reset') expect(await db.getSetting('conversation_context_reset_count'), '1');
      expect(await db.getSetting(DeepReflectionStore.stateKey), isNull);
      expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNull);
    } catch (_) { failed = true; rethrow; }
    finally {
      if (!release.isCompleted) release.complete();
      try { await Future.wait([operation, if (blocker != null) blocker!]).timeout(_limit); }
      catch (_) { if (!failed) rethrow; }
    }
  });
  }
  test('restored in-flight preparation keeps its cooldown but does not consume the material', () async {
    await db.insertMessage(user());
    Map<String, dynamic>? interruptedSnapshot;
    await _duringReview(start: (review) => DeepReflectionEngine(db, reviewer: review).maybePrepare(now: now),
      response: {}, sourceId: 'chat:source', mutate: () async {
        interruptedSnapshot = await db.exportAll();
        expect(jsonDecode((await db.getSetting(DeepReflectionEngine.attemptStateKey))!)['phase'], 'preparing');
      });
    await db.importAll(interruptedSnapshot!);
    expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNull);
    final oldAttempt = jsonDecode((await db.getSetting(DeepReflectionEngine.attemptStateKey))!) as Map;
    expect(oldAttempt['phase'], 'preparing');
    await db.setSetting(DeepReflectionEngine.legacySourcesKey, oldAttempt['fingerprint'] as String);
    var calls = 0;
    final recovered = DeepReflectionEngine(db, reviewer: (_) async { calls++; return {'topic': null}; });
    expect(await recovered.maybePrepare(now: now.add(const Duration(hours: 1))), isFalse);
    expect(calls, 0);
    expect(await recovered.maybePrepare(now: now.add(const Duration(hours: 13))), isFalse);
    expect(calls, 1);
    expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNotEmpty);
    expect(jsonDecode((await db.getSetting(DeepReflectionEngine.attemptStateKey))!)['phase'], 'no_topic');
  });
  test('expired old preparation cannot release or overwrite a newer DB host attempt', () async {
    final directory = await Directory.systemTemp.createTemp('reflection-ownership-');
    const channel = MethodChannel('ai_companion/system');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async =>
        call.method == 'runtimeProcessEpoch' ? 'reflection-test-process' : null);
    AppDatabase? other;
    Future<bool>? oldOperation, newOperation;
    final oldEntered = Completer<void>(), newEntered = Completer<void>();
    final oldResponse = Completer<Map<String, dynamic>?>(), newResponse = Completer<Map<String, dynamic>?>();
    var failed = false;
    try {
      await db.closeForTesting();
      final path = '${directory.path}/shared.db';
      db = await AppDatabase.createForTesting(databaseFactoryFfi, path: path);
      other = await AppDatabase.createForTesting(databaseFactoryFfi, path: path, reopenExisting: true);
      await db.insertMessage(user());
      oldOperation = DeepReflectionEngine(db, reviewer: (_) {
        oldEntered.complete(); return oldResponse.future;
      }).maybePrepare(now: now);
      await _arrived(oldEntered, oldOperation);
      final oldLease = (await db.getSetting(DeepReflectionEngine.leaseKey))!;
      // Simulate expiry, preserving the actual acquired owner token. Re-entry
      // on the same AppDatabase must still be rejected by its owned-token map.
      await db.setSetting(DeepReflectionEngine.leaseKey, '${oldLease.split('|').first}|0');
      expect(await db.tryAcquireLocalLease(DeepReflectionEngine.leaseKey), isFalse);
      newOperation = DeepReflectionEngine(other, reviewer: (_) {
        newEntered.complete(); return newResponse.future;
      }).maybePrepare(now: now.add(const Duration(hours: 13)));
      await _arrived(newEntered, newOperation);
      final newLease = await other.getSetting(DeepReflectionEngine.leaseKey);
      final newReceipt = await other.getSetting(DeepReflectionEngine.attemptStateKey);
      final newDiagnostic = await other.getSetting(DeepReflectionStore.diagnosticKey);
      expect(newLease!.split('|').first, isNot(oldLease.split('|').first));
      oldResponse.complete(topic());
      expect(await oldOperation.timeout(_limit), isFalse);
      expect(await other.getSetting(DeepReflectionEngine.leaseKey), newLease);
      expect(await other.getSetting(DeepReflectionEngine.attemptStateKey), newReceipt);
      expect(await other.getSetting(DeepReflectionStore.diagnosticKey), newDiagnostic);
      expect(await other.getSetting(DeepReflectionStore.stateKey), isNull);
      newResponse.complete({'topic': null});
      expect(await newOperation.timeout(_limit), isFalse);
      expect(await other.getSetting(DeepReflectionEngine.sourcesKey), isNotEmpty);
    } catch (_) { failed = true; rethrow; }
    finally {
      if (!oldResponse.isCompleted) oldResponse.complete(null);
      if (!newResponse.isCompleted) newResponse.complete(null);
      try {
        await Future.wait([if (oldOperation != null) oldOperation, if (newOperation != null) newOperation]).timeout(_limit);
      } catch (_) { if (!failed) rethrow; }
      finally {
        await other?.closeForTesting();
        await db.closeForTesting();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    }
  });
  test('Reflection failed SQLite commit rolls back topic and completed fingerprint together', () async {
    await db.insertMessage(user());
    await (await db.database).execute('''CREATE TRIGGER reject_topic BEFORE INSERT ON settings
      WHEN NEW.key = '${DeepReflectionStore.stateKey}' BEGIN SELECT RAISE(ABORT, 'fixture failure'); END''');
    expect(await DeepReflectionEngine(db, reviewer: (_) async => topic()).maybePrepare(now: now), isFalse);
    expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNull);
    expect(await db.getSetting(DeepReflectionStore.stateKey), isNull);
  });
  test('Reflection ordinary valid topic succeeds while a future message stays outside input', () async {
    await db.insertMessage(user());
    await db.insertMessage(ChatMessage(id: 'future', role: 'assistant', isProactive: true,
      content: '未来的事情不能提前知道', createdAt: now.add(const Duration(days: 1))));
    expect(await DeepReflectionEngine(db, reviewer: (material) async {
      expect((material['sources'] as List).cast<Map>().map((s) => s['id']), isNot(contains('chat:future')));
      return topic();
    }).maybePrepare(now: now), isTrue);
    expect(await db.getSetting(DeepReflectionEngine.sourcesKey), isNotEmpty);
    expect(jsonDecode((await db.getSetting(DeepReflectionStore.stateKey))!)['topic']['phase'], 'ready');
  });
  test('corrupt optional Dream evidence is omitted without blocking ordinary reflection', () async {
    await db.insertMessage(user());
    await db.setSetting(DreamStore.stateKey, jsonEncode({'insights': [
      {'id': 'broken', 'understanding': '缺少来源的可选认识', 'evidence': [{}]},
    ]}));
    expect(await DeepReflectionEngine(db, reviewer: (material) async {
      expect(material['current_self_understanding'], isEmpty);
      return topic();
    }).maybePrepare(now: now), isTrue);
  });
  test('known future memory cannot be the sole new event after a clock rollback', () async {
    expect(await db.insertMemory(kind: 'shared_experience', content: '我们讨论过可以保留不确定',
      importance: .8, semanticType: 'shared_experience',
      sourceObservedAt: now.add(const Duration(days: 1))), isTrue);
    await (await db.database).update('memory_items', {'attention_state': 'closed',
      'recall_policy': 'reminiscence', 'spontaneous_salience': .9});
    var calls = 0;
    final engine = DeepReflectionEngine(db, reviewer: (_) async { calls++; return {'topic': null}; });
    expect(await engine.collect(now), isEmpty);
    expect(await engine.maybePrepare(now: now), isFalse);
    expect(calls, 0);
    await (await db.database).update('memory_items', {
      'last_evidence_at': now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      'first_observed_at': now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    });
    await engine.maybePrepare(now: now);
    expect(calls, 1);
  });
}
