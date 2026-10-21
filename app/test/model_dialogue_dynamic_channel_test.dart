import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_archive_worker.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_controller.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_gateway.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ModelDialogueConfiguration _configuration(String model) => ModelDialogueConfiguration(
  const ModelDialogueEndpoint(speaker:'deepseek',endpoint:'https://first.example/v1/chat/completions',
    model:'deepseek-configured',apiKey:'first-test-key'),
  ModelDialogueEndpoint(speaker:'gemini',endpoint:'https://second.example/v1/chat/completions',
    model:model,apiKey:'second-test-key'));

http.Response _reply(String text) => http.Response.bytes(utf8.encode(
  'data: ${jsonEncode({'choices':[{'delta':{'content':jsonEncode({'text':text,'action':'continue'})},'finish_reason':'stop'}]})}\n\n'
  'data: [DONE]\n\n'),200,headers:const {'content-type':'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  late ModelDialogueRepository repository;
  final controllers=<ModelDialogueController>[];
  setUp(() async {
    db=await AppDatabase.createForTesting(databaseFactoryFfi);
    repository=ModelDialogueRepository(db);
  });
  tearDown(() async {
    for(final c in controllers)c.dispose();controllers.clear();
    await db.closeForTesting();
  });

  test('relay-decorated families are labels; unknown models remain usable',() {
    for(final entry in const {
      '[A]glm-5.3-flash-1':'GLM','[group]GLM5.3':'GLM',
      '[Gemini线路][A]glm-5.3-flash-1':'GLM',
      '[A]gemini-test-fast':'Gemini','vendor/claude-test-latest':'Claude',
      '[relay]gpt-test':'GPT','qwen3-test':'Qwen','moonshot-test':'Kimi',
      'route/grok-test':'Grok','miniMax-test':'MiniMax','deepseek-test':'DeepSeek',
      'custom-model-17':'custom-model-17','notglm-test':'notglm-test',
    }.entries) {
      final config=_configuration(entry.key);
      expect(config.validate,returnsNormally,reason:entry.key);
      expect(config.gemini.label,entry.value,reason:entry.key);
      expect(config.gemini.model,entry.key);
    }
    expect(_configuration(' ').validate,throwsA(isA<ModelDialogueConfigurationError>()));
    expect(const ModelDialogueEndpoint(speaker:'gemini',endpoint:'file:///tmp/local',
      model:'glm-test',apiKey:'test').validate,throwsA(isA<ModelDialogueConfigurationError>()));
    expect(const ModelDialogueEndpoint(speaker:'gemini',endpoint:'https://second.example/chat',
      model:'glm-test',apiKey:'').validate,throwsA(isA<ModelDialogueConfigurationError>()));
  });

  test('configuration loads canonical first model and exact second model',() async {
    await db.setSetting('deepseek_model','first-current');
    await db.setSetting('model','first-legacy');
    FlutterSecureStorage.setMockInitialValues({
      'deepseek_api_key':'first-test-key',
      'aiwangyou_gemini_api_key':'second-test-key',
      'aiwangyou_final_reply_model':'[A]glm-5.3-flash-1',
      'chat_api_provider':'aiwangyou_gemini',
    });
    final config=await ModelDialogueConfiguration.load(db,
      secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()));
    expect(config.deepSeek.model,'first-current');
    expect(config.gemini.model,'[A]glm-5.3-flash-1');
    expect(config.gemini.label,'GLM');
    expect(config.validateForCreation,returnsNormally);
  });

  for(final model in ['[A]glm-5.3-flash-1','vendor/custom-model-17']) {
    test('real request and saved message preserve second model $model',() async {
      final config=_configuration(model);
      final room=await repository.create(title:'动态模型',topic:'',
        participants:config.snapshot,firstSpeaker:'gemini');
      final sent=<Map<String,dynamic>>[];
      final gateway=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>MockClient((r) async {
        expect(r.url.host,'second.example');
        expect(r.headers['authorization'],'Bearer second-test-key');
        final body=jsonDecode(r.body) as Map<String,dynamic>;sent.add(body);
        expect(body['model'],model);expect(body.containsKey('extra_body'),isFalse);
        final prompt=jsonEncode(body['messages']);
        expect(prompt,contains('${config.gemini.label}（$model）'));
        expect(prompt, isNot(contains('你的发言由Gemini')));
        return _reply('这是当前第二通道的观点。');
      })),retryDelay:Duration.zero);
      final c=ModelDialogueController(roomId:room.id,repository:repository,
        configurationLoader:() async=>config,gateway:gateway);
      controllers.add(c);await c.initialize();await c.advance();
      expect(c.error,isEmpty);expect(sent,hasLength(1));
      expect(c.messages.single.model,model);expect(c.room!.label('gemini'),config.gemini.label);
    });
  }

  test('switch between turns preserves historical models and archival attribution',() async {
    var config=_configuration('gemini-original');
    final room=await repository.create(title:'继续旧房间',topic:'',
      participants:config.snapshot,firstSpeaker:'gemini');
    final sent=<String>[];
    final gateway=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>MockClient((r) async {
      sent.add((jsonDecode(r.body) as Map)['model'] as String);
      return _reply('第${sent.length}次观点');
    })),retryDelay:Duration.zero);
    final c=ModelDialogueController(roomId:room.id,repository:repository,
      configurationLoader:() async=>config,gateway:gateway);
    controllers.add(c);await c.initialize();await c.advance();
    config=_configuration('[A]glm-5.3-flash-1');
    // The next scheduled slot is first. Addressing the new family selects the
    // second slot without sending a request to the old Gemini configuration.
    await c.advance(userText:'@GLM，你怎么看？');
    expect(c.error,isEmpty);expect(sent,['gemini-original','[A]glm-5.3-flash-1']);
    final messages=await repository.messagesForRoom(room.id);
    expect(messages.where((m)=>m.speaker=='gemini').map((m)=>m.model),
      ['gemini-original','[A]glm-5.3-flash-1']);
    final transcript=ModelDialogueArchiveWorker.transcript(messages);
    expect(transcript,contains('Gemini'));expect(transcript,contains('GLM'));
    expect(transcript,contains('gemini-original'));expect(transcript,contains('[A]glm-5.3-flash-1'));
    final summary=ModelDialogueArchiveWorker.formatSummary({
      'overview':'讨论了两个观点','deepseek_view':'','gemini_view':'两次表达',
      'common_ground':'','open_questions':'','user_quotes':<String>[],
      'worth_remembering':true},messages);
    expect(summary,contains('Gemini、GLM一侧的观点'));
    final encoded=jsonEncode(c.room!.data);
    expect(encoded,contains('"version":1'));expect(encoded,contains('"gemini"'));
    expect(encoded,isNot(contains('second-test-key')));
  });

  test('two HTTP attempts freeze the same model; next click reloads current config',() async {
    var config=_configuration('[A]glm-5.3-flash-1');
    final room=await repository.create(title:'重试',topic:'',
      participants:config.snapshot,firstSpeaker:'gemini');
    final models=<String>[];
    final gateway=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>MockClient((r) async {
      models.add((jsonDecode(r.body) as Map)['model'] as String);
      if(models.length==1) {
        config=_configuration('relay/claude-current');
        return http.Response('temporary failure',503);
      }
      return _reply('使用本次快照。');
    })),retryDelay:Duration.zero);
    final c=ModelDialogueController(roomId:room.id,repository:repository,
      configurationLoader:() async=>config,gateway:gateway);
    controllers.add(c);await c.initialize();await c.advance();
    expect(models,['[A]glm-5.3-flash-1','[A]glm-5.3-flash-1']);
    expect(c.messages.single.model,'[A]glm-5.3-flash-1');
    await c.advance(userText:'Claude，请接着说。');
    expect(models.last,'relay/claude-current');expect(c.messages.last.model,'relay/claude-current');
  });
}
