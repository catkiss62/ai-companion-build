import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_controller.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_gateway.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_prompt.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';

const configuration=ModelDialogueConfiguration(
  ModelDialogueEndpoint(speaker:'deepseek',endpoint:'https://ds.example/chat/completions',model:'deepseek-test',apiKey:'test-only-ds'),
  ModelDialogueEndpoint(speaker:'gemini',endpoint:'https://gm.example/chat/completions',model:'gemini-test',apiKey:'test-only-gm'));
String frame(String text,{String action='continue',bool done=true,String finish='stop'}) {
  final result=jsonEncode({'text':text,'action':action});
  return 'data: ${jsonEncode({'choices':[{'delta':{'content':result},'finish_reason':finish}]})}\n\n${done?'data: [DONE]\n\n':''}';
}
class _StreamClient extends http.BaseClient {
  _StreamClient(this.frames,this.onSend);
  final StreamController<List<int>> frames;
  final void Function(http.BaseRequest) onSend;
  @override Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend(request);return http.StreamedResponse(frames.stream,200);
  }
  @override void close(){if(!frames.isClosed)unawaited(frames.close());}
}

// SSE is UTF-8 on the wire; http.Response otherwise defaults to Latin-1.
http.Response _response(String body,int status) => http.Response(body,status,
  encoding:utf8,headers:const {'content-type':'text/event-stream; charset=utf-8'});

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  late ModelDialogueRepository repository;
  final controllers=<ModelDialogueController>[];
  final gateways=<ModelDialogueGateway>[];
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);repository=ModelDialogueRepository(db);});
  tearDown(() async {for(final c in controllers)c.dispose();controllers.clear();
    for(final g in gateways)g.close();gateways.clear();await db.closeForTesting();});
  Future<ModelDialogueRoom> create({String first='deepseek',String topic=''}) => repository.create(
    title:'试聊',topic:topic,participants:configuration.snapshot,firstSpeaker:first);
  ModelDialogueGateway gateway(Future<http.Response> Function(http.Request) handler) {
    final result=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>MockClient(handler)),retryDelay:Duration.zero);
    gateways.add(result);return result;
  }
  Future<ModelDialogueController> controller(ModelDialogueRoom room,ModelDialogueGateway g,
      {ModelDialogueRepository? store,Future<ModelDialogueConfiguration> Function()? loader}) async {
    final c=ModelDialogueController(roomId:room.id,repository:store??repository,
      configurationLoader:loader??() async=>configuration,gateway:g);
    controllers.add(c);await c.initialize();return c;
  }
  Future<Map<String,String>> publicState() async {
    final sql=await db.database;final result=<String,String>{};
    for(final table in ['messages','memory_items','thoughts','relationship_events','post_turn_jobs',
      'personality_learning_candidates','desire_state','somatic_events','immersive_rooms','immersive_messages']) {
      result[table]=jsonEncode(await sql.query(table));
    }
    for(final key in ['playful_form_state_v1','playful_heat_trace_v1','personality_base_key']) {
      result[key]=await db.getSetting(key)??'';
    }
    return result;
  }

  test('one click calls one distinct model; user and peers retain their source roles',() async {
    final room=await create(topic:'聊聊有意思的问题');final requests=<http.Request>[];
    final c=await controller(room,gateway((r) async {requests.add(r);return _response(frame('回应${requests.length}'),200);}));
    expect(requests,isEmpty);
    await c.advance();expect(requests,hasLength(1));
    expect(c.messages.single.speaker,'deepseek');expect(c.room!.nextSpeaker,'gemini');
    await c.advance(userText:'我也来插一句。');
    expect(c.messages.map((m)=>m.speaker),['deepseek','user','gemini']);
    final sent=jsonDecode(requests.last.body) as Map;
    expect(sent['model'],'gemini-test');
    final prompt=jsonEncode(sent['messages']);expect(prompt,contains('【真实用户发言】'));
    expect(prompt,contains('【DeepSeek发言】'));expect(prompt,contains('我也来插一句'));
    expect((jsonDecode(requests.first.body) as Map)['model'],'deepseek-test');
    expect(c.room!.nextSpeaker,'deepseek');
    expect(jsonEncode(c.room!.data),isNot(contains('test-only')));
  });

  for(final speaker in modelDialogueSpeakers) {
    test('$speaker retries the same model twice and never invokes the other endpoint',() async {
      final room=await create(first:speaker);final requests=<http.Request>[];
      final c=await controller(room,gateway((r) async {requests.add(r);return _response('private-server-error',503);}));
      await c.advance(userText:'请谈一谈。');
      expect(requests,hasLength(2));
      for(final request in requests) {
        expect(request.url.toString(),configuration.forSpeaker(speaker).endpoint);
        expect((jsonDecode(request.body) as Map)['model'],configuration.forSpeaker(speaker).model);
        expect(request.headers['Authorization'],'Bearer ${configuration.forSpeaker(speaker).apiKey}');
      }
      expect(requests[0].body,requests[1].body);
      expect(c.error,contains('两次请求均失败'));expect(c.error,isNot(contains('private-server-error')));
      expect(c.messages,hasLength(1));expect(c.messages.single.speaker,'user');
      expect(c.room!.nextSpeaker,speaker);expect(c.room!.requestId,isEmpty);
      expect(c.room!.ended,isFalse);
    });
    test('$speaker successful retry commits only one reply without duplicating user text',() async {
      var calls=0;
      final c=await controller(await create(first:speaker),gateway((r) async {
        calls++;return calls==1?_response('error',400):_response(frame('重试后的真实回复'),200);
      }));
      expect(await c.advance(userText:'讨论这个吧。'),isTrue);
      expect(calls,2);expect(c.error,isEmpty);
      expect(c.messages.map((m)=>m.speaker),['user',speaker]);
      expect(c.messages.last.text,'重试后的真实回复');
    });
  }

  test('separate manual retry resumes the failed participant and does not reinsert the user',() async {
    var healthy=false;
    final c=await controller(await create(first:'gemini'),gateway((_) async =>
      healthy?_response(frame('恢复后回应'),200):_response('failed',500)));
    await c.advance(userText:'这条只说一次。');healthy=true;await c.advance();
    expect(c.messages.map((m)=>m.speaker),['user','gemini']);
    expect(c.room!.nextSpeaker,'deepseek');expect(c.error,isEmpty);
  });

  test('same-family configuration is rejected rather than labelled as Gemini',() async {
    final bad=ModelDialogueConfiguration(configuration.deepSeek,
      ModelDialogueEndpoint(speaker:'gemini',endpoint:'https://gm.example/chat',model:'deepseek-test',apiKey:'test'));
    expect(bad.validate,throwsA(isA<ModelDialogueConfigurationError>()));
  });
  test('changing model settings cannot silently replace a room participant',() async {
    var calls=0;final room=await create();
    final changed=ModelDialogueConfiguration(const ModelDialogueEndpoint(speaker:'deepseek',
      endpoint:'https://ds.example/chat/completions',model:'deepseek-different',apiKey:'test'),configuration.gemini);
    final c=await controller(room,gateway((r) async {calls++;return _response(frame('不应调用'),200);}),loader:() async=>changed);
    await c.advance();expect(calls,0);expect(c.error,contains('配置已变化'));
    expect(c.messages,isEmpty);
  });

  test('trial leaves ordinary chat, memory, desires, relationship and form state byte-identical',() async {
    final sql=await db.database;
    await sql.insert('memory_items',{'id':'private-memory','kind':'ai_self','content':'PRIVATE_MEMORY_MUST_NOT_ENTER',
      'created_at':1,'updated_at':1,'importance':.9});
    await sql.insert('messages',{'id':'private-chat','role':'user','content':'PRIVATE_CHAT_MUST_NOT_ENTER','created_at':1});
    await db.setSetting('playful_form_state_v1','{"heat":71,"qForm":false}');
    final before=await publicState();
    final requests=<http.Request>[];
    final c=await controller(await create(topic:'只聊本场'),gateway((r) async {
      requests.add(r);return _response(frame('本场的一个想法'),200);
    }));
    await c.advance(userText:'我加入讨论。');await c.advance();await c.end();
    expect(await publicState(),before);
    for(final r in requests) {
      expect(r.body,isNot(contains('PRIVATE_MEMORY_MUST_NOT_ENTER')));
      expect(r.body,isNot(contains('PRIVATE_CHAT_MUST_NOT_ENTER')));
      expect(r.body,isNot(contains('71')));
    }
  });

  test('close allows only one peer closing turn; end needs no artificial goodbye',() async {
    var calls=0;final c=await controller(await create(),gateway((_) async {
      calls++;return _response(frame(calls==1?'今天先聊到这儿。':'嗯，回头再聊。',action:calls==1?'close':'continue'),200);
    }));
    await c.advance();expect(c.room!.ended,isFalse);expect(c.room!.closingSpeaker,'deepseek');
    await c.advance();expect(c.room!.ended,isTrue);await c.advance();expect(calls,2);
    final end=await controller(await create(),gateway((_) async=>_response(frame('',action:'end'),200)));
    await end.advance();expect(end.room!.ended,isTrue);expect(end.messages,isEmpty);
  });
  test('human interjection can open a new thread before the final closing turn',() async {
    var calls=0;final c=await controller(await create(),gateway((_) async {
      calls++;return _response(frame('发言$calls',action:calls==1?'close':'continue'),200);
    }));
    await c.advance();await c.advance(userText:'等一下，我想再问一个问题。');
    expect(c.room!.ended,isFalse);expect(c.room!.closingSpeaker,isEmpty);
    expect(c.messages.map((m)=>m.speaker),['deepseek','user','gemini']);
  });
  test('an addressed user turn routes to the named participant without a planner call',() async {
    final c=await controller(await create(),gateway((_) async=>_response(frame('回答'),200)));
    await c.advance(userText:'Gemini，你怎么看？');expect(c.messages.last.speaker,'gemini');
    expect(c.room!.nextSpeaker,'deepseek');
  });

  for(final failure in ['missing_terminal','length','invalid_json']) {
    test('$failure never advances or saves a partial reply',() async {
      var calls=0;final c=await controller(await create(),gateway((_) async {
        calls++;
        final data=failure=='invalid_json'?'data: ${jsonEncode({'choices':[{'delta':{'content':'不是JSON'},'finish_reason':'stop'}]})}\n\n':
          failure=='missing_terminal'?'data: ${jsonEncode({'choices':[{'delta':{'content':jsonEncode({'text':'未完成','action':'continue'})}}]})}\n\n':
          frame('截断片段',finish:'length');
        return _response(data,200);
      }));
      await c.advance();expect(calls,2);expect(c.messages,isEmpty);
      expect(c.room!.nextSpeaker,'deepseek');expect(c.error,isNotEmpty);expect(c.preview,isEmpty);
    });
  }
  test('an explicit stop finish is a valid terminal signal even without a DONE frame',() async {
    final c=await controller(await create(),gateway((_) async=>_response(frame('完整回应',done:false),200)));
    await c.advance();expect(c.error,isEmpty);expect(c.messages.single.text,'完整回应');
  });

  test('pause aborts the stream, discards its draft and leaves the next speaker unchanged',() async {
    final frames=StreamController<List<int>>();final sent=Completer<void>();
    var calls=0;
    final g=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>_StreamClient(frames,(_){calls++;sent.complete();})),retryDelay:Duration.zero);
    gateways.add(g);final c=await controller(await create(),g);
    final pending=c.advance(userText:'我说的话保留。');await sent.future.timeout(const Duration(seconds:5));
    frames.add(utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'content':'{"text":"半条回复'}}]})}\n\n'));
    await c.pause();await pending.timeout(const Duration(seconds:5));
    expect(calls,1);expect(c.messages.map((m)=>m.speaker),['user']);
    expect(c.room!.nextSpeaker,'deepseek');expect(c.preview,isEmpty);expect(c.room!.requestId,isEmpty);
  });
  test('stopping during configuration loading does not submit a request or a user turn',() async {
    final gate=Completer<ModelDialogueConfiguration>();var calls=0;
    final c=await controller(await create(),gateway((_) async {calls++;return _response(frame('不应发生'),200);}),loader:()=>gate.future);
    final pending=c.advance(userText:'还没提交');await c.pause();gate.complete(configuration);
    expect(await pending,isFalse);expect(calls,0);expect(c.messages,isEmpty);
  });

  test('cancel at the final SQLite boundary cannot commit an already generated reply',() async {
    final entered=Completer<void>(),release=Completer<void>();
    final store=ModelDialogueRepository(db,beforeCommit:() async {entered.complete();await release.future;});
    final c=await controller(await create(),gateway((_) async=>_response(frame('已经生成但不该落库'),200)),store:store);
    final pending=c.advance();await entered.future.timeout(const Duration(seconds:5));
    final stopped=c.pause();release.complete();await Future.wait<void>([pending.then((_) {}),stopped]);
    expect(c.messages,isEmpty);expect(c.room!.requestId,isEmpty);
  });
  test('double-click during a pending turn cannot create two HTTP requests',() async {
    final frames=StreamController<List<int>>();final sent=Completer<void>();var calls=0;
    final g=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>_StreamClient(frames,(_){calls++;sent.complete();})),retryDelay:Duration.zero);
    gateways.add(g);final c=await controller(await create(),g);
    final pending=c.advance();await sent.future;expect(await c.advance(),isFalse);
    frames.add(utf8.encode(frame('只有一条')));await frames.close();await pending;
    expect(calls,1);expect(c.messages,hasLength(1));
  });

  Future<ModelDialogueTicket> ticket(ModelDialogueRoom room) async {
    expect(await db.tryAcquireLocalLease('chat_turn_lease'),isTrue);
    final fence=(await db.captureBrainWorkFence(leaseKey:'chat_turn_lease'))!;
    return repository.begin(roomId:room.id,fence:fence);
  }
  for(final change in ['delete','end','transfer','restore']) {
    test('$change revokes an in-flight reply at the real repository commit boundary',() async {
      final room=await create();final captured=await ticket(room);
      if(change=='delete')await repository.delete(room.id);
      if(change=='end')await repository.end(room.id);
      if(change=='transfer')await db.setSetting('transfer_lock','1');
      if(change=='restore') {
        final archive=Map<String,dynamic>.from(await db.exportAll());await db.importAll(archive);
      }
      expect(await repository.commit(captured,const ModelDialogueOutput('迟到结果','continue'),GenerationCancellationToken()),isFalse);
      expect(await repository.messagesForRoom(room.id),isEmpty);
      if(change=='delete'){expect(await repository.roomById(room.id),isNull);expect(await repository.listRooms(),isEmpty);}
      if(change=='restore')expect(await repository.cancelTicket(captured),isFalse);
      if(change=='transfer')await db.setSetting('transfer_lock','0');
      await db.releaseLocalLease('chat_turn_lease');
    });
  }
  test('backup round-trip preserves private trial rooms without adding public memories',() async {
    final c=await controller(await create(),gateway((_) async=>_response(frame('仅本场记录'),200)));
    await c.advance(userText:'一次参与');final before=c.messages.map((m)=>m.toJson()).toList();
    final public=await publicState();final archive=Map<String,dynamic>.from(await db.exportAll());
    await db.importAll(archive);
    expect((await repository.messagesForRoom(c.roomId)).map((m)=>m.toJson()).toList(),before);
    final restoredPublic=await publicState();
    for(final table in ['messages','memory_items','thoughts','relationship_events']) {expect(restoredPublic[table],public[table]);}
    final reopened=await controller((await repository.roomById(c.roomId))!,gateway((_) async=>_response(frame('续聊'),200)));
    expect(reopened.messages,hasLength(2));expect(reopened.room!.requestId,isEmpty);
    await reopened.advance();expect(reopened.messages.last.speaker,'gemini');
  });
  test('orphaned generation is paused on reopen and never automatically requested again',() async {
    final room=await create();await ticket(room);await db.releaseLocalLease('chat_turn_lease');
    var calls=0;final c=await controller(room,gateway((_) async {calls++;return _response(frame('以后再说'),200);}));
    expect(c.room!.requestId,isEmpty);expect(c.room!.status,'paused');expect(calls,0);
  });

  test('JSON preview never reveals routing fields or broken Unicode escapes',(){
    const text='你好\n"小鲸鱼" 🐳';final raw=jsonEncode({'text':text,'action':'close'});
    expect(ModelDialogueOutput.preview(raw),text);expect(ModelDialogueOutput.parse(raw).action,'close');
    expect(ModelDialogueOutput.preview(r'{"text":"\u4f60\u597d\ud83d'), '你好');
    expect(ModelDialogueOutput.preview(r'{"text":"\ud83d\udc33","action":"end"}'),'🐳');
    expect(ModelDialogueOutput.preview('{"action":"continue","text":"藏起来"}'),isEmpty);
  });
  test('prompt uses only this room and preserves same-speaker output format',(){
    final room=ModelDialogueRoom({'id':'r','title':'试聊','topic':'自由话题','next_speaker':'gemini','participants':configuration.snapshot});
    final result=ModelDialoguePrompt.build(room,[const ModelDialogueMessage(id:'m',roomId:'r',sequence:1,
      speaker:'gemini',text:'我刚才提出的观点',model:'gemini-test',createdAt:1)],'gemini');
    expect(result.where((m)=>m['role']=='assistant').single['content'],contains('"text"'));
    expect(jsonEncode(result),contains('共同的轻量角色背景')); // participant identity is explicit in the prompt.
  });
}
