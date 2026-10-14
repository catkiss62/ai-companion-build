import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late DateTime base;
  late CedarToyAutonomyEngine engine;
  late int requests;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    final today = DateTime.now();
    base = DateTime(today.year, today.month, today.day, 12);
    requests = 0;
    final transport = MockClient((_) async { requests++; return http.Response('{}', 500); });
    engine = CedarToyAutonomyEngine(db: db, ai: DeepSeekClient(client: transport),
      secureConfig: SecureConfig.instance, tokenReader: () async => 'fixture-token',
      apiKeyReader: () async => 'fixture-key', endpointReader: () async => 'https://example.invalid/ai',
      clientFactory: (token) => CedarToyClient(token: token, transport: McpHttpClient(
        endpoint: Uri.parse('https://example.invalid/mcp'), client: transport)));
    final store = CedarToyActivityStore(db);
    await store.recordGuide(gameId: 'garden_cats', guide: '单人花园。种花、浇水、采收。');
    await store.recordPlay(gameId: 'garden_cats', action: 'water',
      outcome: const McpToolOutcome(content: [McpContentBlock(kind: McpContentKind.text,
        text: '浇水成功，可以继续照料其他花盆。')], isError: false),
      mode: CedarParticipationMode.solo, nextActor: 'companion', shareLevel: 'quiet', invitationApproved: false);
    final raw = jsonDecode((await db.getSetting(CedarToyActivityStore.stateSettingKey))!) as Map;
    for (final s in (raw['sessions'] as List).whereType<Map>()) {
      s['next_action_at'] = base.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
    }
    await db.setSetting(CedarToyActivityStore.stateSettingKey, jsonEncode(raw));
  });
  tearDown(() => db.closeForTesting());

  for (final minutes in [10, 30]) {
    test('$minutes-minute window expires before an extra game/model request', () async {
      final periods = CedarPlaySessionStore(db);
      expect(await periods.save(CedarPlaySession(gameId: 'garden_cats', startedAt: base,
        lastTickAt: base, limitMs: minutes * 60000, usedMs: minutes * 60000 - 1000)), true);
      final before = (await CedarToyActivityStore(db).load())!.events.length;
      final result = await engine.continueDue(now: base.add(const Duration(seconds: 2)));
      expect(result.state, 'autonomous_session_complete');
      expect(requests, 0);
      expect(await periods.load(), isNull);
      expect((await CedarToyActivityStore(db).load())!.events.length, before);
      expect(await db.getSetting('cedar_toy_play_session_end_reason'), 'budget_complete');
    });
  }

  test('repeat autonomous entry retains the original clock and remaining budget', () async {
    final periods = CedarPlaySessionStore(db);
    await periods.save(CedarPlaySession(gameId: 'garden_cats', startedAt: base,
      lastTickAt: base, usedMs: 240000, limitMs: 600000));
    final before = await db.getSetting(CedarPlaySessionStore.key);
    expect((await engine.beginPlaySession(now: base, resume: true, minutes: 30)).state,
      'autonomous_session_already_active');
    expect(await db.getSetting(CedarPlaySessionStore.key), before);
    expect(requests, 0);
  });

  test('stale owner and changed brain cannot clear or replenish a newer grant', () async {
    final periods = CedarPlaySessionStore(db);
    final fence = (await db.captureBrainWorkFence())!;
    await periods.save(CedarPlaySession(gameId: 'garden_cats', startedAt: base, lastTickAt: base));
    final old = (await periods.load())!;
    await periods.end('old_done', expectedClockId: old.clockId);
    await periods.save(CedarPlaySession(gameId: 'garden_cats', startedAt: base, lastTickAt: base, limitMs: 600000));
    final newer = await db.getSetting(CedarPlaySessionStore.key);
    expect(await periods.end('late_end', expectedClockId: old.clockId), false);
    expect(await periods.save(old.tick(base.add(const Duration(seconds: 30)))), false);
    await db.importAll(await db.exportAll());
    expect(await periods.end('late_restore', expectedRaw: newer, workFence: fence), false);
    expect(await db.getSetting(CedarPlaySessionStore.key), newer);
  });

  test('active observed time includes cadence but suspension and pauses do not', () {
    var clock = CedarPlaySession(gameId: 'garden_cats', startedAt: base, lastTickAt: base, limitMs: 600000);
    for (var i = 1; i <= 4; i++) clock = clock.tick(base.add(Duration(seconds: i * 128)));
    expect(clock.usedMs, 512000);
    expect(clock.tick(base.add(const Duration(seconds: 640))).usedMs, 600000);
    expect(clock.tick(base.add(const Duration(hours: 1))).usedMs, 512000);
    final paused = clock.tick(base.add(const Duration(seconds: 513)), pause: true);
    expect(paused.tick(base.add(const Duration(seconds: 540))).usedMs, paused.usedMs);
    expect(CedarPlaySessionStore.autonomousMinutes(sustained: false), 10);
    expect(CedarPlaySessionStore.autonomousMinutes(sustained: true), 30);
  });
}
