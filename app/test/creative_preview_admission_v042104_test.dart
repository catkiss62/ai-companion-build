import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_delivery.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'creative_agent_test.dart' as fixture;

/// Runs real worker tools and SQLite publication against controlled native
/// observations. It proves Dart admission, not execution of WebView JavaScript.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture-only'});
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview, null);
    await db.closeForTesting();
  });
  Future<Map<String, dynamic>> commission(String interaction) => store.commission(
    deepThinking: true, requestId: 'request', messageId: 'card', brief: '一盏灯',
    requestQuote: '一盏灯', latestText: '做一盏灯', interaction: interaction);
  CreativeWorker worker(List<Map<String, dynamic>> calls) => CreativeWorker(db,
    clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
      streamClientFactory: () => MockClient((_) async => fixture.response(fixture.sse(calls)))));
  Future<Map<String, dynamic>> state(String id) async =>
    CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
  List<Map<String, dynamic>> makeCalls(String interaction) => [fixture.plan(interaction: interaction),
    fixture.write(fixture.repaired), fixture.previewCall(), fixture.call('work_finish', {})];
  const measuredCounts = {'choose_count': 1, 'reveal_count': 1, 'save_count': 1, 'reload_count': 1};

  final defects = <String, Map<String, Object?>>{
    'old count-only proof': {'proof_version': 1},
    'different source': {'source_hash': 'wrong-source'},
    'missing cold baseline': {'baseline_verified': false},
    'missing saved checkpoint': {'checkpoint_verified': false},
    'ignored initialState': {'restore_verified': false, 'restored_count': 0},
    'unchanged title only': {'changed_count': 0},
    'no successful save receipt': {'save_seq': 0},
    'save receipt beyond successful saves': {'save_seq': 2},
    'no independent cold reload': {'reload_generation': 0},
    'initial page generation is not a reload': {'reload_generation': 1},
    'zero reloads contradict restore proof': {'reload_count': 0},
    'exercise reload counted as proof': {'proof_phase': 'exercise'},
    'missing assertion evidence': {'assertion_count': 0, 'restored_count': 0},
    'different assertion set': {'assertion_count': 2, 'restored_count': 2, 'changed_count': 1},
    'companion cannot become stateless': {'restore_required': false, 'proof_phase': 'stateless'},
  };
  for (final defect in defects.entries) {
    test('worker rejects ${defect.key} before publication or completion notice', () async {
      final work = await commission('companion'); final id = work['id'] as String;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        CreativeWorker.preview, (method) async => fixture.nativePreviewResult(method.arguments,
          {...measuredCounts, ...defect.value}));
      await worker(makeCalls('companion')).runOnce();
      final current = await store.get(id);
      expect(current['status'], isNot('ready')); expect(current['current'], isNull);
      expect((await state(id))['verification']['ok'], isFalse);
      expect(CreativeContract.decode(await db.getSetting(CreativeDelivery.key(id))), isEmpty);
      expect(CreativeContract.decode(await db.getSetting('${CreativeContract.receiptPrefix}card'))['completed'], isFalse);
    });
  }

  test('local save requires restoration even without companion choose/reveal', () async {
    final work = await commission('local'); final id = work['id'] as String;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (method) async => fixture.nativePreviewResult(method.arguments,
        {'save_count': 1, 'restore_verified': false, 'restored_count': 0}));
    await worker(makeCalls('local')).runOnce();
    expect((await store.get(id))['current'], isNull);
    expect((await state(id))['verification']['ok'], isFalse);
  });

  test('local stateful proof also needs an actual reload count', () async {
    final work = await commission('local'); final id = work['id'] as String;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (method) async => fixture.nativePreviewResult(method.arguments,
        {'save_count': 1, 'reload_count': 0}));
    await worker(makeCalls('local')).runOnce();
    expect((await store.get(id))['current'], isNull);
    expect((await state(id))['verification']['ok'], isFalse);
  });

  for (final interaction in ['local', 'companion']) {
    test('current v2 $interaction proof publishes only measured public proof fields', () async {
      final work = await commission(interaction); final id = work['id'] as String;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        CreativeWorker.preview, (method) async => fixture.nativePreviewResult(method.arguments,
          {if (interaction == 'companion') ...measuredCounts,
            'saved_state': {'secret_fixture': 'NOT_FOR_PROOF_LOG'}}));
      await worker(makeCalls(interaction)).runOnce();
      expect((await store.get(id))['status'], 'ready');
      final notice = CreativeContract.decode(await db.getSetting(CreativeDelivery.key(id)));
      expect(notice['proof']['proof_version'], 2);
      expect(notice['proof']['source_hash'], (await store.get(id))['current']);
      expect(notice['proof']['restore_required'], interaction == 'companion');
      expect(jsonEncode(notice['proof']), isNot(contains('NOT_FOR_PROOF_LOG')));
      expect(jsonEncode((await state(id))['verification']), isNot(contains('NOT_FOR_PROOF_LOG')));
    });
  }

  test('old persisted successful counts cannot finish after upgrade without a new preview', () async {
    final work = await commission('companion'); final id = work['id'] as String;
    final agent = CreativeWorkspace.create(id, work['request_id'] as String, html: fixture.repaired);
    agent['plan'] = {'title': '灯', 'intro': '亮起', 'plan': '恢复灯', 'interaction': 'companion'};
    final hash = CreativeContract.hash(CreativeWorkspace.assemble(agent));
    agent['verification'] = {'ok': true, 'hash': hash, ...measuredCounts};
    await store.write(work, {...work, 'status': 'building'}, extra: {CreativeWorkspace.key(id): jsonEncode(agent)});
    await worker([fixture.call('work_finish', {})]).runOnce();
    expect((await store.get(id))['current'], isNull);
    expect(jsonEncode((await state(id))['feedback']), contains('版本2'));
  });
}
