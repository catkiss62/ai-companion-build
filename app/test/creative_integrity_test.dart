import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_play.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/portable_companion_storage.dart';
import 'package:ai_companion_localfirst/core/storage/snapshot_restore_journal.dart';
import 'package:ai_companion_localfirst/core/sync/snapshot_restore_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  late String id;
  const html = '<p>完整作品</p>';
  const oldHtml = '<p>旧版作品</p>';
  final version = CreativeContract.hash(html);
  final oldVersion = CreativeContract.hash(oldHtml);
  const options = ['石头', '剪刀', '布'];

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-only'});
    final work = await store.commission(deepThinking: true, requestId: 'integrity', messageId: 'commission',
      brief: '作品', requestQuote: '作品', latestText: '作品');
    id = work['id'] as String;
    await store.write(work, {...work, 'current': version, 'versions': [version], 'status': 'ready'},
      extra: {'${CreativeContract.sourcePrefix}$version': html});
  });
  tearDown(() async => db.closeForTesting());

  Future<Map<String, dynamic>> backup() async => jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
  List<dynamic> settings(Map<String, dynamic> archive) => (archive['tables'] as Map)['settings'] as List;
  Future<Object?> event(CreativePlay play, String kind, Object? data) =>
      play.event(version, jsonEncode({'kind': kind, 'data': data}));
  http.Response response() => http.Response(jsonEncode({'choices': [{'message': {
    'content': jsonEncode({'choice': '石头'})}}]}), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

  for (final field in ['current', 'draft', 'versions']) {
    test('missing commissioned $field source rejects before changing the live database', () async {
      if (field != 'current') {
        final work = await store.get(id);
        await store.write(work, {...work, field: field == 'versions' ? [version, oldVersion] : oldVersion},
          extra: {'${CreativeContract.sourcePrefix}$oldVersion': oldHtml});
      }
      final missing = field == 'current' ? version : oldVersion;
      final broken = await backup();
      settings(broken).removeWhere((r) => r['key'] == '${CreativeContract.sourcePrefix}$missing');
      await db.setSetting('creative_integrity_marker', 'live-state');
      await expectLater(db.importAll(broken), throwsFormatException);
      expect(await db.getSetting('creative_integrity_marker'), 'live-state');
      expect((await store.get(id))['current'], version);
      expect(await db.getSetting('${CreativeContract.sourcePrefix}$missing'), field == 'current' ? html : oldHtml);
    });
  }

  test('older playable source outside the version list survives collection and restore', () async {
    final work = await store.get(id);
    await store.write(work, {...work, 'current': oldVersion, 'versions': [oldVersion]},
      extra: {'${CreativeContract.sourcePrefix}$oldVersion': oldHtml});
    final play = CreativePlay(db, id);
    await play.open();
    await play.event(oldVersion, jsonEncode({'kind': 'save', 'data': {'score': 7}}));
    final oldWork = await store.get(id);
    await store.write(oldWork, {...oldWork, 'current': version, 'versions': [version]},
      extra: {'${CreativeContract.sourcePrefix}$version': html});
    await store.collectUnusedSources();
    expect(await db.getSetting('${CreativeContract.sourcePrefix}$oldVersion'), oldHtml);
    final good = await backup();
    final broken = await backup();
    settings(broken).removeWhere((r) => r['key'] == '${CreativeContract.sourcePrefix}$oldVersion');
    await expectLater(db.importAll(broken), throwsFormatException);
    await db.importAll(good);
    final reopened = await CreativePlay(db, id).open();
    expect(reopened['version'], oldVersion);
    expect(reopened['public'], {'score': 7});
  });

  test('legacy queued work without source and historical receipts remain importable', () async {
    final work = await store.get(id);
    final legacy = {...work, 'status': 'queued', 'current': '', 'draft': ''}
      ..remove('origin')..remove('visibility')..remove('versions');
    await store.write(work, legacy);
    await db.setSetting('${CreativeContract.receiptPrefix}historical', jsonEncode({
      'message_id': 'historical', 'work_id': id, 'version': oldVersion, 'kind': 'delivered'}));
    await db.importAll(await backup());
    expect((await store.list()).single['status'], 'paused');
    expect(await db.getSetting('${CreativeContract.receiptPrefix}historical'), isNotEmpty);
  });

  test('missing source or an empty completed version cannot create a play session', () async {
    final work = await store.get(id);
    await store.write(work, {...work, 'current': oldVersion});
    await expectLater(CreativePlay(db, id).open(), throwsFormatException);
    expect(await db.getSetting('${CreativeContract.playPrefix}$id'), isNull);
    final missing = await store.get(id);
    await store.write(missing, {...missing, 'current': ''});
    await expectLater(CreativePlay(db, id).open(), throwsFormatException);
    await expectLater(db.importAll(await backup()), throwsFormatException);
  });

  test('public saves, descriptions and another reveal do not discard a pending paid choice', () async {
    final started = Completer<void>();
    final result = Completer<http.Response>();
    late Future<bool> Function() abortGate;
    var requests = 0;
    final play = CreativePlay(db, id, clientFactory: (abort) {
      abortGate = abort;
      return DeepSeekClient(abortWhen: abort, jsonClientFactory: () => MockClient((_) {
        requests++; started.complete(); return result.future;
      }));
    });
    final initial = await play.open();
    await db.setSetting(play.stateKey, jsonEncode({...initial, 'turns': {
      'previous': {'options': options, 'choice': '布', 'at': 1}}}));
    final pending = event(play, 'choose', {'turn': 'new', 'options': options});
    await started.future;
    await event(play, 'describe', {'kind': 'game', 'content': '正在选择', 'resettable': true});
    await event(play, 'save', {'score': 9, 'phase': 'waiting'});
    await event(play, 'reveal', {'turn': 'previous', 'playerChoice': '剪刀'});
    final duringChoice = await play.captureSnapshot().timeout(const Duration(seconds: 2));
    expect(duringChoice.data['public_state']['score'], 9);
    expect(duringChoice.data['revealed_total'], 1);
    expect(await abortGate(), false);
    result.complete(response());
    expect(await pending, {'committed': true});
    final state = await play.read();
    expect(state['public'], {'score': 9, 'phase': 'waiting'});
    expect(state['description']['content'], '正在选择');
    expect(state['turns']['previous']['playerChoice'], '剪刀');
    expect(state['turns']['new']['choice'], '石头');
    expect(state['turns']['new']['playerChoice'], isNull);
    expect(requests, 1);
    expect(await event(play, 'choose', {'turn': 'new', 'options': options}), {'committed': true});
    expect(requests, 1);
  });

  test('background revision and publication preserve a pending choice in the old play version', () async {
    final started = Completer<void>();
    final result = Completer<http.Response>();
    late Future<bool> Function() abortGate;
    final play = CreativePlay(db, id, clientFactory: (abort) {
      abortGate = abort;
      return DeepSeekClient(abortWhen: abort, jsonClientFactory: () => MockClient((_) {
        started.complete(); return result.future;
      }));
    });
    await play.open();
    final pending = event(play, 'choose', {'turn': 'new', 'options': options});
    await started.future;
    final revision = await store.commission(deepThinking: true, requestId: 'revision', messageId: 'revision-card',
      brief: '修改颜色', requestQuote: '修改颜色', latestText: '修改颜色', workId: id);
    expect(await abortGate(), false);
    await store.write(revision, {...revision, 'status': 'ready', 'current': oldVersion,
      'title': '修改后的作品', 'versions': [oldVersion, version]},
      extra: {'${CreativeContract.sourcePrefix}$oldVersion': oldHtml});
    expect(await abortGate(), false);
    result.complete(response());
    expect(await pending, {'committed': true});
    final state = await play.read();
    expect(state['version'], version);
    expect(state['turns']['new']['choice'], '石头');
    expect((await store.get(id))['current'], oldVersion);
  });

  test('next paid choice receives actual reveal order and no still-sealed choice', () async {
    Map? input;
    final play = CreativePlay(db, id, clientFactory: (abort) => DeepSeekClient(
      abortWhen: abort, jsonClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        input = jsonDecode((body['messages'] as List).last['content'] as String) as Map;
        return response();
      })));
    final initial = await play.open();
    await db.setSetting(play.stateKey, jsonEncode({...initial, 'turns': {
      'first': {'options': options, 'choice': '石头', 'at': 1},
      'second': {'options': options, 'choice': '布', 'at': 2},
      'hidden': {'options': options, 'choice': 'sealed-value', 'at': 3},
    }}));
    await event(play, 'reveal', {'turn': 'second', 'playerChoice': '石头'});
    await event(play, 'reveal', {'turn': 'first', 'playerChoice': '布'});
    final work = await store.get(id);
    await store.write(work, {...work, 'status': 'building', 'title': '新版计划标题',
      'intro': '尚未发布的新内容'});
    expect(await event(play, 'choose', {'turn': 'next', 'options': options}),
      {'committed': true});
    expect(input!['work'], initial['work_metadata']['title']);
    expect(input!['work'], isNot('新版计划标题'));
    final previous = input!['previous_revealed'] as List;
    expect(previous.map((turn) => turn['choice']), ['石头', '布']);
    expect(previous.map((turn) => turn['playerChoice']), ['布', '石头']);
    expect(jsonEncode(previous), isNot(contains('sealed-value')));
  });

  for (final interruption in ['restart', 'restore', 'delete', 'same-turn']) {
    test('$interruption prevents a pending choice from overwriting newer state', () async {
      final started = Completer<void>();
      final result = Completer<http.Response>();
      final play = CreativePlay(db, id, clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
        jsonClientFactory: () => MockClient((_) { started.complete(); return result.future; })));
      await play.open();
      final pending = event(play, 'choose', {'turn': 'new', 'options': options});
      await started.future;
      if (interruption == 'restart') {
        await play.open(restart: true);
      } else if (interruption == 'restore') {
        // Bare importAll is a low-level state copy and preserves the archive's
        // identity. Actual restores install a fresh epoch through this owner.
        // Exercise that production path rather than manually changing a fence.
        final archive = await backup();
        final priorEpoch = await db.getSetting('runtime_state_epoch_v1');
        final root = await Directory.systemTemp.createTemp('creative-restore-');
        try {
          final coordinator = SnapshotRestoreCoordinator(db, PortableCompanionStorage(),
            journal: SnapshotRestoreJournal(root));
          final outcome = await coordinator.install(
            prepare: (_) async => SnapshotInstallPlan([]),
            commitDatabase: (runtime) => db.importAll(archive, runtimeSettingOverrides: runtime));
          expect(outcome.recoveryPending, false);
          expect(await db.getSetting('runtime_state_epoch_v1'), isNot(priorEpoch));
          expect(await db.brainWorkAllowed(), true);
        } finally {
          await root.delete(recursive: true);
        }
      } else if (interruption == 'delete') {
        await store.delete(id);
      } else {
        final current = await play.read();
        await db.setSetting(play.stateKey, jsonEncode({...current, 'turns': {
          'new': {'options': options, 'choice': '布', 'playerChoice': '剪刀', 'at': 1}}}));
      }
      final rejected = expectLater(pending, throwsA(isA<Exception>()));
      result.complete(response());
      await rejected;
      final state = await play.read();
      if (interruption == 'same-turn') {
        expect(state['turns']['new']['choice'], '布');
        expect(state['turns']['new']['playerChoice'], '剪刀');
      } else if (interruption == 'delete') {
        expect(state, isEmpty);
        expect((await store.get(id))['status'], 'deleted');
      } else {
        expect(state['turns'], isEmpty);
      }
    });
  }
}
