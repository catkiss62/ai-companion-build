import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_route.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_config.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/settings/model_network_config_transfer.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  setUp(()=>FlutterSecureStorage.setMockInitialValues({}));
  test('old third profiles retain high, each supported choice round trips',() {
    expect(ThirdChannelConfig.decode('{"enabled":false}').reasoningEffort,'high');
    for(final effort in ['low','medium','high'])expect(ThirdChannelConfig.decode(ThirdChannelConfig(effort:effort).encode()).reasoningEffort,effort);
  });
  for(final effort in ['low','medium','high'])for(final stream in [true,false]) {
    test('$effort is sent for ${stream?'body':'structured vision'} with a stable retry profile',()async {
      final sent=<Map>[];
      final client=ThirdChannelClient(retryDelay:Duration.zero,clientFactory:()=>MockClient((r)async {
        if(r.url.path=='/health')return http.Response('{"status":"ok"}',200);
        final body=jsonDecode(r.body) as Map;sent.add(body);
        const usage={'prompt_tokens':3,'completion_tokens':2,'completion_tokens_details':{'reasoning_tokens':4}};
        final content=stream?'正常回答':'{"summary":"实际图片"}';
        if(stream)return http.Response('data:${jsonEncode({'choices':[{'delta':{'content':content},'finish_reason':'stop'}],'usage':usage})}\n\ndata:[DONE]\n\n',200,headers:{'content-type':'text/event-stream; charset=utf-8'});
        return http.Response(jsonEncode({'choices':[{'message':{'content':content},'finish_reason':'stop'}],'usage':usage}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }));
      try {final result=await client.complete(config:ThirdChannelConfig(baseUrl:'http://fixture.invalid/v1',apiKey:'fixture',effort:effort),
        messages:[],stream:stream,responseFormat:stream?null:{'type':'json_object'});
        expect(result.content,contains(stream?'正常回答':'summary'));expect(sent.single['reasoning_effort'],effort);
      } finally {client.close();}
    });
  }
  test('App and QQ third body ignore the independent base-provider effort',()async {
    final secure=SecureConfig.forTesting(const FlutterSecureStorage());
    await secure.writeThirdChannel(const ThirdChannelConfig(enabled:true,baseUrl:'http://fixture.invalid/v1',apiKey:'fixture',effort:'medium'));
    final efforts=<String>[];
    ThirdChannelClient third()=>ThirdChannelClient(clientFactory:()=>MockClient((r)async {
      if(r.url.path=='/health')return http.Response('{"status":"ok"}',200);
      efforts.add((jsonDecode(r.body) as Map)['reasoning_effort'] as String);
      return http.Response('data:${jsonEncode({'choices':[{'delta':{'content':'实际第三回答'},'finish_reason':'stop'}],
        'usage':{'prompt_tokens':3,'completion_tokens':2}})}\n\ndata:[DONE]\n\n',200,headers:{'content-type':'text/event-stream; charset=utf-8'});
    }));
    final client=DeepSeekClient(secureConfig:secure,thirdClientFactory:third);
    try {
      await client.streamChat(apiKey:'first',model:DeepSeekModelProfile.flash,effort:ReasoningEffort.max,messages:[],
        finalReplyRoute:FinalReplyRoute(secondChannelEnabled:false)).toList();
      await QqReplyGenerator(client:client,secure:secure,current:()async=>true).generate(channel:'first',firstModel:DeepSeekModelProfile.flash,
        firstEffort:ReasoningEffort.high,secondEffort:ReasoningEffort.low,messages:[]);
      expect(efforts,['medium','medium']);
    }finally{client.close();}
  });
  test('explicit configuration transfer preserves third effort without rewriting first/second effort',()async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi),secure=SecureConfig.forTesting(const FlutterSecureStorage());
    try {
      await db.setSetting('reasoning_effort','low');await db.setSetting('deepseek_reasoning_effort','high');
      await secure.writeThirdChannel(const ThirdChannelConfig(effort:'medium'));
      final decoded=ModelNetworkConfigTransfer.parse(await ModelNetworkConfigTransfer(db,secure).exportSaved());
      expect(ThirdChannelConfig.decode(decoded.secure['third_connection']).reasoningEffort,'medium');
      expect(decoded.settings['reasoning_effort'],'low');expect(decoded.settings['deepseek_reasoning_effort'],'high');
    }finally{await db.closeForTesting();}
  });
}
