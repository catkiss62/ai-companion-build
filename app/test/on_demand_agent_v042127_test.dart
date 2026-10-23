import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/on_demand_agent_entry.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
class _Paths extends PathProviderPlatform {
  _Paths(this.path);final String path;
  @override Future<String?> getApplicationSupportPath()async=>path;
  @override Future<String?> getTemporaryPath()async=>path;
}
http.Response _reply(Map<String,Object?> delta,{String finish='stop'}) => http.Response.bytes(
  utf8.encode('data: ${jsonEncode({'choices':[{'delta':delta,'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),200,
  headers:{'content-type':'text/event-stream; charset=utf-8'});
Map<String,Object?> _call(String name,Map<String,Object?> args)=>{'tool_calls':[{
  'index':0,'id':'call-$name','type':'function','function':{'name':name,'arguments':jsonEncode(args)}}]};
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  test('optional entry validates the request and never exposes write or capture permissions',(){
    final request=OnDemandAgentEntry.parse([DeepSeekToolCall(id:'r',name:'agent_request',
      arguments:jsonEncode({'goal':'查一下实际能力','families':['system','game','device']}))])!;
    final ids=request.toolIds(cedarConfigured:true);
    expect(ids,contains('cedar_toy.list_games'));expect(ids,contains('device_context.read'));
    expect(ids,contains('system_self.read'));expect(ids,isNot(contains('cedar_toy.play')));
    expect(ids,isNot(contains('screen_observation.inspect')));
    expect(request.definitions(ids),isNotEmpty);
    expect(const OnDemandAgentEntry('问题',{'web'}).toolIds(cedarBlindPlay:true),isEmpty);
    expect(OnDemandAgentEntry.parse([const DeepSeekToolCall(id:'r',name:'agent_request',
      arguments:'{"goal":"","families":["system"]}')]),isNull);
  });
  for(final second in [false,true]){
    for(final action in ['direct','choose','cancel']){
      test('real ${second?'second':'first'} channel $action chooses the optional entry without per-turn planning',()async{
        final files=await Directory.systemTemp.createTemp('optional-agent-');
        final previous=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(files.path);
        final db=await AppDatabase.createForTesting(databaseFactoryFfi);
        const channel=MethodChannel('ai_companion/system');
        final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel,(_)async=>null);
        FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'test-first',
          'chat_api_provider':second?'aiwangyou_gemini':'deepseek',
          'aiwangyou_gemini_api_key':'test-second',
          'aiwangyou_final_reply_endpoint':'https://relay.invalid/v1/chat/completions',
          'aiwangyou_final_reply_model':'second-custom'});
        final token=GenerationCancellationToken();var finals=0;var plans=0;
        final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async{
          final body=jsonDecode(request.body) as Map;
          final names=[for(final t in body['tools'] as List? ?? [])((t as Map)['function'] as Map)['name']];
          if(names.contains('system_self_read')){
            plans++;expect(request.url.host,isNot('relay.invalid'));
            if(action=='cancel')token.cancel();
            if(plans==1)return _reply(_call('system_self_read',{'scope':'facts'}),finish:'tool_calls');
            return _reply({'content':'已经足够。'});
          }
          if(body.containsKey('max_tokens'))return _reply({'content':'{}'});
          finals++;expect(request.url.host=='relay.invalid',second);
          if(finals==1){
            expect(names,['agent_request']);
            if(action!='direct')return _reply(_call('agent_request',
              {'goal':'我想核实一下自己有哪些实际能力','families':['system']}),finish:'tool_calls');
          }else{
            expect(names,everyElement('agent_request'));expect(jsonEncode(body['messages']),contains('system_self.read'));
            expect(jsonEncode(body['messages']),contains('outcomes'));
          }
          return _reply({'content':'「嗯，我知道了。」'});
        }),jsonClientFactory:()=>MockClient((_)async=>http.Response(
          jsonEncode({'choices':[{'message':{'content':'{}'},'finish_reason':'stop'}]}),200)));
        try{
          await db.tryAcquireLocalLease('chat_turn_lease');
          final job=await db.createGenerationTurn(user:ChatMessage(id:'u',role:'user',content:'今天就随便聊聊吧',createdAt:DateTime.now()),
            assistantMessageId:'a',model:'first-configured',reasoningEffort:'high');
          final source=(await ConversationSourceStore.captureMessage(await db.database,'u'))!;
          final key='${source.contentHash}:${source.revision}';
          await db.setSetting('nsfw_route_turn_id','u');await db.setSetting('nsfw_route_source_key_v2',key);
          await db.setSetting('route_tool_intent_v1',jsonEncode({'turn_id':'u','source_key':key,
            'route':const SemanticToolRoute(available:true).toJson()}));
          await db.setSetting('route_task_intent_v1',jsonEncode({'turn_id':'u','source_key':key,
            'intent':const TurnTaskIntent(available:true).toJson()}));
          final result=await DurableGenerationRunner(db:db,client:client,
            secureConfig:SecureConfig.forTesting(const FlutterSecureStorage())).run(job,cancellationToken:token)
            .timeout(const Duration(seconds:25));
          if(action=='cancel'){
            expect(result.status,'cancelled_by_user');expect(await db.messageById('a'),isNull);
          }else{
            expect(result.status,'completed',reason:result.error?.toString());
            expect(finals,action=='direct'?1:2);expect(plans,action=='direct'?0:2);
            final records=await db.recentAgentToolOutcomeRecords(limit:10);
            expect(records.where((r)=>r.toolId=='system_self.read'),hasLength(action=='direct'?0:1));
            expect((await db.messageById('a'))!.content,isNot(contains('agent_request')));
          }
        }finally{
          token.cancel();client.close();await db.releaseLocalLease('chat_turn_lease');await db.closeForTesting();
          messenger.setMockMethodCallHandler(channel,null);PathProviderPlatform.instance=previous;
          await files.delete(recursive:true);
        }
      });
    }
  }
}
