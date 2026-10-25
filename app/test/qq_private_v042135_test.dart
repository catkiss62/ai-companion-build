import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_readonly_context.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_private_config.dart';

Future<void> until(bool Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!check()) {
    if (DateTime.now().isAfter(deadline)) fail('QQ test condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _GatewayApi extends QqApi {
  _GatewayApi(this.url) : super(appId: 'test', secret: 'test');
  final String url;
  @override Future<String> token() async => 'test-token';
  @override Future<String> gatewayUrl() async => url;
}

// Bypass only Flutter's HTTP-400 test override, so the protocol test exercises
// the real loopback server rather than a fabricated success response.
class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late QqJournal journal;
  final sessions = <QqPrivateSession>[];
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('qq-private-test-');
    journal = QqJournal(File('${temporary.path}/qq.json'));
    await journal.open();
  });
  tearDown(() async {
    for (final session in sessions) { await session.stop(); }
    sessions.clear();
    await temporary.delete(recursive: true);
  });
  Map<String, dynamic> event(String id, {String sender = 'owner', String text = '你好'}) => {
    'id': id, 'author': {'user_openid': sender}, 'content': text,
    'timestamp': DateTime.now().toUtc().toIso8601String(), 'message_type': 0,
  };
  QqPrivateSession create({String owner = 'owner', String code = 'LOCALCODE',
      QqGenerate? generate, Future<void> Function(String, String, String, int)? send,
      Future<void> Function(String)? bind, Future<bool> Function()? allowed,
      Future<bool> Function()? yieldToChat, DateTime? expires, List<String>? statuses}) {
    final session = QqPrivateSession(journal: journal, owner: owner, pairCode: code,
      pairExpires: expires ?? DateTime.now().add(const Duration(minutes: 10)),
      bindOwner: bind ?? (_) async {}, allowed: allowed ?? () async => true,
      yieldToChat: yieldToChat ?? () async => false,
      generate: generate ?? (_, __) async => '你好呀',
      send: send ?? (_, __, ___, ____) async {}, onStatus: statuses?.add ?? (_) {});
    sessions.add(session); return session;
  }

  test('unbound, strangers and injected group events never reach private context', () async {
    var reads = 0;
    final unbound = create(owner: '', generate: (_, __) async { reads++; return 'private'; });
    await unbound.accept(event('a'));
    await unbound.accept(event('b', text: '/绑定 WRONG'));
    final bound = create(generate: (_, __) async { reads++; return 'private'; });
    await bound.accept(event('c', sender: 'stranger'));
    await bound.accept({...event('d'), 'group_openid': 'group'});
    await bound.accept({...event('e'), 'guild_id': 'guild'});
    await bound.drain();
    expect(reads, 0); expect(journal.rows, isEmpty);
  });

  test('one-time local pairing persists identity before private access', () async {
    final writes = <String>[];
    final session = create(owner: '', bind: (s) async { writes.add(s); });
    await session.accept(event('pair', text: '/绑定 LOCALCODE'));
    await until(() => journal.rows.single['state'] == 'sent');
    expect(writes, ['owner']); expect(session.owner, 'owner'); expect(session.pairCode, '');
    await session.accept(event('intruder', sender: 'other', text: '/绑定 LOCALCODE'));
    expect(journal.rows.length, 1);
  });

  test('expired pairing and failed identity save cannot unlock memory', () async {
    final expired = create(owner: '', expires: DateTime(2000));
    await expired.accept(event('expired', text: '/绑定 LOCALCODE'));
    expect(expired.owner, '');
    final failed = create(owner: '', bind: (_) async { throw StateError('secure storage failed'); });
    await expectLater(failed.accept(event('failed', text: '/绑定 LOCALCODE')), throwsStateError);
    expect(failed.owner, ''); expect(journal.rows, isEmpty);
  });

  test('duplicate deliveries during slow generation create one paid turn', () async {
    final entered = Completer<void>(), output = Completer<String>();
    var generations = 0, sends = 0;
    final session = create(generate: (_, __) { generations++; entered.complete(); return output.future; },
      send: (_, __, ___, ____) async { sends++; });
    await session.accept(event('same'));
    await entered.future;
    await Future.wait([session.accept(event('same')), session.accept(event('same'))]);
    expect(generations, 1); expect(journal.rows.length, 1);
    output.complete('只回一次');
    await until(() => journal.rows.single['state'] == 'sent');
    await session.accept(event('same'));
    expect(sends, 1); expect(generations, 1);
  });

  test('later input is durably accepted while prior model waits', () async {
    final entered = Completer<void>(), first = Completer<String>();
    final contexts = <List<Map<String, String>>>[];
    final session = create(generate: (text, history) async {
      contexts.add(history);
      if (contexts.length == 1) { entered.complete(); return first.future; }
      return '第二轮';
    });
    await session.accept(event('first', text: '第一轮'));
    await entered.future;
    await session.accept(event('second', text: '继续'));
    expect(journal.rows.length, 2);
    expect(jsonDecode(await journal.file.readAsString())['rows'].length, 2);
    first.complete('第一轮回复');
    await until(() => journal.rows.first['state'] == 'sent');
    await session.drain();
    expect(journal.rows.last['state'], 'sent');
    expect(contexts.last, [{'role': 'user', 'content': '第一轮'}, {'role': 'assistant', 'content': '第一轮回复'}]);
  });

  test('transfer freeze and App priority do not drop queued messages', () async {
    var enabled = false, busy = true, generated = 0;
    final session = create(allowed: () async => enabled, yieldToChat: () async => busy,
      generate: (_, __) async { generated++; return 'ok'; });
    await session.accept(event('wait'));
    await session.drain(); expect(generated, 0);
    enabled = true; await session.drain(); expect(generated, 0);
    busy = false; await session.drain();
    expect(generated, 1); expect(journal.rows.single['state'], 'sent');
  });

  test('unsupported media and stale events never invoke a model', () async {
    var generations = 0;
    final session = create(generate: (_, __) async { generations++; return 'bad'; });
    await session.accept({...event('media'), 'attachments': [{'content_type': 'voice', 'url': 'https://not-downloaded.test'}]});
    await until(() => journal.rows.single['state'] == 'sent');
    await session.accept({...event('old'), 'timestamp': DateTime(2000).toIso8601String()});
    await session.accept({...event('quote'), 'message_type': 103});
    await until(() => journal.rows.last['state'] == 'sent');
    expect(generations, 0); expect(journal.rows.length, 2);
  });

  test('unknown send and interrupted generation are not replayed after restart', () async {
    var attempts = 0;
    final session = create(send: (_, __, ___, ____) async { attempts++; throw QqApiException('timeout', uncertain: true); });
    await session.accept(event('unknown'));
    await until(() => journal.rows.single['state'] == 'send_uncertain');
    journal.rows.add({'id': 'killed', 'user': 'hi', 'reply': '', 'at': 1, 'state': 'working', 'sent': 0});
    await journal.save(); await session.stop();
    final restored = QqJournal(journal.file); await restored.open();
    journal = restored;
    var regenerated = 0;
    final next = create(generate: (_, __) async { regenerated++; return 'bad'; });
    await next.drain();
    expect(restored.rows.map((r) => r['state']), ['send_uncertain', 'generation_interrupted']);
    expect(attempts, 1); expect(regenerated, 0);
  });

  test('chunking preserves surrogate pairs and original text', () {
    final text = List.filled(3700, '🐳').join();
    final pieces = splitQqText(text);
    expect(pieces.map((s) => s.runes.length), [1800, 1800, 100]); expect(pieces.join(), text);
  });

  test('late pairing from retired namespace cannot replace new credentials or owner', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await const QqPrivateConfig(appId: '100', secret: 'old', namespace: 'oldnamespace').save();
    await const QqPrivateConfig(appId: '200', secret: 'new', namespace: 'newnamespace').save();
    await QqPrivateConfig.bind('oldnamespace', 'old-owner');
    final current = await QqPrivateConfig.read();
    expect(current.appId, '200'); expect(current.secret, 'new'); expect(current.owner, '');
    await QqPrivateConfig.bind('newnamespace', 'new-owner');
    expect((await QqPrivateConfig.read()).owner, 'new-owner');
  });

  test('real HTTP adapter authenticates and requires a send receipt', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    final subscription = server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('getAppAccessToken')) {
        requests.add(jsonDecode(body)); request.response.write(jsonEncode({'access_token': 'TOKEN', 'expires_in': 7200}));
      } else {
        expect(request.headers.value('authorization'), 'QQBot TOKEN');
        expect(request.headers.value('X-Union-Appid'), 'APP');
        requests.add(jsonDecode(body)); request.response.write(jsonEncode(requests.length == 2 ? {'id': 'receipt'} : {}));
      }
      await request.response.close();
    });
    final root = 'http://127.0.0.1:${server.port}';
    final api = QqApi(appId: 'APP', secret: 'SECRET', apiBase: root, tokenBase: root,
      client: _RealHttp().createHttpClient(null));
    try {
      await api.send('owner', 'original', 'hello', 2);
      expect(requests.first, {'appId': 'APP', 'clientSecret': 'SECRET'});
      expect(requests[1], {'msg_type': 0, 'content': 'hello', 'msg_id': 'original', 'msg_seq': 2});
      await expectLater(api.send('owner', 'next', 'hello', 1), throwsA(isA<QqApiException>().having((e) => e.uncertain, 'uncertain', true)));
    } finally { api.close(); await subscription.cancel(); await server.close(force: true); }
  });

  test('real WebSocket handshake scopes subscription to C2C and ignores groups', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final identified = Completer<Map>(), message = Completer<Map>();
    final subscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(jsonEncode({'op': 10, 'd': {'heartbeat_interval': 45000}}));
      socket.listen((raw) {
        final frame = jsonDecode(raw as String) as Map;
        if (frame['op'] == 2) {
          identified.complete(frame);
          socket.add(jsonEncode({'op': 0, 's': 1, 't': 'READY', 'd': {'session_id': 'session'}}));
          socket.add(jsonEncode({'op': 0, 's': 2, 't': 'GROUP_AT_MESSAGE_CREATE', 'd': event('group')}));
          socket.add(jsonEncode({'op': 0, 's': 3, 't': 'C2C_MESSAGE_CREATE', 'd': event('private')}));
        }
      });
    });
    final gateway = QqGateway(_GatewayApi('ws://127.0.0.1:${server.port}'),
      onMessage: (m) async { expect(message.isCompleted, false); message.complete(m); }, onStatus: (_) {});
    final run = gateway.run();
    try {
      expect((await identified.future)['d']['intents'], 1 << 25);
      expect((await message.future)['id'], 'private');
    } finally { await gateway.stop(); await run; await subscription.cancel(); await server.close(force: true); }
  });

  test('host memory snapshot leaves every existing SQLite table unchanged', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      final sql = await db.database;
      await sql.insert('memory_items', {'id': 'readonly-shell', 'kind': 'user_profile', 'content': '喜欢蓝色贝壳',
        'importance': .9, 'confidence': .9, 'source': 'test', 'status': 'active',
        'semantic_type': 'current_fact', 'subject_key': 'shell', 'tags': '贝壳',
        'created_at': 1, 'updated_at': 1});
      Future<Map<String, Object>> snapshot() async {
        final tables = await sql.rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
        return {for (final t in tables) t['name'] as String:
          await sql.rawQuery('SELECT * FROM "${t['name']}"')};
      }
      final before = await snapshot();
      final context = await QqReadOnlyContext(db).build('蓝色贝壳');
      expect(context, contains('喜欢蓝色贝壳'));
      expect(await snapshot(), before);
      await db.setSetting('active_brain', '0');
      await expectLater(QqReadOnlyContext(db).build('贝壳'), throwsStateError);
    } finally { await db.closeForTesting(); }
  });
}
