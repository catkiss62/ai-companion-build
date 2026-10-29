import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_config.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_event.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_transport.dart';
import 'package:ai_companion_localfirst/core/diagnostics/third_channel_diagnostics.dart';

class _RealHttp extends HttpOverrides {}
String _sse(String text)=>'data: ${jsonEncode({'choices':[{'delta':{'content':text},'finish_reason':'stop'}],
  'usage':{'prompt_tokens':10,'completion_tokens':2,'completion_tokens_details':{'reasoning_tokens':3}}})}\n\ndata: [DONE]\n\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>HttpOverrides.global=_RealHttp());
  test('health and SSE reuse one actual TCP connection across disposable wrappers',() async {
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0),pool=ThirdChannelTransportPool();
    final ports=<int>{},ids=<String>[],events=<ThirdChannelEvent>[];
    final usageA=<int>[],usageB=<int>[]; var health=0,posts=0;
    server.listen((r) async {
      ports.add(r.connectionInfo!.remotePort); ids.add(r.headers.value('x-request-id')!);
      if(r.uri.path=='/health') {health++;await r.drain();r.response.write('{"status":"ok"}');}
      else {
        posts++;final body=jsonDecode(await utf8.decoder.bind(r).join()) as Map;
        expect(body['reasoning_effort'],'low');
        r.response.headers.contentType=ContentType('text','event-stream',charset:'utf-8');r.response.write(_sse('成功'));
      }
      await r.response.close();
    });
    final config=ThirdChannelConfig(baseUrl:'http://127.0.0.1:${server.port}/v1',apiKey:'synthetic',effort:'low');
    final a=ThirdChannelClient(transportPool:pool,onUsage:(u,_,_) async=>usageA.add(u.total));
    final b=ThirdChannelClient(transportPool:pool,onUsage:(u,_,_) async=>usageB.add(u.total));
    try {
      expect((await a.complete(config:config,messages:[],onDiagnostic:events.add)).content,'成功'); a.close();
      expect((await b.complete(config:config,messages:[],onDiagnostic:events.add)).content,'成功');
      expect(health,2);expect(posts,2);expect(ports,hasLength(1));expect(ids.toSet(),hasLength(4));
      expect(usageA,[15]);expect(usageB,[15]);
      expect(events.first.transportReused,false);expect(events.last.transportReused,true);
      expect(events.last.effort,'low');expect(events.last.requestBytes,greaterThan(0));
      expect(events.last.firstContentElapsedMs,greaterThanOrEqualTo(events.last.headersElapsedMs));
      expect(events.last.tailAborted,false);
    } finally {a.close();b.close();pool.close();await server.close(force:true);}
  });
  for(final cancel in ['token','wrapper_close']) {
    test('$cancel stops one active stream without closing another pooled request',() async {
      final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0),pool=ThirdChannelTransportPool();
      final entered=Completer<void>(),release=Completer<void>();
      server.listen((r) async {
        try {
          if(r.uri.path=='/health') {await r.drain();r.response.write('{"status":"ok"}');}
          else {
            final body=await utf8.decoder.bind(r).join();r.response.headers.contentType=ContentType('text','event-stream',charset:'utf-8');
            if(body.contains('cancel-me')) {
              r.response.write('data: {"choices":[{"delta":{"content":"未完成"}}]}\n\n'); await r.response.flush();
              entered.complete();await release.future;
            } else {r.response.write(_sse('另一条完成'));}
          }
          await r.response.close();
        } catch(_) { /* The canceled loopback peer is expected to disconnect. */ }
      });
      final config=ThirdChannelConfig(baseUrl:'http://127.0.0.1:${server.port}/v1',apiKey:'synthetic');
      final a=ThirdChannelClient(transportPool:pool),b=ThirdChannelClient(transportPool:pool),token=GenerationCancellationToken();
      final first=a.complete(config:config,messages:[{'role':'user','content':'cancel-me'}],cancellation:token);
      final stopped=expectLater(first,throwsA(cancel=='token'?isA<GenerationCancelledByUserException>():isA<GenerationSuspendedByRuntimeGateException>()));
      try {
        await entered.future.timeout(const Duration(seconds:3));
        final second=b.complete(config:config,messages:[{'role':'user','content':'keep-going'}]);
        if(cancel=='token') {token.cancel();} else {a.close();}
        await stopped.timeout(const Duration(seconds:3));
        expect((await second.timeout(const Duration(seconds:3))).content,'另一条完成');
      } finally {if(!release.isCompleted)release.complete();a.close();b.close();pool.close();await server.close(force:true);}
    });
  }
  test('a hanging HTTP tail after complete usage/DONE is bounded to two seconds',() async {
    final phases=<String>[];
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0),
      pool=ThirdChannelTransportPool(clientFactory:()=>_TapClient(phases));
    final release=Completer<void>(),events=<ThirdChannelEvent>[];
    server.listen((r) async {
      try {
        await r.drain();
        if(r.uri.path=='/health') {r.response.write('{"status":"ok"}');}
        else {r.response.bufferOutput=false;r.response.headers.contentType=ContentType('text','event-stream',charset:'utf-8');
          r.response.write(_sse('完整回答'));await r.response.flush();phases.add('server_flushed');await release.future;}
        await r.response.close();
      } catch(_) {}
    });
    final client=ThirdChannelClient(transportPool:pool),clock=Stopwatch()..start();
    try {
      final result=await client.complete(config:ThirdChannelConfig(baseUrl:'http://127.0.0.1:${server.port}',apiKey:'synthetic'),messages:[],onDiagnostic:events.add)
        .timeout(const Duration(seconds:5),onTimeout:()=>throw StateError('loopback tail phases: $phases'));
      expect(result.content,'完整回答');expect(clock.elapsedMilliseconds,lessThan(4500));expect(events.single.tailAborted,true);
    } finally {release.complete();client.close();pool.close();await server.close(force:true);}
  });
  test('complete SSE with a never-ending synthetic response is also bounded',() async {
    final controller=StreamController<List<int>>();
    final client=ThirdChannelClient(clientFactory:()=>MockClient.streaming((request,_) async {
      if(request.url.path=='/health') return http.StreamedResponse(Stream.value(utf8.encode('{"status":"ok"}')),200);
      controller.add(utf8.encode(_sse('合成完整回答')));
      return http.StreamedResponse(controller.stream,200);
    }));
    try {
      final result=await client.complete(config:const ThirdChannelConfig(baseUrl:'https://fixture.invalid',apiKey:'synthetic'),messages:[])
        .timeout(const Duration(seconds:4));
      expect(result.content,'合成完整回答');
    } finally {client.close();await controller.close();}
  });
  test('a changed profile retires the old transport after its last lease',() async {
    var created=0,closed=0;
    final pool=ThirdChannelTransportPool(clientFactory:()=>_TrackedClient((){closed++;},()=>created++));
    const one=ThirdChannelConfig(baseUrl:'https://one.invalid',apiKey:'synthetic');
    const two=ThirdChannelConfig(baseUrl:'https://two.invalid',apiKey:'synthetic');
    final a=await pool.acquire(one),b=await pool.acquire(one);expect(created,1);expect(b.reused,true);
    final c=await pool.acquire(two);expect(created,2);expect(closed,0);
    a.release();expect(closed,0);b.release();expect(closed,1);b.release();expect(closed,1);
    c.release();pool.close();expect(closed,2);
  });
  test('observable network change and failed transport invalidate reuse without interrupting another lease',() async {
    var network='wifi',created=0,closed=0;
    final pool=ThirdChannelTransportPool(networkIdentity:() async=>network,
      clientFactory:()=>_TrackedClient((){closed++;},()=>created++));
    const config=ThirdChannelConfig(baseUrl:'https://fixture.invalid',apiKey:'synthetic');
    final a=await pool.acquire(config);a.release();
    final b=await pool.acquire(config);expect(b.reused,true);
    network='vpn';final c=await pool.acquire(config);expect(c.reused,false);expect(created,2);expect(closed,0);
    b.release();expect(closed,1);
    c.invalidate();final d=await pool.acquire(config);expect(d.reused,false);expect(created,3);expect(closed,1);
    c.release();expect(closed,2);d.release();pool.close();expect(closed,3);
  });
  test('failure to inspect the network falls back to fresh transports rather than blocking requests',() async {
    var created=0;
    final pool=ThirdChannelTransportPool(networkIdentity:() async=>throw StateError('unavailable'),
      clientFactory:()=>_TrackedClient((){},()=>created++));
    const config=ThirdChannelConfig(baseUrl:'https://fixture.invalid',apiKey:'synthetic');
    final a=await pool.acquire(config);a.release();final b=await pool.acquire(config);
    expect(b.reused,false);expect(created,2);b.release();pool.close();
  });
  test('new timing facts are bounded and cannot persist arbitrary ids or effort text',() {
    final safe=ThirdChannelDiagnostics.sanitize({'request_id':'PRIVATE https://host.invalid',
      'reasoning_effort':'PRIVATE','request_bytes':-1,'model_elapsed_ms':999999999,
      'first_content_elapsed_ms':42,'url':'PRIVATE','body':'PRIVATE'});
    expect(jsonEncode(safe),isNot(contains('PRIVATE')));expect(safe['request_id'],'');
    expect(safe['model_elapsed_ms'],86400000);expect(safe['request_bytes'],0);expect(safe['first_content_elapsed_ms'],42);
  });
}

class _TrackedClient extends MockClient {
  _TrackedClient(this.onClose,void Function() onCreate):super((_) async=>http.Response('{}',200)) {onCreate();}
  final void Function() onClose;
  @override void close() {onClose();super.close();}
}

class _TapClient extends http.BaseClient {
  _TapClient(this.phases);
  final List<String> phases;
  final http.Client inner=http.Client();
  @override Future<http.StreamedResponse> send(http.BaseRequest request) async {
    phases.add('${request.method}_start');final response=await inner.send(request);
    phases.add('${request.method}_headers');
    return http.StreamedResponse(response.stream.map((bytes) {
      phases.add('${request.method}_bytes:${bytes.length}');return bytes;
    }),response.statusCode,headers:response.headers);
  }
  @override void close()=>inner.close();
}
