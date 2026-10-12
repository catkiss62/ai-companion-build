import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/personality/form_context_snapshot.dart';
import 'package:ai_companion_localfirst/core/self/dream_contract.dart';
import 'package:ai_companion_localfirst/core/self/dream_engine.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _words = '不用一直赶目标，停下来看看也很好。';
const _view = '我可能也喜欢不急着完成目标的游玩节奏。';

Map<String, dynamic> _change({
  String source = 'chat:fresh',
  String basis = 'new_experience',
  String stance = 'tentative',
}) => {
  'action': 'upsert',
  'id': 'play.own_pace',
  'domain': 'play',
  'stance': stance,
  'understanding': _view,
  'choice': '允许自己在有兴趣的地方多停留一会儿。',
  'uncertainty': '也可能只是今天更想轻松一点。',
  'reason': '这份真实交流支持原来的理解，修复已经失效的出处。',
  'basis': basis,
  'evidence': [
    {'id': source, 'quote': _words, 'role': 'support'},
  ],
};

Map<String, dynamic> _payload([Map<String, dynamic>? change]) => {
  'changes': [change ?? _change()],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final night = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 10);
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async {
    await db.closeForTesting();
  });

  String metadata(String form, DateTime at, {String captureKind = 'user_received'}) => form == 'legacy'
      ? ''
      : FormContextSnapshot(
          form: form,
          capturedAt: at.millisecondsSinceEpoch,
          captureKind: captureKind,
        ).encode();

  Future<void> seed({
    required String id,
    required DateTime at,
    String form = 'normal',
    String role = 'user',
  }) => db.insertMessage(
    ChatMessage(
      id: id,
      role: role,
      content: _words,
      createdAt: at,
      formContextJson: metadata(form, at,
          captureKind: role == 'user' ? 'user_received' : 'generation'),
    ),
  );

  // Both SQL projections must reach commit with the same canonical source
  // fields, even when the model uses none of the material in a conclusion.
  for (final form in ['legacy', 'normal', 'q']) {
    for (final empty in [false, true]) {
      test('$form fresh and related sources commit, empty=$empty', () async {
        final relatedAt = night.subtract(const Duration(hours: 3));
        final freshAt = night.subtract(const Duration(hours: 2));
        await seed(id: 'related', at: relatedAt, form: form, role: 'assistant');
        await seed(id: 'fresh', at: freshAt, form: form);
        await db.setSetting(DreamStore.stateKey, jsonEncode({
          'schema': 1,
          'insights': [],
          'cursor': {
            'chat_at': relatedAt.millisecondsSinceEpoch,
            'chat_id': 'related',
          },
          'last_weekly_at': night.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        }));
        Map<String, Object?>? input;
        final result = await DreamEngine(db, reviewer: (material) async {
          input = material;
          return empty ? {'changes': []} : _payload();
        }).maybeDream(now: night, manual: true);
        expect(result, isTrue);
        expect(input!['weekly'], isFalse);
        final sources = DreamContract.records(input!['sources']);
        expect(sources.map((s) => s['id']).toSet(), {'chat:fresh', 'chat:related'});
        for (final source in sources) {
          final fresh = source['id'] == 'chat:fresh';
          expect(source['fresh'], fresh);
          expect(source['kind'], fresh ? 'user_text' : 'assistant_text');
          expect(source['form_context'], form == 'legacy'
              ? isNull : jsonDecode(metadata(form, fresh ? freshAt : relatedAt,
                  captureKind: fresh ? 'user_received' : 'generation')));
        }
        final saved = await DreamStore(db).load();
        expect((saved['cursor'] as Map)['chat_id'], 'fresh');
        expect(saved['last_success_day'], DreamContract.day(night));
        if (empty) {
          expect(saved['insights'], isEmpty);
        } else {
          final live = await DreamStore.originals(await db.database, ['chat:fresh']);
          final insight = DreamContract.records(saved['insights']).single;
          expect(DreamContract.records(insight['evidence']).single['fingerprint'],
              live['chat:fresh']!.fingerprint);
          expect(await DreamStore(db).prompt(), contains(_view));
        }
      });
    }
  }

  for (final target in ['fresh', 'related']) {
    for (final empty in [false, true]) {
      test('form change during review rejects $target, empty=$empty', () async {
        final relatedAt = night.subtract(const Duration(hours: 3));
        final freshAt = night.subtract(const Duration(hours: 2));
        await seed(id: 'related', at: relatedAt);
        await seed(id: 'fresh', at: freshAt);
        final originalState = jsonEncode({
          'schema': 1,
          'insights': [],
          'cursor': {
            'chat_at': relatedAt.millisecondsSinceEpoch,
            'chat_id': 'related',
          },
        });
        await db.setSetting(DreamStore.stateKey, originalState);
        final handle = await db.database;
        final stamp = await DreamStore.messageStamp(handle);
        var reviewed = false;
        final result = await DreamEngine(db, reviewer: (_) async {
          reviewed = true;
          await handle.update('messages', {
            'form_context_json': metadata('q', target == 'fresh' ? freshAt : relatedAt),
          }, where: 'id = ?', whereArgs: [target]);
          return empty ? {'changes': []} : _payload();
        }).maybeDream(now: night, manual: true);
        expect(reviewed, isTrue);
        // The coarse chat stamp deliberately does not detect this change;
        // every collected source must still be checked inside commit.
        expect(await DreamStore.messageStamp(handle), stamp);
        expect(result, isFalse);
        expect(await db.getSetting(DreamStore.stateKey), originalState);
        expect(DreamContract.decode(await db.getSetting(DreamStore.diagnosticKey))['status'],
            'evidence_changed_before_commit');
        // A clean retry can consume the same material with its current form.
        expect(await DreamEngine(db, reviewer: (_) async => {'changes': []})
            .maybeDream(now: night, manual: true), isTrue);
      });
    }
  }

  for (final historical in [false, true]) {
    for (final invalidation in ['deleted', 'changed']) {
      test('$invalidation evidence repairs from ${historical ? 'historical' : 'fresh'} support without new growth', () async {
        final oldAt = night.subtract(const Duration(hours: 3));
        final replacementAt = historical
            ? night.subtract(const Duration(hours: 2))
            : night.add(const Duration(days: 6));
        await seed(id: 'old', at: oldAt);
        if (historical) await seed(id: 'replacement', at: replacementAt, form: 'q');
        final store = DreamStore(db);
        expect(await DreamEngine(db, reviewer: (_) async => _payload(
          _change(source: 'chat:old', stance: 'considered'),
        )).maybeDream(now: night, manual: true), isTrue);
        final before = DreamContract.records((await store.load())['insights']).single;
        final handle = await db.database;
        if (invalidation == 'deleted') {
          await handle.delete('messages', where: 'id = ?', whereArgs: ['old']);
        } else {
          await handle.update('messages', {'form_context_json': metadata('q', oldAt)},
              where: 'id = ?', whereArgs: ['old']);
        }
        expect(await store.prompt(), isEmpty);
        if (!historical) await seed(id: 'replacement', at: replacementAt, form: 'q');
        final repairAt = night.add(const Duration(days: 7));
        Map<String, Object?>? input;
        expect(await DreamEngine(db, reviewer: (material) async {
          input = material;
          return _payload(_change(source: 'chat:replacement',
              basis: historical ? 'reinterpretation' : 'new_experience',
              stance: 'aspiration'));
        }).maybeDream(now: repairAt, manual: true), isTrue);
        expect(DreamContract.records(input!['current']).single['originals_available'], isFalse);
        final replacement = DreamContract.records(input!['sources'])
            .singleWhere((s) => s['id'] == 'chat:replacement');
        expect(replacement['fresh'], !historical);
        final state = await store.load();
        final repaired = DreamContract.records(state['insights']).single;
        for (final key in ['understanding', 'choice', 'uncertainty', 'domain',
          'stance', 'created_at', 'updated_at']) {
          expect(repaired[key], before[key], reason: key);
        }
        expect(repaired['evidence_repaired_at'], repairAt.millisecondsSinceEpoch);
        expect(repaired['revision'], 2);
        final evidence = DreamContract.records(repaired['evidence']).single;
        expect(evidence['id'], 'chat:replacement');
        expect(evidence['at'], replacementAt.millisecondsSinceEpoch);
        expect(DreamContract.records(state['history']).first['revision_kind'], 'evidence_repair');
        expect(await store.prompt(), contains(_view));
        expect((await store.diagnostics())['last_changed_count'], 0);
        // The JSON setting is the backup unit; provenance-only fields survive
        // export unchanged instead of being reconstructed from old columns.
        final snapshot = await db.exportAll();
        final settings = ((snapshot['tables'] as Map)['settings'] as List).cast<Map>();
        expect(settings.singleWhere((s) => s['key'] == DreamStore.stateKey)['value'],
            jsonEncode(state));
      });
    }
  }

  test('replacement becoming invalid during repair cannot revive the old view', () async {
    final oldAt = night.subtract(const Duration(hours: 3));
    final replacementAt = night.subtract(const Duration(hours: 2));
    await seed(id: 'old', at: oldAt);
    await seed(id: 'replacement', at: replacementAt);
    final store = DreamStore(db);
    expect(await DreamEngine(db, reviewer: (_) async => _payload(
      _change(source: 'chat:old'),
    )).maybeDream(now: night, manual: true), isTrue);
    final handle = await db.database;
    await handle.delete('messages', where: 'id = ?', whereArgs: ['old']);
    final before = await db.getSetting(DreamStore.stateKey);
    final repairAt = night.add(const Duration(days: 7));
    final proposal = _payload(_change(source: 'chat:replacement', basis: 'reinterpretation'));
    expect(await DreamEngine(db, reviewer: (_) async {
      await handle.update('messages', {
        'form_context_json': metadata('q', replacementAt),
      }, where: 'id = ?', whereArgs: ['replacement']);
      return proposal;
    }).maybeDream(now: repairAt, manual: true), isFalse);
    expect(await db.getSetting(DreamStore.stateKey), before);
    expect(await store.prompt(), isEmpty);
    expect(DreamContract.decode(await db.getSetting(DreamStore.diagnosticKey))['status'],
        'evidence_changed_before_commit');
    expect(await DreamEngine(db, reviewer: (_) async => proposal)
        .maybeDream(now: repairAt, manual: true), isTrue);
    expect(await store.prompt(), contains(_view));
  });

  group('source repair does not manufacture confirmation', () {
    DreamSource source(String id, {String kind = 'user_text', bool fresh = false}) =>
        DreamSource(id: 'chat:$id', kind: kind, text: _words, at: 42, fresh: fresh);
    Map<String, dynamic> initial() => DreamContract.apply(
      payload: _payload(_change(source: 'chat:old')),
      state: {}, sources: [source('old', fresh: true)], now: night,
    )!;

    for (final scenario in ['valid_old', 'assistant_only', 'reused_support', 'fresh_counter_only']) {
      test('$scenario cannot refresh an unchanged understanding', () {
        final old = initial();
        final sources = <DreamSource>[];
        var change = _change(source: 'chat:new', basis: 'reinterpretation', stance: 'considered');
        if (scenario == 'valid_old') {
          sources.addAll([source('old'), source('new')]);
        } else if (scenario == 'assistant_only') {
          sources.add(source('new', kind: 'assistant_text', fresh: true));
          change['basis'] = 'new_experience';
        } else {
          // One stale ref invalidates the whole insight, but merely repeating
          // its remaining old support is not a new source repair.
          final insight = (old['insights'] as List).single as Map;
          (insight['evidence'] as List).add({
            'id': 'chat:missing', 'quote': _words, 'role': 'counter',
            'fingerprint': 'obsolete', 'at': 1, 'kind': 'user_text',
          });
          sources.add(source('old'));
          change = _change(source: 'chat:old', basis: 'reinterpretation', stance: 'considered');
          if (scenario == 'fresh_counter_only') {
            sources.add(source('new', fresh: true));
            change['basis'] = 'new_experience';
            (change['evidence'] as List).add({'id': 'chat:new', 'quote': _words, 'role': 'counter'});
          }
        }
        final next = DreamContract.apply(payload: _payload(change),
            state: old, sources: sources, now: night.add(const Duration(days: 1)))!;
        expect(next['insights'], old['insights']);
        expect(next['history'], old['history']);
      });
    }

    test('new historical support restores tentative view without promotion', () {
      final old = initial();
      final next = DreamContract.apply(payload: _payload(_change(
        source: 'chat:new', basis: 'reinterpretation', stance: 'considered',
      )), state: old, sources: [source('new')], now: night.add(const Duration(days: 1)))!;
      final insight = DreamContract.records(next['insights']).single;
      expect(insight['stance'], 'tentative');
      expect(insight['updated_at'], night.millisecondsSinceEpoch);
      expect(DreamContract.records(insight['evidence']).single['id'], 'chat:new');
    });

    test('changing only reference order or support role does not create repair', () {
      final first = _change(source: 'chat:old');
      (first['evidence'] as List).add({'id': 'chat:other', 'quote': _words, 'role': 'counter'});
      final old = DreamContract.apply(payload: _payload(first), state: {},
          sources: [source('old', fresh: true), source('other')], now: night)!;
      for (final missingOriginal in [false, true]) {
        final change = _change(source: 'chat:other', basis: 'reinterpretation', stance: 'considered');
        if (!missingOriginal) {
          (change['evidence'] as List).add({'id': 'chat:old', 'quote': _words, 'role': 'counter'});
        }
        final next = DreamContract.apply(payload: _payload(change), state: old,
            sources: [if (!missingOriginal) source('old'), source('other')],
            now: night.add(const Duration(days: 1)))!;
        expect(next['insights'], old['insights']);
        expect(next['history'], old['history']);
      }
    });
  });
}
