import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_task_loop.dart';
import 'package:ai_companion_localfirst/core/autonomy/web_page_evidence.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_read_service.dart';
import 'package:ai_companion_localfirst/core/autonomy/layered_public_web_provider.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  Set<String> names(List<Map<String, Object?>> tools) =>
      tools.map((item) => (item['function'] as Map)['name'] as String).toSet();
  test('deep exposes research reads while ordinary chat stays plan-free', () {
    expect(AgentToolPlanner.nativeToolDefinitionsFor('今天心情不错'), isEmpty);
    final deep = names(
      AgentToolPlanner.nativeToolDefinitionsFor('今天心情不错', deepThinking: true),
    );
    expect(
      deep,
      containsAll({
        'public_web_search',
        'public_web_read',
        'memory_search',
        'rules_read',
      }),
    );
    expect(
      deep.any(
        (n) =>
            n.contains('send') ||
            n.contains('save') ||
            n.contains('cedar') ||
            n.contains('screen'),
      ),
      isFalse,
    );
    final blind = names(
      AgentToolPlanner.nativeToolDefinitionsFor(
        '去玩游戏',
        deepThinking: true,
        cedarBlindPlay: true,
      ),
    );
    expect(blind.contains('public_web_read'), isFalse);
    expect(blind.contains('public_web_search'), isFalse);
    expect(
      AgentTaskLoopPolicy.allowedCalls(planningRounds: 3, toolCalls: 4),
      0,
    );
    expect(
      AgentTaskLoopPolicy.allowedCalls(
        planningRounds: 3,
        toolCalls: 4,
        planningRoundLimit: 5,
        toolCallLimit: 10,
      ),
      2,
    );
  });
  test('whole short source and later qualifications reach final evidence', () {
    final body = '${'原文资料。' * 300}重要结论：不能推广到儿童。';
    final result = WebPageEvidence.render(body: body);
    expect(result, contains(jsonEncode(body)));
    expect(result, contains('whole_extracted_body'));
    final long = '${'开头材料。' * 2500}重要结论：不能推广到儿童。';
    expect(
      WebPageEvidence.render(body: long),
      contains('selected_original_parts'),
    );
    expect(WebPageEvidence.render(body: long), contains('不能推广到儿童'));
    expect(
      WebPageEvidence.render(body: long, part: 2),
      contains(jsonEncode(WebPageEvidence.parts(long)[1])),
    );
  });
  test(
    'bad, oversized, gated and stale bodies cannot count as a full read',
    () {
      expect(WebPageEvidence.rejection('x' * 100, truncated: true), isNotNull);
      expect(WebPageEvidence.rejection('x' * 168001), isNotNull);
      expect(
        WebPageEvidence.rejection('Access denied ${'x' * 100}'),
        isNotNull,
      );
      final now = DateTime.now();
      expect(
        WebPageEvidence.fresh(
          'x' * 100,
          now.subtract(const Duration(days: 1)),
          now,
        ),
        isFalse,
      );
      expect(
        WebPageEvidence.fresh(
          'x' * 100,
          now.add(const Duration(seconds: 1)),
          now,
        ),
        isFalse,
      );
    },
  );
  test(
    'all long-page chunks are read, body survives compaction unchanged',
    () async {
      final original = '${'研究材料。' * 12000}结尾限制。';
      final seen = <String>[];
      var active = 0, peak = 0;
      final client = MockClient((request) async {
        final data = jsonDecode(request.body) as Map;
        if (request.url.path == '/extract') {
          expect(data.containsKey('query'), isFalse);
          expect(data.containsKey('chunks_per_source'), isFalse);
          return http.Response(
            jsonEncode({
              'results': [
                {'url': 'https://example.com/p', 'raw_content': original},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final prompt =
            ((data['messages'] as List).last as Map)['content'] as String;
        seen.add(prompt);
        active++; if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reader_summary': '仅是导航摘要',
                    'key_points': ['研究材料'],
                    'uncertainties': ['有限'],
                    'topic_tags': ['研究'],
                    'event_date': '2026-10-08',
                    'publication_date': '2026-10-09',
                  }),
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final page = await LayeredPublicWebProvider(
        tavilyApiKey: 'test',
        agnesApiKey: 'test',
        client: client,
      ).rereadCandidate(candidate: _page(), query: '研究材料', now: DateTime.now());
      expect(page.readState, 'verified');
      expect(page.pageBody, original);
      expect(page.topicTags, containsAll(['event_date=2026-10-08', 'publication_date=2026-10-09']));
      expect(seen.join(), contains('结尾限制'));
      expect(seen.length, greaterThanOrEqualTo(3));
      expect(peak, inInclusiveRange(2, 3));
    },
  );
  group('real storage: snapshot, refresh and ownership', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
    });
    tearDown(() async {
      await db.closeForTesting();
    });
    test('deep job retains mode across settings changes and retry', () async {
      final job = await db.createGenerationTurn(
        user: ChatMessage(
          id: 'u',
          role: 'user',
          content: '你好',
          createdAt: DateTime.now(),
        ),
        assistantMessageId: 'a',
        model: 'deepseek-v4-flash',
        reasoningEffort: 'high',
        deepThinking: true,
      );
      await db.setSetting('deep_thinking_enabled', '0');
      final sql = await db.database;
      await sql.update(
        'generation_jobs',
        {'status': 'failed'},
        where: 'id = ?',
        whereArgs: [job.id],
      );
      expect(await db.retryFailedGenerationJob(job.id), isTrue);
      expect((await db.generationJobById(job.id))!.deepThinking, isTrue);
      final old = Map<String, Object?>.from(
        (await sql.query('generation_jobs')).single,
      )..remove('deep_thinking');
      expect(GenerationJob.fromDb(old).deepThinking, isFalse);
    });
    Future<void> seed() async {
      final sql = await db.database;
      await sql.insert('autonomous_action_runs', {
        'id': 'run',
        'dedupe_key': 'run',
        'tool_kind': 'public_web',
        'intent_action': 'discover_interest',
        'drive_key': 'curiosity',
        'intent_score': 1,
        'reason_source': 'test',
        'status': 'succeeded',
        'gate_reason': '',
        'outcome_kind': 'candidate_stored',
        'requested_at': 1,
        'state_generation': 0,
        'device_id': 'test',
      });
      await sql.insert('public_web_candidates', {
        'id': 'page',
        'fingerprint': 'page',
        'title': '研究',
        'summary': '旧摘要',
        'url': 'https://example.com/p',
        'source_domain': 'example.com',
        'provider': 'test',
        'drive_key': 'curiosity',
        'intent_action': 'discover_interest',
        'action_run_id': 'run',
        'discovered_at': 1,
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        'read_state': 'verified',
        'semantic_state': 'valid',
        'lifecycle_state': 'share_ready',
        'share_score': 0.9,
        'read_at': 1,
        'content_sha256': 'old',
        'page_body': '旧原文。' * 100,
      });
    }

    test(
      'deferred source is reread and original evidence reaches prompt projection',
      () async {
        await seed();
        var calls = 0;
        final service = PublicWebReadService(
          db,
          reader: (page, query, cancellation) async {
            calls++;
            return page.copyWith(
              pageBody: '新原文证据。' * 300,
              summary: '新摘要',
              readState: 'verified',
              semanticState: 'valid',
              contentSha256: 'new',
              readAt: DateTime.now(),
            );
          },
        );
        expect(await service.refreshForUse('page'), isTrue);
        expect(await service.refreshForUse('page'), isTrue);
        expect(calls, 1);
        final context = await db.publicWebContextByIds(candidateIds: ['page']);
        expect(context.single.pageBody, '新原文证据。' * 300);
      },
    );
    test('failed reread supplies no old summary as current evidence', () async {
      await seed();
      final service = PublicWebReadService(
        db,
        reader: (page, query, cancellation) async =>
            page.copyWith(readState: 'unreadable', pageBody: ''),
      );
      expect(await service.refreshIds(['page']), isEmpty);
    });
    test(
      'deletion while reading cannot revive or overwrite the source',
      () async {
        await seed();
        final service = PublicWebReadService(
          db,
          reader: (page, query, cancellation) async {
            await (await db.database).update(
              'public_web_candidates',
              {'lifecycle_state': 'user_deleted'},
              where: 'id = ?',
              whereArgs: ['page'],
            );
            return page.copyWith(
              readState: 'verified',
              pageBody: '新正文。' * 100,
              readAt: DateTime.now(),
              contentSha256: 'new',
            );
          },
        );
        expect(await service.refreshForUse('page'), isFalse);
        expect(
          (await db.publicWebCandidateForRefresh('page'))!.appraisalState,
          'user_deleted',
        );
      },
    );
    test(
      'source table accepts original evidence without changing rollback schema',
      () async {
        final sql = await db.database;
        final columns = (await sql.rawQuery(
          'PRAGMA table_info(public_web_candidates)',
        )).map((r) => r['name']);
        expect(columns, contains('page_body'));
        expect(AppDatabase.schemaVersion, 61);
      },
    );
  });
}

PublicWebCandidateDraft _page() => PublicWebCandidateDraft(
  fingerprint: 'page',
  title: '研究',
  summary: '',
  url: 'https://example.com/p',
  sourceDomain: 'example.com',
  provider: 'tavily',
  language: 'zh',
  driveKey: 'curiosity',
  intentAction: 'discover_interest',
  interestKey: 'research',
  discoveredAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(days: 1)),
);
