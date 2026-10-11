import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';

Map<String, dynamic> call(String name, Object args, {String id = ''}) => {
  'id': id.isEmpty ? 'c_$name' : id, 'name': name,
  'arguments': args is String ? args : jsonEncode(args),
};
Map<String, dynamic> plan({String interaction = 'local'}) => call('work_plan', {
  'title': '一盏灯', 'intro': '点亮它', 'plan': '按钮点亮，退出可恢复', 'interaction': interaction,
});
Map<String, dynamic> write(String html, {String before = '', String path = 'index.html', String mode = 'replace'}) =>
    call('work_write', {'path': path, 'content': html, 'expected_hash': before, 'mode': mode});
Map<String, dynamic> previewCall() => call('work_preview', {
  'checks': [{'click': '#light', 'selector': '#state', 'text': '亮了'}],
});
String sse(List<Map<String, dynamic>> calls, {String? finish = 'tool_calls', bool done = true}) {
  String event(Object delta, {String? reason}) => 'data: ${jsonEncode({'choices': [{'delta': delta, if (reason != null) 'finish_reason': reason}]})}\n\n';
  final out = StringBuffer(event({'reasoning_content': '检查已有文件，按实际结果修复。'}));
  for (var index = 0; index < calls.length; index++) {
    final c = calls[index];
    final args = c['arguments'] as String;
    final mid = args.length ~/ 2;
    out.write(event({'tool_calls': [{'index': index, 'id': c['id'], 'type': 'function',
      'function': {'name': c['name'], 'arguments': args.substring(0, mid)}}]}));
    out.write(event({'tool_calls': [{'index': index, 'function': {'arguments': args.substring(mid)}}]}));
  }
  if (finish != null) out.write(event({}, reason: finish));
  out.write('data: ${jsonEncode({'choices': [], 'usage': {'prompt_tokens': 40, 'completion_tokens': 30, 'prompt_cache_hit_tokens': 10, 'prompt_cache_miss_tokens': 30}})}\n\n');
  if (done) out.write('data: [DONE]\n\n');
  return out.toString();
}
http.Response response(String body, {int status = 200}) => http.Response(body, status,
    headers: {'content-type': 'text/event-stream; charset=utf-8'});
const broken = '<button id="light">点亮</button><p id="state">没亮</p>';
const repaired = '<button id="light">点亮</button><p id="state">亮了</p>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  var clock = DateTime(2026, 10, 11, 12);
  final requests = <Map<String, dynamic>>[];
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    requests.clear(); clock = DateTime(2026, 10, 11, 12);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-key-only'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (_) async => {'ok': true, 'errors': [], 'page_text': '亮了', 'elements': []});
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview, null);
    await db.closeForTesting();
  });
  Future<String> commission({String request = '请制作一个点亮按钮', String brief = '一盏小灯'}) async =>
      (await store.commission(deepThinking: true, requestId: 'request', messageId: 'message',
        brief: brief, requestQuote: request, latestText: request))['id'] as String;
  CreativeWorker worker(Future<http.Response> Function(int, http.Request) handler) =>
      CreativeWorker(db, now: () => clock, clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
        streamClientFactory: () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-key-only');
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return handler(requests.length, request);
        })));
  Future<Map<String, dynamic>> state(String id) async =>
      CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
  Future<void> tick(CreativeWorker runtime) async { clock = clock.add(const Duration(hours: 1)); await runtime.runOnce(); }

  test('native SSE tools repair preview feedback; isolated context and chat coexist', () async {
    final id = await commission();
    await db.setSetting('nightly_dream_state_v1', 'PRIVATE_DREAM');
    final handle = await db.database;
    await handle.insert('messages', {'id': 'unrelated', 'role': 'user', 'content': 'PRIVATE_CHAT', 'created_at': 1});
    await db.tryAcquireLocalLease('chat_turn_lease');
    var previews = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (method) async {
        previews++;
        final args = method.arguments as Map;
        expect(args['html'], previews == 1 ? broken : repaired);
        return {'ok': previews > 1, 'errors': previews == 1 ? ['button failed'] : [], 'page_text': '按钮实际文字'};
      });
    final runtime = worker((n, request) async {
      expect(request.body, isNot(contains('PRIVATE_DREAM')));
      expect(request.body, isNot(contains('PRIVATE_CHAT')));
      final body = requests.last;
      expect(body['model'], 'deepseek-flash'); expect(body['reasoning_effort'], 'max');
      expect(body['stream'], true); expect(body['tools'], isNotEmpty);
      expect(body.containsKey('response_format'), false);
      if (n == 1) return response(sse([plan(), write(broken), previewCall()]));
      expect(request.body, contains('button failed'));
      expect((body['messages'] as List).whereType<Map>().any((m) => m['role'] == 'assistant' && m['reasoning_content'] != null), true);
      return response(sse([call('work_patch', {'path': 'index.html', 'expected_hash': CreativeContract.hash(broken),
        'old_text': '没亮', 'new_text': '亮了'}), previewCall(), call('work_finish', {})]));
    });
    await runtime.runOnce();
    expect((await store.get(id))['current'], isNull);
    expect(CreativeWorkspace.files(await state(id))['index.html'], broken);
    await runtime.runOnce();
    final ready = await store.get(id);
    expect(ready['status'], 'ready');
    expect(await db.getSetting('${CreativeContract.sourcePrefix}${ready['current']}'), repaired);
    expect(requests.length, 2); expect(previews, 2);
    await runtime.runOnce(); expect(requests.length, 2);
    final diagnostics = jsonEncode(await store.diagnostics());
    expect(diagnostics, contains('tool_calls'));
    expect(diagnostics, isNot(contains('检查已有文件')));
    expect(diagnostics, isNot(contains(broken)));
  });

  test('malformed arguments become tool feedback and a later call repairs them', () async {
    final id = await commission();
    final runtime = worker((n, request) async {
      if (n == 1) return response(sse([plan(), call('work_write', '{"path":')]));
      expect((requests.last['messages'] as List).last['role'], 'tool');
      expect((requests.last['messages'] as List).last['content'], contains('false'));
      return response(sse([write(repaired), previewCall(), call('work_finish', {})]));
    });
    await runtime.runOnce();
    expect(CreativeWorkspace.files(await state(id)), isEmpty);
    expect((await store.get(id))['status'], 'building');
    await runtime.runOnce(); expect((await store.get(id))['status'], 'ready');
  });

  test('foreground and background runners cannot request the same commission twice', () async {
    final id = await commission();
    final started = Completer<void>();
    final release = Completer<void>();
    final first = worker((_, request) async {
      started.complete(); await release.future;
      return response(sse([plan(), write(repaired)]));
    });
    final second = worker((_, request) async { fail('second loop stole the live lease'); });
    final running = first.runOnce();
    await started.future;
    await second.runOnce();
    release.complete(); await running;
    expect(requests.length, 1);
    expect(CreativeWorkspace.files(await state(id))['index.html'], repaired);
  });

  test('length never executes a seemingly complete tool; existing files survive', () async {
    final id = await commission();
    final runtime = worker((n, request) async {
      if (n == 1) return response(sse([plan(), write(repaired)]));
      if (n == 2) return response(sse([write('BROKEN_REPLACEMENT', before: CreativeContract.hash(repaired))], finish: 'length'));
      expect(requests.last['max_tokens'], 128000);
      expect(request.body, contains('输出达到长度上限'));
      return response(sse([previewCall(), call('work_finish', {})]));
    });
    await runtime.runOnce(); await runtime.runOnce();
    expect(CreativeWorkspace.files(await state(id))['index.html'], repaired);
    expect((await store.get(id))['status'], 'queued');
    expect((await store.get(id))['errors'], ['length']);
    await runtime.runOnce(); expect(requests.length, 2); // backoff
    await tick(runtime); expect((await store.get(id))['status'], 'ready');
  });

  test('EOF without finish does not invent a draft and resumes with explicit cause', () async {
    final id = await commission();
    final runtime = worker((n, request) async => n == 1
      ? response(sse([write(repaired)], finish: null, done: false))
      : response(sse([plan(), write(repaired), previewCall(), call('work_finish', {})])));
    await runtime.runOnce();
    expect(CreativeWorkspace.files(await state(id)), isEmpty);
    expect((await store.get(id))['note'], contains('尚未生成有效草稿'));
    expect((await store.get(id))['errors'], ['incomplete_stream']);
    await tick(runtime); expect((await store.get(id))['status'], 'ready');
  });

  test('temporary HTTP errors back off and stop after a finite number of paid attempts', () async {
    final id = await commission();
    final runtime = worker((_, request) async => response('{"error":{"message":"temporary"}}', status: 503));
    await runtime.runOnce(); await runtime.runOnce(); expect(requests.length, 1);
    for (var i = 1; i < CreativeWorker.maxFailures; i++) { await tick(runtime); }
    expect((await store.get(id))['status'], 'paused');
    await tick(runtime); expect(requests.length, CreativeWorker.maxFailures);
    expect((await store.get(id))['errors'], ['http_503']);
  });

  test('credentials or balance errors pause without repeated calls or secret error bodies', () async {
    final id = await commission();
    final runtime = worker((_, request) async => response('{"error":{"message":"PRIVATE_PROVIDER_BODY"}}', status: 401));
    await runtime.runOnce(); await tick(runtime);
    expect(requests.length, 1); expect((await store.get(id))['status'], 'paused');
    expect(jsonEncode(await store.diagnostics()), isNot(contains('PRIVATE_PROVIDER_BODY')));
  });

  test('a saved model response resumes its remaining append without another API call', () async {
    final id = await commission();
    var meta = await store.get(id);
    final agent = CreativeWorkspace.create(id, meta['request_id'] as String);
    CreativeWorkspace.edit(agent, {'path': 'index.html', 'mode': 'replace', 'content': 'A', 'expected_hash': ''});
    final pending = [write('A'), write('B', before: CreativeContract.hash('A'), mode: 'append')];
    pending[0]['id'] = 'first'; pending[1]['id'] = 'second';
    agent['pending'] = pending; agent['next_tool'] = 1;
    agent['history'] = [{'role': 'assistant', 'reasoning_content': 'continue', 'content': '', 'tool_calls': pending.map((c) => {
      'id': c['id'], 'type': 'function', 'function': {'name': c['name'], 'arguments': c['arguments']},
    }).toList()}, {'role': 'tool', 'tool_call_id': 'first', 'content': '{"saved":true}'}];
    await store.write(meta, {...meta, 'status': 'building'}, extra: {CreativeWorkspace.key(id): jsonEncode(agent)});
    final runtime = worker((_, request) async { fail('completed model step must not be requested again'); });
    await runtime.runOnce();
    expect(CreativeWorkspace.files(await state(id))['index.html'], 'AB');
    expect((await state(id))['pending'], isEmpty);
    expect(requests, isEmpty);
  });

  test('stop during preview fences late publication and explicit resume retains the response', () async {
    final id = await commission();
    var stopped = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (_) async {
        if (!stopped) { stopped = true; await store.stop(id); }
        return {'ok': true, 'errors': []};
      });
    final runtime = worker((_, request) async => response(sse([plan(), write(repaired), previewCall(), call('work_finish', {})])));
    await runtime.runOnce();
    expect((await store.get(id))['status'], 'paused'); expect((await store.get(id))['current'], isNull);
    await runtime.runOnce(); expect(requests.length, 1);
    await store.resume(id, deepThinking: true);
    await runtime.runOnce();
    expect((await store.get(id))['status'], 'ready'); expect(requests.length, 1);
  });

  test('delete during generation rejects late calls and does not resurrect files', () async {
    final id = await commission();
    final runtime = worker((_, request) async {
      await store.delete(id);
      return response(sse([plan(), write(repaired), previewCall(), call('work_finish', {})]));
    });
    await runtime.runOnce();
    expect((await store.get(id))['status'], 'deleted');
    expect(await db.getSetting(CreativeWorkspace.key(id)), '');
  });

  test('file changed after preview cannot publish the old verification', () async {
    final id = await commission();
    final runtime = worker((_, request) async => response(sse([
      plan(), write(repaired), previewCall(),
      {...write(broken, before: CreativeContract.hash(repaired)), 'id': 'rewrite'}, call('work_finish', {}),
    ])));
    await runtime.runOnce();
    expect((await store.get(id))['current'], isNull);
    expect(CreativeWorkspace.files(await state(id))['index.html'], broken);
    expect(jsonEncode((await state(id))['feedback']), contains('重新试玩'));
  });

  test('companion works require actual choose and reveal receipts, not just a passing title check', () async {
    final id = await commission(request: '做一个我们一起玩的猜拳');
    var previews = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (_) async { previews++; return {'ok': true, 'errors': [],
        'choose_count': previews == 1 ? 0 : 1, 'reveal_count': previews == 1 ? 0 : 1,
        'save_count': previews == 1 ? 0 : 1, 'reload_count': previews == 1 ? 0 : 1}; });
    final runtime = worker((n, request) async => response(sse(n == 1
        ? [plan(interaction: 'companion'), write(repaired), previewCall(), call('work_finish', {})]
        : [previewCall(), call('work_finish', {})])));
    await runtime.runOnce(); expect((await store.get(id))['current'], isNull);
    await runtime.runOnce(); expect((await store.get(id))['status'], 'ready');
  });

  test('archive carries editable files, pauses work, invalidates preview and resumes without regeneration', () async {
    final id = await commission();
    final runtime = worker((n, request) async => response(sse(n == 1
      ? [plan(), write(repaired), previewCall()] : [previewCall(), call('work_finish', {})])));
    await runtime.runOnce();
    final backup = await db.exportAll();
    await db.importAll(Map<String, dynamic>.from(backup));
    expect((await store.get(id))['status'], 'paused');
    expect((await state(id))['verification'], isEmpty);
    expect(CreativeWorkspace.files(await state(id))['index.html'], repaired);
    await runtime.runOnce(); expect(requests.length, 1);
    await store.resume(id, deepThinking: true); await runtime.runOnce();
    expect((await store.get(id))['status'], 'ready');
  });

  test('raw user request survives delegation and legacy assistant-card lookup', () async {
    final id = await commission(request: '请做一个和你一起玩的猜拳', brief: '离线随机电脑');
    expect((await store.get(id))['original_request'], '请做一个和你一起玩的猜拳');
    final handle = await db.database;
    await handle.insert('messages', {'id': 'old-user', 'role': 'user', 'content': '旧的原始要求', 'created_at': 10});
    await handle.insert('messages', {'id': 'old-card', 'role': 'assistant', 'content': '开始制作', 'created_at': 20});
    expect(await store.originalRequest({'message_id': 'old-card'}), '旧的原始要求');
  });

  test('a delegated companion requirement cannot be downgraded to a local opponent', () async {
    final meta = await store.commission(deepThinking: true, requestId: 'shared', messageId: 'message',
      requestQuote: '我们一起玩', latestText: '我们一起玩', brief: '制作游戏', interaction: 'companion');
    final id = meta['id'] as String;
    final runtime = worker((_, request) async => response(sse([plan(), write(repaired), previewCall(), call('work_finish', {})])));
    await runtime.runOnce();
    expect((await store.get(id))['current'], isNull);
    expect(jsonEncode((await state(id))['feedback']), contains('不能改成本地随机对手'));
  });

  test('workspace rejects stale edits and unexpected paths and bundles separate assets', () {
    final agent = CreativeWorkspace.create('id', 'r');
    CreativeWorkspace.edit(agent, {'path': 'index.html', 'mode': 'replace', 'content': '<h1>Hi</h1>', 'expected_hash': ''});
    expect(() => CreativeWorkspace.edit(agent, {'path': 'index.html', 'mode': 'replace', 'content': 'bad', 'expected_hash': ''}), throwsFormatException);
    expect(() => CreativeWorkspace.read(agent, {'path': '../key'}), throwsFormatException);
    CreativeWorkspace.edit(agent, {'path': 'style.css', 'mode': 'replace', 'content': 'body{color:red}', 'expected_hash': ''});
    CreativeWorkspace.edit(agent, {'path': 'script.js', 'mode': 'replace', 'content': 'window.sample="</script>";', 'expected_hash': ''});
    final html = CreativeWorkspace.assemble(agent);
    expect(html, contains('body{color:red}')); expect(html, contains(r'<\/script>'));
    expect(html, contains('<h1>Hi</h1>'));
    final corrupt = {...agent, 'files': {'../key': 'bad'}};
    expect(() => CreativeWorkspace.validate(corrupt, 'id'), throwsFormatException);
  });
}
