import 'dart:async';

import 'package:ai_companion_localfirst/core/autonomy/public_web_share_coordinator.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_read_service.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _timeout = Duration(seconds: 10);
const _body = '座头鲸群体的歌声包含重复主题和短句，研究者通过长期录音比较不同年份的变化。'
    '这段材料只说明特定群体的观测结果，不能推广到所有海域或每一只鲸鱼。'
    '研究仍需更多独立观察，也没有证明这些声音具有与人类语言相同的含义。';

Future<void> _entered(Future<void> entered, Future<Object?> operation) =>
    Future.any<void>([entered, operation.then<void>((_) {
      throw StateError('stage completed before entering reader');
    })]).timeout(_timeout);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async => db = await AppDatabase.createForTesting(databaseFactoryFfi));
  tearDown(() async => db.closeForTesting());

  Future<String> seed() async {
    final id = await db.seedDiagnosticPublicWebShareCandidate();
    await (await db.database).update('public_web_candidates',
      {'page_body': _body}, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  test('the real preview reclaims the only legacy staging row before selection', () async {
    final id = await seed();
    final sql = await db.database;
    await sql.update('public_web_candidates', {
      'lifecycle_state': 'share_staging', 'share_stage_token': '',
      'share_stage_until': 0,
      'last_viewed_at': DateTime.now().subtract(const Duration(minutes: 8)).millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    expect(await sql.query('public_web_candidates', where: "lifecycle_state = 'unread'"), isEmpty);
    expect((await db.nextPublicWebCandidateForSharing())?.id, id);
    final result = await PublicWebShareCoordinator(db: db, desire: DesireEngine(db))
        .stageNextCandidate();
    expect(result.ready, isTrue);
    expect((await db.thoughtById(result.thoughtId!))!.source, PublicWebSharePolicy.source(id));
    final row = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
    expect(row['lifecycle_state'], 'share_ready');
    expect(row['share_stage_token'], '');
    expect(await db.nextPublicWebCandidateForSharing(), isNull);
  });

  for (final lateOutcome in ['success', 'throw']) {
    test('old reader $lateOutcome cannot mutate a replacement stage or clean up its thought', () async {
      final id = await seed();
      final sql = await db.database;
      final entered = Completer<void>(), release = Completer<void>();
      final old = PublicWebShareCoordinator(db: db, desire: DesireEngine(db),
        refreshBeforeShare: true, reader: (page, _, __) async {
          entered.complete();
          await release.future.timeout(_timeout);
          if (lateOutcome == 'throw') throw StateError('old reader failed');
          return page.copyWith(summary: '迟到的旧内容', appraisalState: 'share_candidate');
        }).stageNextCandidate();
      var bodyFailed = false;
      Map<String, List<Map<String, Object?>>>? before;
      final diagnosticsBefore = <String, String?>{};
      try {
        await _entered(entered.future, old);
        await sql.update('public_web_candidates', {'share_stage_until': 0},
          where: 'id = ?', whereArgs: [id]);
        expect((await db.nextPublicWebCandidateForSharing())?.id, id);
        final winner = await PublicWebShareCoordinator(db: db, desire: DesireEngine(db),
          refreshBeforeShare: true, reader: (page, _, __) async => page.copyWith(
            summary: '新主人核验完成的内容', appraisalState: 'share_candidate'))
          .stageNextCandidate();
        expect(winner.ready, isTrue);
        before = {};
        for (final table in ['public_web_candidates', 'companion_browser_visits',
          'public_web_knowledge', 'thoughts', 'provider_health_events']) {
          before[table] = await sql.query(table);
        }
        for (final key in ['public_web_share_last_outcome', 'public_web_share_last_at']) {
          diagnosticsBefore[key] = await db.getSetting(key);
        }
      } catch (_) {
        bodyFailed = true;
        rethrow;
      } finally {
        if (!release.isCompleted) release.complete();
        try { await old.timeout(_timeout); } catch (_) { if (!bodyFailed) rethrow; }
      }
      expect((await old).ready, isFalse);
      for (final entry in before!.entries) {
        expect(await sql.query(entry.key), entry.value, reason: 'old worker touched ${entry.key}');
      }
      for (final entry in diagnosticsBefore.entries) {
        expect(await db.getSetting(entry.key), entry.value,
          reason: 'old worker overwrote winner diagnostics: ${entry.key}');
      }
    });
  }

  test('reset while a stage reader waits cannot create a thought or ready a candidate', () async {
    final id = await seed();
    final entered = Completer<void>(), release = Completer<void>();
    final work = PublicWebShareCoordinator(db: db, desire: DesireEngine(db),
      refreshBeforeShare: true, reader: (page, _, __) async {
        entered.complete();
        await release.future.timeout(_timeout);
        return page.copyWith(appraisalState: 'share_candidate');
      }).stageNextCandidate();
    var bodyFailed = false;
    try {
      await _entered(entered.future, work);
      expect((await db.beginFreshConversationContext()).applied, isTrue);
    } catch (_) { bodyFailed = true; rethrow; }
    finally {
      if (!release.isCompleted) release.complete();
      try { await work.timeout(_timeout); } catch (_) { if (!bodyFailed) rethrow; }
    }
    expect((await work).ready, isFalse);
    expect(await db.thoughtBySource(PublicWebSharePolicy.source(id)), isNull);
    final row = (await (await db.database).query('public_web_candidates',
      where: 'id = ?', whereArgs: [id])).single;
    expect(row['lifecycle_state'], isNot('share_ready'));
  });
  for (final mutation in ['summary', 'semantic', 'lifecycle', 'reset', 'view_only']) {
    test('actual guarded prompt reader preserves newer $mutation state', () async {
      final id = await seed();
      final sql = await db.database;
      await sql.update('public_web_candidates', {
        'read_at': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      }, where: 'id = ?', whereArgs: [id]);
      final fence = (await db.captureBrainWorkFence(settingKeys: const [
        'conversation_context_reset_at', 'conversation_context_reset_count']))!;
      final entered = Completer<void>(), release = Completer<void>();
      final work = PublicWebReadService(db, workFence: fence, reader: (page, _, __) async {
        entered.complete();
        await release.future.timeout(_timeout);
        return page.copyWith(summary: '旧请求返回的摘要', semanticState: 'valid', readAt: DateTime.now());
      }).refreshForUse(id);
      var bodyFailed = false;
      Map<String, Object?>? before;
      try {
        await _entered(entered.future, work);
        if (mutation == 'reset') {
          expect((await db.beginFreshConversationContext()).applied, isTrue);
        } else {
          final change = switch (mutation) {
            'summary' => <String, Object?>{'summary': '新版本同正文摘要'},
            'semantic' => <String, Object?>{'semantic_state': 'history_only'},
            'lifecycle' => <String, Object?>{'lifecycle_state': 'reviewed'},
            _ => <String, Object?>{'view_count': 7},
          };
          await sql.update('public_web_candidates', change, where: 'id = ?', whereArgs: [id]);
        }
        before = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
      } catch (_) { bodyFailed = true; rethrow; }
      finally {
        if (!release.isCompleted) release.complete();
        try { await work.timeout(_timeout); } catch (_) { if (!bodyFailed) rethrow; }
      }
      expect(await work, mutation == 'view_only');
      final after = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
      if (mutation == 'view_only') {
        expect(after['view_count'], 7);
        expect(after['summary'], '旧请求返回的摘要');
      } else {
        expect(after, before);
      }
    });
  }

}
