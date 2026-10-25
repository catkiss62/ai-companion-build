import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_private_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_generator.dart';

class _Config extends SecureConfig {
  _Config():super.forTesting(const FlutterSecureStorage());
  @override Future<String?> readApiKey()async=>'first-key';
  @override Future<String> readEndpoint()async=>'https://first.test/chat';
  @override Future<String?> readAiWangYouApiKey()async=>'second-key';
  @override Future<String> readAiWangYouEndpoint()async=>'https://second.test/chat';
  @override Future<String> readAiWangYouModel()async=>'configurable-second-model';
  @override Future<ChatApiProvider> readChatProvider()async=>ChatApiProvider.aiWangYouGemini;
}
http.Response sse(String text,{String finish='stop'})=>http.Response.bytes(utf8.encode(
  'data: ${jsonEncode({'choices':[{'delta':{'content':text},'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),200,
  headers:{'content-type':'text/event-stream; charset=utf-8'});

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  for(final scenario in ['first','second_success','second_retry','second_fallback','partial_fallback','stopped','all_failed']){
    test('QQ production reply generator: $scenario',()async{
      final requests=<http.Request>[];var current=true,secondaryCalls=0;
      final statuses=<String>[];
      final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async{
        requests.add(request);
        final body=jsonDecode(request.body) as Map;
        if(request.url.host=='second.test'){
          secondaryCalls++;
          expect(body['model'],'configurable-second-model');
          expect(request.headers['Authorization'],'Bearer second-key');
          if(scenario=='second_success'||scenario=='second_retry'&&secondaryCalls==2)return sse('第二通道完整回复');
          if(scenario=='stopped')current=false;
          if(scenario=='partial_fallback')return sse('不该送出的半句',finish:'length');
          return http.Response('upstream failure',503);
        }
        expect(request.url.host,'first.test');
        expect(body['model'],'configured-deepseek-next');
        expect(request.headers['Authorization'],'Bearer first-key');
        if(scenario=='all_failed')return http.Response('first unavailable',503);
        return sse('DeepSeek完整回复');
      }));
      try{
        final generator=QqReplyGenerator(client:client,secure:_Config(),current:()async=>current,onStatus:statuses.add);
        final future=generator.generate(channel:scenario=='first'?'first':'second',
          firstModel:DeepSeekModelProfile.fromApiName('configured-deepseek-next'),
          firstEffort:ReasoningEffort.high,secondEffort:ReasoningEffort.low,
          messages:const[{'role':'user','content':'你好'}]);
        if(scenario=='stopped'||scenario=='all_failed'){
          await expectLater(future,throwsA(anything));
          expect(requests.where((r)=>r.url.host=='first.test').length,scenario=='stopped'?0:1);
        }else{
          final output=await future;
          expect(output,scenario=='second_success'||scenario=='second_retry'?'第二通道完整回复':'DeepSeek完整回复');
          expect(output,isNot(contains('半句')));
          expect(secondaryCalls,scenario=='first'?0:scenario=='second_success'?1:2);
          expect(requests.where((r)=>r.url.host=='first.test').length,
            scenario=='second_success'||scenario=='second_retry'?0:1);
        }
      }finally{client.close();}
    });
  }
  test('QQ bounds a continuously progressing unfinished second reply before fallback',()async{
    var secondaryCalls=0;
    final client=DeepSeekClient(streamClientFactory:()=>MockClient.streaming((request,body)async{
      if(request.url.host=='second.test'){
        secondaryCalls++;
        // Real parsed model progress arrives frequently: an idle timeout
        // alone would never finish this attempt.
        return http.StreamedResponse(Stream<List<int>>.periodic(const Duration(milliseconds:10),(_)=>
          utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'reasoning_content':'继续思考'}}]})}\n\n')),200);
      }
      return http.StreamedResponse(Stream.value(sse('限时后完整兜底').bodyBytes),200);
    }));
    try{
      final output=await QqReplyGenerator(client:client,secure:_Config(),current:()async=>true,
        secondTimeout:const Duration(milliseconds:200),firstTimeout:const Duration(seconds:2))
        .generate(channel:'second',firstModel:DeepSeekModelProfile.flash,
          firstEffort:ReasoningEffort.high,secondEffort:ReasoningEffort.high,
          messages:const[{'role':'user','content':'你好'}]);
      expect(secondaryCalls,2);expect(output,'限时后完整兜底');
    }finally{client.close();}
  });
  test('QQ channel persists independently and does not change App reply provider',()async{
    FlutterSecureStorage.setMockInitialValues({'chat_api_provider':'aiwangyou_gemini'});
    final config=const QqPrivateConfig(appId:'123',secret:'device-only',namespace:'binding',replyChannel:'first');
    await config.save();
    expect((await QqPrivateConfig.read()).replyChannel,'first');
    expect(await SecureConfig.instance.readChatProvider(),ChatApiProvider.aiWangYouGemini);
    await config.withReplyChannel('second').save();
    expect((await QqPrivateConfig.read()).replyChannel,'second');
    expect(await SecureConfig.instance.readChatProvider(),ChatApiProvider.aiWangYouGemini);
  });
}
