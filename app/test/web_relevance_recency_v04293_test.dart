import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/autonomy/layered_public_web_provider.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_deepseek_appraiser.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_discovery_policy.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_read_service.dart';
import 'package:ai_companion_localfirst/core/autonomy/recent_web_topics.dart';
import 'package:ai_companion_localfirst/core/autonomy/web_knowledge_selection.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime.utc(2026, 10, 10);
  const fallback = PublicWebDiscoveryTopic(query: '海洋', interestKey: 'curiosity:ocean',
    searchMode: 'interest', domain: 'ocean');
  test('relevance choices select sources; unavailable or incomplete keeps fallback', () {
    final pages = List.generate(3, (i) => PublicWebContextItem(id: '$i', title: '研究$i',
      summary: '导航' * 400, url: 'https://example.com/$i', sourceDomain: 'example.com',
      provider: 'test', discoveredAt: now, safetyState: 'untrusted_public'));
    expect(WebKnowledgeSelection.questions(pages).length, 2);
    expect(WebKnowledgeSelection.selected(pages, {'web_0': 'skip', 'web_1': 'read'}), ['1']);
    expect(WebKnowledgeSelection.selected(pages, {'web_0': 'skip', 'web_1': 'skip'}), isEmpty);
    expect(WebKnowledgeSelection.selected(pages, null), isNull);
    expect(WebKnowledgeSelection.selected(pages, {'web_0': 'read'}), isNull);
    expect(((WebKnowledgeSelection.describe(pages)['web_0'] as Map)['summary'] as String).length, 500);
  });
  test('topic routing uses interests without putting private sentences in queries', () {
    final date = List.generate(5, (i) => now.add(Duration(hours: i * 6)))
        .firstWhere((d) => (d.millisecondsSinceEpoch ~/ const Duration(hours: 6).inMilliseconds) % 5 != 0);
    final selected = RecentWebTopics.choose(fallback: fallback, now: date,
      ownInterest: ['海洋生物'], userPreferences: ['我喜欢海洋，个人暗号PRIVATE-123'],
      sharedTopics: ['昨天和PRIVATE-456讨论海豚']);
    expect(selected.domain, 'ocean');
    expect(selected.query, isNot(contains('PRIVATE')));
    expect(selected.query, contains('最近一周'));
    expect(RecentWebTopics.isRecent(selected.interestKey), isTrue);
    expect(RecentWebTopics.matching(['我不喜欢游戏']), isEmpty);
    final repeated = RecentWebTopics.choose(fallback: fallback, now: date,
      ownInterest: ['海洋'], sharedTopics: ['太空'], recentKeys: [selected.interestKey]);
    expect(repeated.domain, 'space');
  });
  test('a new publication date cannot turn old or unknown events into news', () {
    expect(RecentWebTopics.recentEvent(['event_date=2026-10-03'], now), isTrue);
    for (final tags in [<String>[], ['publication_date=2026-10-10'],
        ['event_date=2025-10-10', 'publication_date=2026-10-10'],
        ['event_date=2026-10-11'], ['event_date=2026-02-30']]) {
      expect(RecentWebTopics.recentEvent(tags, now), isFalse);
    }
  });
  test('recent search sends time window and never falls back to encyclopedia', () async {
    final seen = <Uri>[];
    final result = await LayeredPublicWebProvider(tavilyApiKey: 'test', recentMode: true,
      client: MockClient((request) async {
        seen.add(request.url);
        expect(request.url.path, '/search');
        expect((jsonDecode(request.body) as Map)['time_range'], 'week');
        return http.Response('{"results":[]}', 200);
      })).discover(query: '海洋研究最近一周新进展', driveKey: 'curiosity',
        intentAction: 'discover_interest', interestKey: 'curiosity:recent_interest:ocean:recent7d', now: now);
    expect(seen.length, 1);
    expect(result.candidates, isEmpty);
    expect(result.failureReason, 'no_recent_results');
  });
  test('recent appraisal needs a dated substantive change, including duplicate check', () async {
    final current = DateTime.now();
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    final tags = [
      ['event_date=${date(current)}'],
      ['publication_date=${date(current)}'],
      ['event_date=${date(current.subtract(const Duration(days: 30)))}'],
      ['event_date=${date(current)}'],
    ];
    final pages = List.generate(4, (i) => PublicWebCandidateDraft(fingerprint: 'p$i',
      title: '研究$i', summary: '研究正文已完整读取', url: 'https://example.com/$i',
      sourceDomain: 'example.com', provider: 'test', language: 'zh', driveKey: 'curiosity',
      intentAction: 'discover_interest', interestKey: 'curiosity:recent_interest:ocean:recent7d',
      discoveredAt: current, expiresAt: current.add(const Duration(days: 2)),
      readState: 'verified', topicTags: tags[i]));
    final result = await DeepSeekPublicWebAppraiser(apiKey: 'test',
      endpoint: 'https://api.deepseek.com/chat/completions', sharedHeadlines: ['同一事件已分享'],
      client: DeepSeekClient(client: MockClient((request) async {
        expect(request.body, contains('同一事件已分享'));
        return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({
          'items': List.generate(4, (i) => {'id': i, 'semantic_state': 'valid',
            'new_development': i != 3, 'interest_score': .9, 'learning_score': .9, 'share_score': .9})})}}]}), 200);
      }))).appraise(query: '近期海洋研究', candidates: pages,
        sourceIntent: const DesireIntent(drive: DriveKey.curiosity, score: 1,
          reason: 'test', wantAction: 'discover_interest'), socialExcess: 0);
    expect(result.map((p) => p.semanticState), ['valid', 'history_only', 'history_only', 'history_only']);
  });
  group('bounded full reads with real storage', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
      final sql = await db.database;
      await sql.insert('autonomous_action_runs', {'id': 'run', 'dedupe_key': 'run',
        'tool_kind': 'public_web', 'intent_action': 'discover_interest', 'drive_key': 'curiosity',
        'intent_score': 1, 'reason_source': 'test', 'status': 'succeeded', 'gate_reason': '',
        'outcome_kind': 'candidate_stored', 'requested_at': 1, 'state_generation': 0, 'device_id': 'test'});
      for (var i = 0; i < 3; i++) {
        await sql.insert('public_web_candidates', {'id': 'p$i', 'fingerprint': 'p$i',
          'title': '研究$i', 'summary': '旧摘要', 'url': 'https://example.com/$i', 'source_domain': 'example.com',
          'provider': 'test', 'drive_key': 'curiosity', 'intent_action': 'discover_interest',
          'action_run_id': 'run', 'discovered_at': 1, 'expires_at': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
          'read_state': 'verified', 'semantic_state': 'valid', 'lifecycle_state': 'share_ready',
          'share_score': .9, 'read_at': 1, 'content_sha256': 'old', 'page_body': '旧原文。' * 100});
      }
    });
    tearDown(() => db.closeForTesting());
    test('two pages run together, all complete, duplicate ids read once and order preserved', () async {
      final enteredPair = Completer<void>(), releasePair = Completer<void>();
      var active = 0, peak = 0, calls = 0;
      final activity = <AgentToolActivity>[];
      final service = PublicWebReadService(db, reader: (page, query, token) async {
        calls++; active++; if (active > peak) peak = active;
        if (calls == 2) enteredPair.complete();
        await releasePair.future;
        active--;
        return page.copyWith(pageBody: '完整新原文。' * 100, summary: '新摘要',
          readAt: DateTime.now(), contentSha256: 'new', semanticState: 'valid');
      });
      final future = service.refreshIds(['p0', 'p1', 'p0', 'p2'], onActivity: activity.add);
      await enteredPair.future.timeout(const Duration(seconds: 5));
      expect(calls, 2); expect(peak, 2);
      releasePair.complete();
      expect(await future, ['p0', 'p1', 'p2']);
      expect(calls, 3); expect(peak, 2);
      expect(activity.first.status, AgentToolStatus.running);
      expect(activity.last.status, AgentToolStatus.succeeded);
      expect(await db.getSetting('web_prompt_read_timing_v1'), contains('|3|3|'));
      expect((await db.publicWebCandidateForRefresh('p2'))!.pageBody, '完整新原文。' * 100);
    });
    test('cancellation prevents writeback and starting later pages', () async {
      final token = GenerationCancellationToken();
      final entered = Completer<void>();
      var calls = 0;
      final activity = <AgentToolActivity>[];
      final service = PublicWebReadService(db, reader: (page, query, cancellation) async {
        if (++calls == 2) entered.complete();
        await cancellation!.whenCancelled;
        cancellation.throwIfCancelled();
        return page;
      });
      final future = service.refreshIds(['p0', 'p1', 'p2'], cancellation: token, onActivity: activity.add);
      final assertion = expectLater(future, throwsA(isA<GenerationCancelledByUserException>()));
      await entered.future.timeout(const Duration(seconds: 5));
      token.cancel();
      await assertion;
      expect(calls, 2);
      expect(activity.last.status, AgentToolStatus.stopped);
      expect((await db.publicWebCandidateForRefresh('p0'))!.contentSha256, 'old');
    });
  });
}
