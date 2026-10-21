import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_coordinator.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _timeout = Duration(seconds: 15);
const _body = '座头鲸群体的歌声包含重复主题和短句，研究者通过长期录音比较不同年份的变化。'
    '这段材料只说明特定群体的观测结果，不能推广到所有海域或每一只鲸鱼。'
    '研究仍需更多独立观察，也没有证明这些声音具有与人类语言相同的含义。';
const _reply = '「鲸歌里那些慢慢变动的段落，让我觉得像一群鲸鱼在交换旋律。」';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override Future<String?> getApplicationSupportPath() async => path;
  @override Future<String?> getTemporaryPath() async => path;
}
// The heartbeat still runs the real DesireEngine and selector. Only the
// circadian clock input is fixed so this source-concurrency test is identical
// at noon and at 03:00 on CI (forceForDebug does not bypass rest competition).
class _MiddayDesireEngine extends DesireEngine {
  _MiddayDesireEngine(super.db);
  @override
  Future<DesireSnapshot> tick({Map<DriveKey, double> pulses = const {},
      bool userBusy = false, DateTime? now}) {
    final day = DateTime.now();
    return super.tick(pulses: pulses, userBusy: userBusy,
      now: DateTime(day.year, day.month, day.day, 12));
  }
}
class _Config extends SecureConfig {
  _Config({this.beforeKey}) : super.forTesting(const FlutterSecureStorage());
  final Future<void> Function()? beforeKey;
  @override Future<String?> readApiKey() async {
    await beforeKey?.call();
    return 'test-key';
  }
}
Future<void> _entered(Future<void> entered, Future<Object?> operation) =>
    Future.any<void>([entered, operation.then<void>((value) {
      throw StateError('evaluate ended before barrier: $value');
    })]).timeout(_timeout);
http.Response _answer(String text) => http.Response.bytes(utf8.encode(
    'data: ${jsonEncode({'choices': [{'delta': {'content': text}, 'finish_reason': 'stop'}]})}\n\n'
    'data: [DONE]\n\n'), 200, headers: {'content-type': 'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late Directory files;
  late PathProviderPlatform oldPaths;
  final clients = <DeepSeekClient>[];
  const channel = MethodChannel('ai_companion/system');
  setUp(() async {
    files = await Directory.systemTemp.createTemp('proactive-g3-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(files.path);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    // Optional network engines remain unconfigured; only the final writer has
    // the explicitly injected key and controlled HTTP transport.
    FlutterSecureStorage.setMockInitialValues({'openrouter_jev_short_judgments_enabled': '0'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => null);
    for (final key in ['self_drive_enabled', 'perception_enabled', 'memory_fading_enabled',
      'thought_consolidation_enabled', 'simulated_phone_enabled', 'ai_self_reflection_enabled',
      'cedar_toy_autonomy_enabled', 'tts_enabled']) {
      await db.setSetting(key, '0');
    }
    await db.saveDesire(DesireSnapshot(drives: {for (final k in DriveKey.values) k: .05},
      lastTickAt: DateTime.now()));
  });
  tearDown(() async {
    for (final client in clients) { client.close(); }
    clients.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
    await db.closeForTesting();
    PathProviderPlatform.instance = oldPaths;
    await files.delete(recursive: true);
  });

  Future<(String, String)> seedReady() async {
    final id = await db.seedDiagnosticPublicWebShareCandidate();
    await (await db.database).update('public_web_candidates', {'page_body': _body},
      where: 'id = ?', whereArgs: [id]);
    final stage = await PublicWebShareCoordinator(db: db, desire: DesireEngine(db))
      .stageNextCandidate();
    expect(stage.ready, isTrue);
    return (id, stage.thoughtId!);
  }
  ProactiveEngine engine({Future<void> Function()? beforeKey,
      required Future<http.Response> Function(http.Request) writer}) {
    final ai = DeepSeekClient(streamClientFactory: () => MockClient(writer),
      jsonClientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{}'}}]}), 200)));
    clients.add(ai);
    return ProactiveEngine(db: db, desireEngine: _MiddayDesireEngine(db), ai: ai,
      android: AndroidBridge.instance, secureConfig: _Config(beforeKey: beforeKey),
      webReader: (page, _, __) async => page.copyWith(appraisalState: 'share_candidate', readAt: DateTime.now()));
  }

  for (final mode in ['single', 'second_success', 'second_failure']) {
    test('proactive real HTTP and committed model follow configured routes: $mode', () async {
      await db.setSetting('deepseek_model', 'first-proactive-custom');
      FlutterSecureStorage.setMockInitialValues({
        'openrouter_jev_short_judgments_enabled': '0',
        'chat_api_provider': mode == 'single' ? 'deepseek' : 'aiwangyou_gemini',
        'aiwangyou_gemini_api_key': 'second-test',
        'aiwangyou_final_reply_endpoint': 'https://relay.invalid/v1/chat/completions',
        'aiwangyou_final_reply_model': 'second-proactive-custom',
      });
      final (_, thoughtId) = await seedReady();
      final models = <String>[];
      final e = engine(writer: (request) async {
        final model = (jsonDecode(request.body) as Map)['model'] as String;
        models.add(model);
        if (model == 'second-proactive-custom' && mode == 'second_failure') {
          return http.Response('upstream unavailable', 503);
        }
        return _answer(_reply);
      });
      final sent = await e.evaluate(forceForDebug: true, forcedThoughtIdForDebug: thoughtId);
      expect(sent.sent, isTrue, reason: sent.reason);
      final row = (await (await db.database).query('messages', where: 'is_proactive = 1')).single;
      expect(row['model'], mode == 'second_success' ? 'second-proactive-custom' : 'first-proactive-custom');
      expect(models, mode == 'single' ? ['first-proactive-custom']
          : mode == 'second_success' ? ['second-proactive-custom']
          : ['second-proactive-custom', 'second-proactive-custom', 'first-proactive-custom']);
    });
  }

  for (final point in ['before_late_fence', 'writer_wait', 'same_ms_count']) {
    test('real evaluate rejects reset at $point without consuming the ready source', () async {
      final (id, thoughtId) = await seedReady();
      if (point == 'same_ms_count') {
        await db.setSetting('conversation_context_reset_at', '123456789');
        await db.setSetting('conversation_context_reset_count', '1');
      }
      // An independent durable task is not context garbage.
      await db.setSetting('cedar_timed_play_reports_v1', '[{"id":"keep-independent-result"}]');
      final entered = Completer<void>(), release = Completer<void>();
      var writerCalls = 0;
      Future<void> hold() async {
        if (!entered.isCompleted) entered.complete();
        await release.future.timeout(_timeout);
      }
      final run = engine(beforeKey: point == 'before_late_fence' ? hold : null,
        writer: (request) async {
          writerCalls++;
          expect(jsonEncode(jsonDecode(request.body)['messages']), contains(_body));
          await hold();
          return _answer(_reply);
        }).evaluate(forceForDebug: true, forcedThoughtIdForDebug: thoughtId);
      var bodyFailed = false;
      try {
        await _entered(entered.future, run);
        if (point == 'same_ms_count') {
          // Reproduce two resets whose timestamp is identical: only count moves.
          await db.setSetting('conversation_context_reset_count', '2');
        } else {
          expect((await db.beginFreshConversationContext()).applied, isTrue);
        }
      } catch (_) { bodyFailed = true; rethrow; }
      finally {
        if (!release.isCompleted) release.complete();
        try { await run.timeout(_timeout); } catch (_) { if (!bodyFailed) rethrow; }
      }
      final result = await run;
      expect(result.sent, isFalse, reason: result.reason);
      expect(writerCalls, point == 'before_late_fence' ? 0 : 1);
      final sql = await db.database;
      expect(await sql.query('messages', where: 'is_proactive = 1'), isEmpty);
      expect((await db.thoughtById(thoughtId))!.lastActedAt, isNull);
      final row = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
      expect(row['lifecycle_state'], 'share_ready');
      expect(row['shared_message_id'], '');
      expect(await db.getSetting('cedar_timed_play_reports_v1'), '[{"id":"keep-independent-result"}]');
    });
  }

  test('real evaluate commits a current ready page and its thought once', () async {
    final (id, thoughtId) = await seedReady();
    var calls = 0;
    final e = engine(writer: (request) async {
      calls++;
      expect(jsonEncode(jsonDecode(request.body)['messages']), contains(_body));
      return _answer(_reply);
    });
    final sent = await e.evaluate(forceForDebug: true, forcedThoughtIdForDebug: thoughtId);
    expect(sent.sent, isTrue, reason: sent.reason);
    final sql = await db.database;
    final messages = await sql.query('messages', where: 'is_proactive = 1');
    expect(messages, hasLength(1));
    final page = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
    expect(page['shared_message_id'], messages.single['id']);
    expect(page['lifecycle_state'], 'shared');
    expect((await db.thoughtById(thoughtId))!.actionCount, 1);
    await e.evaluate(forceForDebug: true, forcedThoughtIdForDebug: thoughtId);
    expect(await sql.query('messages', where: 'is_proactive = 1'), hasLength(1));
    expect(calls, 1);
  });

  test('real evaluate can select its only expired staging candidate and invoke the stage reader', () async {
    final id = await db.seedDiagnosticPublicWebShareCandidate();
    final sql = await db.database;
    await sql.update('public_web_candidates', {'page_body': _body,
      'lifecycle_state': 'share_staging', 'share_stage_token': '', 'share_stage_until': 0,
      'discovered_at': DateTime.now().subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
      'last_viewed_at': DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    expect(await sql.query('public_web_candidates', where: "lifecycle_state = 'unread'"), isEmpty);
    var calls = 0;
    final result = await engine(writer: (_) async { calls++; return _answer('WAIT'); })
      .evaluate(forceForDebug: true);
    expect(calls, 1, reason: result.reason);
    expect(result.sent, isFalse);
    expect(await db.thoughtBySource(PublicWebSharePolicy.source(id)), isNotNull);
    final page = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
    expect(page['lifecycle_state'], 'declined');
    expect(await sql.query('messages', where: 'is_proactive = 1'), isEmpty);
  });
  test('real evaluate reset after choosing a private work does not spend its share cooldown', () async {
    final store = CreativeStore(db);
    await store.setAutonomyEnabled(true);
    final now = DateTime.now();
    final work = {...store.autonomousWork({'id': 'g3-private-idea', 'brief': '小灯',
      'motive': '记录颜色', 'evidence': <Object?>[]}, now,
      model: 'deepseek-flash', effort: 'high'), 'status': 'ready',
      'current': 'stored-version', 'share_after': 0};
    expect(await store.write({}, work), isTrue);
    final entered = Completer<void>(), release = Completer<void>();
    var writerCalls = 0;
    final run = engine(beforeKey: () async {
      entered.complete();
      await release.future.timeout(_timeout);
    }, writer: (_) async { writerCalls++; return _answer(_reply); })
      .evaluate(forceForDebug: true);
    var bodyFailed = false;
    try {
      await _entered(entered.future, run);
      expect((await db.beginFreshConversationContext()).applied, isTrue);
    } catch (_) { bodyFailed = true; rethrow; }
    finally {
      if (!release.isCompleted) release.complete();
      try { await run.timeout(_timeout); } catch (_) { if (!bodyFailed) rethrow; }
    }
    final result = await run;
    expect(result.sent, isFalse, reason: result.reason);
    expect(result.reason, '作品已变化或仍在私存冷却');
    expect(writerCalls, 0);
    expect(await store.get(work['id'] as String), work);
  });

}
