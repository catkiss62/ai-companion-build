import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_delivery.dart';
import 'package:ai_companion_localfirst/core/creative/creative_facts.dart';
import 'package:ai_companion_localfirst/core/creative/creative_play.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-only'});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
  });
  tearDown(() async => db.closeForTesting());

  Future<Map<String, dynamic>> work(String title, {bool ready = true, int updated = 1}) async {
    final before = await store.commission(deepThinking: true, requestId: title,
      messageId: 'a:$title', userMessageId: 'u:$title', brief: title,
      requestQuote: title, latestText: title);
    final html = '<p>SOURCE_ONLY_$title</p>';
    final version = CreativeContract.hash(html);
    final after = {...before, 'title': title, 'intro': '一起体验$title', 'updated': updated,
      'status': ready ? 'ready' : 'queued',
      if (ready) 'current': version, 'versions': ready ? [version] : <String>[]};
    await store.write(before, after, extra: {
      if (ready) '${CreativeContract.sourcePrefix}$version': html});
    return after;
  }

  Future<void> played(Map w) async {
    await db.setSetting('${CreativeContract.playPrefix}${w['id']}', jsonEncode({
      'schema': 1, 'version': w['current'], 'session_id': 'played-session',
      'public': {'score': 17, 'detail': 'PAGE_DETAIL_SECRET'},
      'turns': {'1': {'choice': 'right', 'playerChoice': 'left', 'at': 1},
        '2': {'choice': 'SEALED_SECRET', 'at': 2}}, 'reports': []}));
  }

  Map<String, dynamic> projection(String text) =>
      Map<String, dynamic>.from(jsonDecode(text.substring(text.indexOf('\n{') + 1)) as Map);

  test('legacy completed work needs no delivery text; usage is coarse and does not leak details', () async {
    final w = await work('星光迷宫'); await played(w);
    final text = await store.chatContext();
    final fact = (projection(text)['works'] as List).single;
    expect(fact['has_published'], true);
    expect(fact['current_request_completed'], true);
    expect(fact['announcement'], 'not_recorded');
    expect(fact['use_evidence']['revealed_interaction'], true);
    for (final secret in ['SOURCE_ONLY_', 'PAGE_DETAIL_SECRET', 'SEALED_SECRET', '"score"']) {
      expect(text, isNot(contains(secret)));
    }
    expect(await db.getSetting(CreativeDelivery.key(w['id'] as String)), '');
    expect(await db.recentMessages(limit: 10), isEmpty);
  });

  test('relevant older works outrank five new jobs and omissions are explicit', () async {
    final old = await work('雨夜灯塔', updated: 1);
    for (var i = 0; i < 7; i++) { await work('任务$i', ready: false, updated: 100 + i); }
    final facts = projection(await store.chatContext(query: '雨夜灯塔是不是还没做？'));
    expect((facts['works'] as List).first['id'], old['id']);
    expect(facts['omitted_count'], 3);
    expect((facts['works'] as List).length, CreativeFacts.limit);
  });

  test('revision pause preserves the published version without calling the revision completed', () async {
    final w = await work('风铃卡片'); await played(w);
    await store.commission(deepThinking: true, requestId: 'revision', messageId: 'a:revision',
      brief: '增加夜景', requestQuote: '增加夜景', latestText: '增加夜景', workId: w['id'] as String);
    await store.stop(w['id'] as String);
    final fact = (projection(await store.chatContext())['works'] as List).single;
    expect(fact['status'], 'paused');
    expect(fact['has_published'], true);
    expect(fact['current_request_completed'], false);
    expect(fact['use_evidence']['version_scope'], 'published_version');
  });

  test('pending or cancelled announcement does not undo completed work', () async {
    final w = await work('星河贺卡');
    for (final status in ['pending', 'cancelled', 'delivered']) {
      await db.setSetting(CreativeDelivery.key(w['id'] as String), jsonEncode({
        ...CreativeDelivery.pending(w, w['current'] as String, {}, 5), 'status': status}));
      final fact = (projection(await store.chatContext())['works'] as List).single;
      expect(fact['current_request_completed'], true);
      expect(fact['announcement'], status);
    }
  });

  test('autonomous share is a delivered announcement and survives archive restore', () async {
    final w = await work('树叶小灯');
    await store.write(w, {...w, 'origin': 'autonomous', 'visibility': 'private',
      'idea_id': 'leaf-idea', 'motive': '想留下这个颜色'});
    await store.setAutonomyEnabled(true);
    final now = DateTime.now();
    final share = await store.claimShare(w['id'] as String, now);
    expect(share, isNotNull);
    expect(projection(await store.chatContext())['visible_count'], 0);
    expect(await db.commitProactiveMessageIfCurrent(
      message: ChatMessage(id: 'leaf-gift', role: 'assistant', content: '给你做了一盏树叶小灯。',
        createdAt: now, isProactive: true), evaluationStartedAt: now, creativeShare: share), isNull);
    expect(await db.getSetting(CreativeDelivery.key(w['id'] as String)), '');
    var fact = (projection(await store.chatContext())['works'] as List).single;
    expect(fact['announcement'], 'delivered');
    expect(fact['current_request_completed'], true);
    await db.importAll(Map<String, dynamic>.from(await db.exportAll()));
    fact = (projection(await store.chatContext())['works'] as List).single;
    expect(fact['announcement'], 'delivered');
    expect(await store.shareCandidates(now.add(const Duration(days: 1))), isEmpty);
  });

  test('announcement receipt requires the same work request version and actual assistant message', () async {
    final w = await work('云朵灯');
    await store.write(w, {...w, 'completion_message_id': 'gift-message'});
    final receipt = {'message_id': 'gift-message', 'work_id': w['id'],
      'request_id': w['request_id'], 'version': w['current'], 'kind': 'delivered'};
    final receiptKey = '${CreativeContract.receiptPrefix}gift-message';
    Future<Object?> announcement() async =>
        (projection(await store.chatContext())['works'] as List).single['announcement'];
    await db.setSetting(receiptKey, jsonEncode(receipt));
    expect(await announcement(), 'not_recorded'); // Receipt without its message.
    await db.insertMessage(ChatMessage(id: 'gift-message', role: 'user',
      content: '这是用户的文字', createdAt: DateTime.now()));
    expect(await announcement(), 'not_recorded');
    await (await db.database).update('messages', {'role': 'assistant'},
      where: 'id = ?', whereArgs: ['gift-message']);
    expect(await announcement(), 'delivered');
    for (final field in ['message_id', 'work_id', 'request_id', 'version', 'kind']) {
      await db.setSetting(receiptKey, jsonEncode({...receipt, field: 'stale'}));
      expect(await announcement(), 'not_recorded', reason: field);
    }
    await db.setSetting(receiptKey, '');
    expect(await announcement(), 'not_recorded'); // Metadata ID alone is not evidence.
  });

  test('private and deleted works never enter facts, including related-source lookup', () async {
    final hidden = await work('PRIVATE_GIFT');
    await store.write(hidden, {...hidden, 'origin': 'autonomous', 'visibility': 'private',
      'idea_id': 'idea', 'motive': 'PRIVATE_MOTIVE'});
    final deleted = await work('DELETED_WORK'); await store.delete(deleted['id'] as String);
    final text = await store.chatContext(query: 'PRIVATE_GIFT DELETED_WORK');
    expect(projection(text)['visible_count'], 0);
    expect(text, isNot(contains('PRIVATE_GIFT')));
    expect(text, isNot(contains('DELETED_WORK')));
    expect(await store.chatContext(query: 'PRIVATE_GIFT', relevantOnly: true), isEmpty);
  });

  test('ordinary and fresh-topic proactive prompts both verify the selected source', () async {
    await work('星光迷宫');
    await work('UNRELATED_CARD');
    final user = ChatMessage(id: 'current', role: 'user', content: '星光迷宫做好了吗', createdAt: DateTime.now());
    await db.insertMessage(user);
    for (final proactive in [false, true]) {
      final built = await PromptBuilder(db).buildChatPrompt(
        latestUserText: proactive ? '' : user.content,
        retrievalQuery: proactive ? '星光迷宫还没做好，只是口头玩过' : null,
        recent: proactive ? const [] : [user], desire: await db.loadDesire(), thoughts: const [],
        mode: proactive ? PromptGenerationMode.proactive : PromptGenerationMode.userTurn,
        freshTopicSourceOnly: proactive);
      final sections = built.messages.where((m) => m['content'].toString().contains(CreativeFacts.authority)).toList();
      expect(sections, hasLength(1));
      expect(sections.single['content'], contains('"current_request_completed":true'));
      if (proactive) {
        expect(sections.single['content'], isNot(contains('UNRELATED_CARD')));
      } else {
        expect(built.messages.last['role'], 'user');
      }
    }
    expect(await store.chatContext(query: '天文学的新发现', relevantOnly: true), isEmpty);
  });

  test('experience extraction actually receives work facts and only this user message snapshot', () async {
    final w = await work('星光迷宫'); await played(w);
    final play = CreativePlay(db, w['id'] as String); await play.open();
    final snap = await play.captureSnapshot();
    final user = ChatMessage(id: 'inside', role: 'user', content: '这局结束啦', createdAt: DateTime.now());
    final assistant = ChatMessage(id: 'answer', role: 'assistant', content: '下次再一起玩。', createdAt: DateTime.now());
    await db.setSetting('${CreativeContract.chatPrefix}${user.id}', jsonEncode(snap.data));
    for (var i = 0; i < 6; i++) { await work('新任务$i', ready: false, updated: 100 + i); }
    await db.insertMessage(user); await db.insertMessage(assistant);
    await db.setSetting('post_turn_queue_enabled', '0');
    // Avoid unrelated maintenance/model calls; the same extraction prompt is
    // used when durable memories are enabled.
    await db.setSetting('auto_memory', '0');
    final requests = <String>[];
    final client = DeepSeekClient(client: MockClient((request) async {
      requests.add(request.body);
      return http.Response(jsonEncode({'choices': [{'message': {'content': '{}'}, 'finish_reason': 'stop'}]}),
        200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
    await extractor.extractFromTurn(user: user, assistant: assistant);
    expect(requests, hasLength(1));
    expect(requests.single, contains('current_request_completed'));
    expect(requests.single, contains('PAGE_DETAIL_SECRET'));
    expect(requests.single, isNot(contains('SEALED_SECRET')));
    expect(await db.getSetting('last_memory_error'), '');
    requests.clear();
    await extractor.extractFromTurn(user: ChatMessage(id: 'outside', role: 'user',
      content: '星光迷宫很好玩', createdAt: DateTime.now()), assistant: assistant);
    expect(requests, hasLength(1));
    expect(requests.single, contains('星光迷宫'));
    expect(requests.single, isNot(contains('PAGE_DETAIL_SECRET')));
    client.close();
  });

  test('archive roundtrip keeps public facts, private isolation and message-scoped snapshots', () async {
    final w = await work('星光迷宫'); await played(w);
    final play = CreativePlay(db, w['id'] as String); await play.open();
    final snapshot = await play.captureSnapshot();
    final user = ChatMessage(id: 'snapshot-user', role: 'user', content: '这局如何', createdAt: DateTime.now());
    await db.createGenerationTurn(user: user, assistantMessageId: 'snapshot-answer',
      model: 'deepseek-flash', reasoningEffort: 'max', creativeContext: snapshot.data, creativeFence: snapshot.fence);
    final private = await work('PRIVATE_ARCHIVE_GIFT');
    await store.write(private, {...private, 'origin': 'autonomous', 'visibility': 'private', 'idea_id': 'idea', 'motive': 'gift'});
    final before = await store.chatContext();
    final backup = await db.exportAll();
    await db.importAll(Map<String, dynamic>.from(backup));
    expect(await store.chatContext(), before);
    expect(await CreativePlay.chatContext(db, userMessageId: user.id), contains('PAGE_DETAIL_SECRET'));
    expect(await CreativePlay.chatContext(db), isEmpty);
    expect(await store.chatContext(), isNot(contains('PRIVATE_ARCHIVE_GIFT')));
    expect((await store.list(includePrivate: true)).length, 2);
  });

  test('new version marks old use as historical, and restart cannot invent previous scores', () async {
    final w = await work('星光迷宫'); await played(w);
    const html = '<p>new version</p>'; final version = CreativeContract.hash(html);
    await store.write(w, {...w, 'current': version, 'versions': [w['current'], version]},
      extra: {'${CreativeContract.sourcePrefix}$version': html});
    var fact = (projection(await store.chatContext())['works'] as List).single;
    expect(fact['use_evidence']['version_scope'], 'earlier_version');
    await CreativePlay(db, w['id'] as String).open(restart: true);
    fact = (projection(await store.chatContext())['works'] as List).single;
    expect(fact.containsKey('use_evidence'), false);
    expect(fact['current_request_completed'], true);
  });

  test('outbound guard accepts proven local play, without granting external operations or false recency', () async {
    final w = await work('星光迷宫'); await played(w);
    final read = await CreativeFacts(db).read(query: '星光迷宫还没玩过', relevantOnly: true);
    bool allowed(String text) => OperationalClaimGroundingGuard.evaluate(
        text: text, creativePlayEvidence: read.playEvidence).allowed;
    expect(allowed('昨晚这局我赢了。'), true);
    expect(allowed('我刚刚玩了一局游戏。'), false); // Recorded interaction is old.
    expect(allowed('我正在游戏里玩。'), false); // A record is not live activity.
    expect(allowed('我刚才钓了一条鱼。'), false);
    expect(allowed('我在游戏厅玩了一局游戏。'), false);
    expect(allowed('我已经成功调用MCP了。'), false);
    expect(OperationalClaimGroundingGuard.removeUnsupportedSentences(
      text: '昨晚这局我赢了。', creativePlayEvidence: read.playEvidence), '昨晚这局我赢了。');
    final unrelated = await CreativeFacts(db).read(query: '陌生的竞技赛事', relevantOnly: true);
    expect(OperationalClaimGroundingGuard.evaluate(text: '这局我赢了。',
      creativePlayEvidence: unrelated.playEvidence).allowed, false);
    final catalog = await CreativeFacts(db).read();
    expect(OperationalClaimGroundingGuard.evaluate(text: '这局我赢了。',
      creativePlayEvidence: catalog.playEvidence).allowed, false);
    expect(OperationalClaimGroundingGuard.evaluate(text: '之前玩了星光迷宫这个游戏。',
      creativePlayEvidence: catalog.playEvidence).allowed, true);
  });

  test('guard uses revealed timestamps and never accepts a future timestamp as just now', () async {
    final w = await work('星光迷宫'); await played(w);
    final now = DateTime.now();
    final key = '${CreativeContract.playPrefix}${w['id']}';
    final state = CreativeContract.decode(await db.getSetting(key));
    for (final offset in [-1000, 1000]) {
      state['turns']['1']['revealed_at'] = now.millisecondsSinceEpoch + offset;
      await db.setSetting(key, jsonEncode(state));
      final read = await CreativeFacts(db).read(query: '星光迷宫', relevantOnly: true);
      expect(OperationalClaimGroundingGuard.evaluate(text: '刚刚玩了一局游戏。',
        creativePlayEvidence: read.playEvidence, now: now).allowed, offset < 0);
      for (final external in ['我刚才钓了一条鱼。', '我现在就进去开局。']) {
        expect(OperationalClaimGroundingGuard.evaluate(text: external,
          creativePlayEvidence: read.playEvidence, now: now).allowed, false);
      }
    }
  });

  test('real fresh-topic prompt carries typed play proof; private work and empty new round do not', () async {
    final w = await work('星光迷宫'); await played(w);
    final built = await PromptBuilder(db).buildChatPrompt(latestUserText: '',
      retrievalQuery: '星光迷宫没做好，想继续玩', recent: const [], desire: await db.loadDesire(),
      thoughts: const [], mode: PromptGenerationMode.proactive, freshTopicSourceOnly: true);
    expect(OperationalClaimGroundingGuard.evaluate(text: '昨晚这局我赢了。',
      creativePlayEvidence: built.creativePlayEvidence).allowed, true);
    final play = CreativePlay(db, w['id'] as String); await play.open(restart: true);
    final snap = await play.captureSnapshot();
    await db.setSetting('${CreativeContract.chatPrefix}new-round', jsonEncode(snap.data));
    final newRound = await CreativeFacts(db).read(userMessageId: 'new-round');
    expect(newRound.playEvidence.supports('这局我赢了。'), false);
    await store.write(await store.get(w['id'] as String), {...w, 'origin': 'autonomous',
      'visibility': 'private', 'idea_id': 'idea', 'motive': 'gift'});
    final private = await CreativeFacts(db).read(query: '星光迷宫', userMessageId: 'new-round', relevantOnly: true);
    expect(private.playEvidence.works, isEmpty);
    expect(private.playEvidence.scopedAt, isNull);
  });
}
