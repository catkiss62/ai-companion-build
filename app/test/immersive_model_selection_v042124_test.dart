import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_model_selection.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  final secure = SecureConfig.forTesting(const FlutterSecureStorage());
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSettingsAtomically({'deepseek_model':'first-configured','model':'legacy-model',
      'tts_enabled':'0','auto_tts':'0'});
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'first-key',
      'deepseek_chat_endpoint':'https://first.example/v1/chat/completions',
      'chat_api_provider':'aiwangyou_gemini'});
  });
  tearDown(() async => db.closeForTesting());

  test('only genuinely configured choices appear; initial room model is first', () async {
    final choices = await ImmersiveModelSelection.options(db, secureConfig:secure);
    expect(choices.map((c)=>c.source), [ImmersiveModelSource.first]);
    expect((await ImmersiveModelSelection.resolve(db, secureConfig:secure)).model,'first-configured');
    // Neither the relay getter default nor the work UI placeholder is a saved choice.
    expect(await secure.readAiWangYouModel(),isNotEmpty);
  });
  test('same model names retain distinct sources and work effort', () async {
    await db.setSettingsAtomically({'creative_work_model':'first-configured','creative_work_effort':'max'});
    final choices = await ImmersiveModelSelection.options(db,secureConfig:secure);
    expect(choices.map((c)=>c.source),[ImmersiveModelSource.first,ImmersiveModelSource.work]);
    expect(choices.last.effort.apiName,'max');
    expect(choices.last.apiKey,'first-key');
  });
  test('removed selected configuration requires a new selection', () async {
    await db.setSetting(ImmersiveModelSelection.settingKey,'work');
    await expectLater(ImmersiveModelSelection.resolve(db,secureConfig:secure),throwsFormatException);
    expect(await db.getSetting(ImmersiveModelSelection.settingKey),'work');
  });

  test('selected relay failure records the actual first-channel fallback', () async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'first-key',
      'deepseek_chat_endpoint':'https://first.example/v1/chat/completions',
      'aiwangyou_gemini_api_key':'second-key',
      'aiwangyou_final_reply_endpoint':'https://second.example/v1/chat/completions',
      'aiwangyou_final_reply_model':'[A]glm-test'});
    await db.setSetting(ImmersiveModelSelection.settingKey,'second');
    final repository = ImmersiveRoomRepository(db);
    final room = await repository.createRoom(title:'回退',openingScene:'',inheritCurrentChat:false);
    await repository.setNsfwManualOverride(room.id,false);
    final models = <String>[];
    final client = DeepSeekClient(streamClientFactory:()=>MockClient((request) async {
      final model = (jsonDecode(request.body) as Map)['model'] as String;models.add(model);
      if(request.url.host=='second.example') return http.Response('bad configuration',400);
      return http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'content':'她继续看着海面。'},'finish_reason':'stop'}]})}\n\ndata: [DONE]\n\n'),200,
        headers:const {'content-type':'text/event-stream; charset=utf-8'});
    }));
    final controller = ImmersiveRoomController(roomId:room.id,db:db,secureConfig:secure,client:client);
    try {
      await controller.initialize();await controller.send('继续。');
      expect(controller.error,isNull);expect(models,['[A]glm-test','first-configured']);
      final assistant = (await repository.messagesForRoom(room.id)).singleWhere((m)=>m.isAssistant);
      final recorded=jsonDecode((await db.getSetting('immersive_message_model_v1:${room.id}:${assistant.id}'))!) as Map;
      expect(recorded['model'],'first-configured');expect(recorded['reason'],'second_channel_failure');
      expect(await db.getSetting(ImmersiveModelSelection.settingKey),'second');
    } finally {controller.dispose();client.close();}
  });

  for (final source in ImmersiveModelSource.values) {
    test('normal and regenerated HTTP bodies use selected ${source.key} config', () async {
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'first-key',
        'deepseek_chat_endpoint':'https://first.example/v1/chat/completions',
        'aiwangyou_gemini_api_key':'second-key',
        'aiwangyou_final_reply_endpoint':'https://second.example/v1/chat/completions',
        'aiwangyou_final_reply_model':'[A]glm-5.3-flash-1',
        // An immersive selection works independently of the ordinary-chat switch.
        'chat_api_provider':'deepseek'});
      await db.setSettingsAtomically({ImmersiveModelSelection.settingKey:source.key,
        'creative_work_model':'work-configured','creative_work_effort':'max'});
      final repository = ImmersiveRoomRepository(db);
      final room = await repository.createRoom(title:'模型选择',openingScene:'海边',inheritCurrentChat:false);
      await repository.setNsfwManualOverride(room.id,false);
      final expected = source == ImmersiveModelSource.first ? 'first-configured'
          : source == ImmersiveModelSource.second ? '[A]glm-5.3-flash-1' : 'work-configured';
      final requests = <Map>[];
      final internalRequests = <Map>[];
      var truncate = true;
      final client = DeepSeekClient(streamClientFactory:()=>MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        // Regeneration can run the existing short first-channel route check.
        // Verify it separately from the selected final prose request.
        if (body['max_tokens'] == 120) {
          internalRequests.add({'model':body['model'],'host':request.url.host,
            'authorization':request.headers['authorization']});
          return http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'content':jsonEncode({'mode':'daily','climax_event':'none'})},'finish_reason':'stop'}]})}\n\ndata: [DONE]\n\n'),200,
            headers:const {'content-type':'text/event-stream; charset=utf-8'});
        }
        requests.add(body);
        expect(body['model'],expected);
        expect(request.url.host,source == ImmersiveModelSource.second ? 'second.example':'first.example');
        expect(request.headers['authorization'],source == ImmersiveModelSource.second ? 'Bearer second-key':'Bearer first-key');
        final finish = truncate ? 'length':'stop';
        if (source == ImmersiveModelSource.work) expect(body['reasoning_effort'],'max');
        return http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'content':'她望着海面，轻轻点头。'},'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),200,
          headers:const {'content-type':'text/event-stream; charset=utf-8'});
      }));
      final controller = ImmersiveRoomController(roomId:room.id,db:db,secureConfig:secure,client:client);
      try {
        await controller.initialize();
        // First two non-relay requests can include the existing continuation.
        // Explicitly truncated relay uses the durable draft/regenerate path.
        if (source != ImmersiveModelSource.second) truncate = false;
        await controller.send('看看眼前的海。');
        if (source == ImmersiveModelSource.second) {
          expect(controller.incompleteReplyDraft,isNotNull);
          truncate = false;
          await controller.regenerateIncompleteReply();
          expect(controller.incompleteReplyDraft,isNull);
          expect(requests,hasLength(2));
        } else {
          expect(requests,hasLength(1));
        }
        expect(controller.error,isNull);
        for(final internal in internalRequests) {
          expect(internal,{'model':'first-configured','host':'first.example',
            'authorization':'Bearer first-key'});
        }
        expect((await repository.messagesForRoom(room.id)).where((m)=>m.isAssistant),hasLength(1));
        expect(await secure.readChatProvider(),isNotNull);
        expect(await db.getSetting('deepseek_model'),'first-configured');
        final assistant = (await repository.messagesForRoom(room.id)).singleWhere((m)=>m.isAssistant);
        final modelKey = 'immersive_message_model_v1:${room.id}:${assistant.id}';
        final recorded = jsonDecode((await db.getSetting(modelKey))!) as Map;
        expect(recorded['model'], expected); expect(recorded['source'], source.key);
        expect(jsonEncode(recorded), isNot(contains('first-key')));
        await repository.deleteRoom(room.id);
        expect(await db.getSetting(modelKey), isNull);
      } finally { controller.dispose(); client.close(); }
    });
  }
}
