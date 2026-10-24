import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';
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
http.Response _reply(String text)=>http.Response.bytes(utf8.encode(
  'data: ${jsonEncode({'choices':[{'delta':{'content':text},'finish_reason':'stop'}]})}\n\ndata: [DONE]\n\n'),
  200,headers:{'content-type':'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  test('production transport retains empty and exact reasoning during a thinking tool continuation',()async {
    final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async {
      final body=jsonDecode(request.body) as Map;
      final assistant=(body['messages'] as List).where((m)=>m['role']=='assistant').toList();
      expect(assistant[0]['reasoning_content'],'');
      expect(assistant[1]['reasoning_content'],'  exact\n');
      return _reply('ok');
    }));
    try {
      await client.streamChat(apiKey:'fixture',model:DeepSeekModelProfile.flash,effort:ReasoningEffort.high,
        messages:[{'role':'user','content':'问题'},{'role':'assistant','content':null,
          'tool_calls':[{'id':'c','type':'function','function':{'name':'fixture','arguments':'{}'}}]},
          {'role':'tool','tool_call_id':'c','content':'结果'},
          {'role':'assistant','content':'history','reasoning_content':'  exact\n'}],
        tools:[{'type':'function','function':{'name':'fixture','parameters':{'type':'object'}}}]).toList();
    } finally {client.close();}
  });

  for (final status in ['failed', 'retry_wait', 'orphan_running']) {
  test('$status resumes the same turn without waiting for old retry or checkpoint age',()async {
    final directory=await Directory.systemTemp.createTemp('failed-reply374-');
    final paths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(directory.path);
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'fixture',
      'chat_api_provider':'aiwangyou_gemini','aiwangyou_gemini_api_key':'second-fixture'});
    const channel=MethodChannel('ai_companion/system');
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel,(c)async=>c.method=='runtimeProcessEpoch'?'new-process':null);
    var firstCalls=0,secondCalls=0;
    final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async {
      if(request.url.host.contains('aiwangyou'))secondCalls++;else firstCalls++;
      return _reply('<emotion>正常</emotion>\n「接上了。」');
    }),jsonClientFactory:()=>MockClient((_)async=>http.Response(
      jsonEncode({'choices':[{'message':{'content':'{}'}}]}),200)));
    final chat=ChatController(db:db,client:client,
      secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()),externalRecoveryOrchestrator:true);
    try {
      await db.setSettingsAtomically({'tts_enabled':'0','auto_tts':'0','emotion_sound_enabled':'0',
        'cedar_toy_enabled':'0','post_turn_queue_enabled':'0',
        'daily_continuity_enabled':'0','memory_fading_enabled':'0','memory_consolidation_enabled':'0',
        'relationship_continuity_enabled':'0','personality_learning_enabled':'0'});
      final pending=await db.createGenerationTurn(user:ChatMessage(id:'u',role:'user',
        content:'继续说吧',createdAt:DateTime.now()),assistantMessageId:'a',
        model:'deepseek-flash',reasoningEffort:'high');
      final claimed=(await db.claimGenerationJob(pending.id))!;
      if (status != 'orphan_running') {
        await db.failGenerationJob(pending.id,runToken:claimed.runToken,
          error:'API 400: reasoning_content must be passed back',recoverable:status=='retry_wait');
        if (status == 'retry_wait') {
          await (await db.database).update('generation_jobs', {
            'next_retry_at': DateTime.now().add(const Duration(hours:1)).millisecondsSinceEpoch,
          }, where:'id = ?', whereArgs:[pending.id]);
        }
      } else {
        await db.setSetting('chat_turn_lease',
          'old-process:00000000-0000-0000-0000-000000000001|${DateTime.now().add(const Duration(minutes:2)).millisecondsSinceEpoch}');
        expect(await db.nextGenerationRecoveryDelay(), Duration.zero);
        // Keep both paid routes configured while explicitly testing recovery
        // on the first channel to make assertions independent of routing.
        await db.selectDeepSeekForGeneration(pending.id);
      }
      await chat.syncExternalMessages();
      expect(chat.generationActive,status!='failed');expect(chat.failedReplyAvailable,status=='failed');
      expect(chat.showManualReplyControl,true);expect(chat.canUseDeepSeekForCurrentReply,true);
      if (status == 'orphan_running') {
        await chat.resumePendingGeneration().timeout(const Duration(seconds:30));
      } else {
        await chat.useDeepSeekForCurrentReply(expectedReplyIdentity:chat.manualReplyIdentity)
          .timeout(const Duration(seconds:30));
      }
      expect(await db.isGenerationRunCurrent(pending.id,runToken:claimed.runToken),false);
      expect((await db.generationJobById(pending.id))!.status,'completed');
      expect((await db.messageById('a'))!.content,contains('接上了'));
      expect(firstCalls,greaterThan(0));expect(secondCalls,0);
      expect((await (await db.database).query('generation_jobs')).length,1);
    } finally {
      chat.dispose();client.close();await db.closeForTesting();
      messenger.setMockMethodCallHandler(channel,null);PathProviderPlatform.instance=paths;
      await directory.delete(recursive:true);
    }
  });
  }
}
