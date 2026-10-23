import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/on_demand_agent_entry.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/history/conversation_history_reader.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_expression_service.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';

class _SmallPack extends StickerPackStorage {
  _SmallPack(AppDatabase db):super(db:db);
  static const pack=StickerPackMeta(id:'fixture',name:'Fixture',description:'',
    license:'',rootPath:'/unused',count:3);
  static final records=[for(var i=0;i<3;i++)StickerRecord(packId:'fixture',
    path:'memes/$i.png',tag:'daily',caption:'接梗$i',keywords:'无意义',
    toneScope:i==2?'bold':'general',intensity:1,enabled:true)];
  @override Future<List<StickerPackMeta>> scanPacks() async=>[pack];
  @override Future<Set<String>> enabledPackIds() async=>{'fixture'};
  @override Future<List<StickerRecord>> readRecords(StickerPackMeta pack,{bool applyEdits=true}) async=>records;
  @override Future<MessageAttachment> prepareAttachment({required StickerPackMeta pack,
    required StickerRecord record,required String messageId,required String source,
    required MessageAttachmentStorage attachments,PendingMediaOwner? pendingOwner}) async =>
      MessageAttachment(id:record.usageKey,messageId:messageId,kind:'image',
        originalPath:record.path,thumbnailPath:record.path,mimeType:'image/png',
        byteSize:1,width:1,height:1,source:source,createdAt:DateTime.now());
}

String _sse(String text)=>'data: ${jsonEncode({'choices':[{'delta':{'content':text},'finish_reason':'stop'}]})}\n\ndata: [DONE]\n\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);});
  tearDown(() async {await db.closeForTesting();});

  test('natural evolution conserves real time across reactive captures and zero-time ticks',() {
    final now=DateTime(2026,10,23,12);
    final baseline=DesireSnapshot.defaultBaselines();
    final snapshot=DesireSnapshot(drives:{...baseline,DriveKey.duty:.7},lastTickAt:now);
    final zero=DesireCorePolicy.advance(snapshot:snapshot,now:now);
    expect(zero.scale,0);expect(zero.drives[DriveKey.duty],.7);
    final event=DesireCorePolicy.advance(snapshot:snapshot,now:now,pulses:{DriveKey.duty:.01});
    expect(event.drives[DriveKey.duty],closeTo(.71,1e-12));
    var split=snapshot;
    for(var i=1;i<=20;i++) {
      final at=now.add(Duration(seconds:i*90));
      final next=DesireCorePolicy.advance(snapshot:split,now:at);
      expect(next.scale,closeTo(.125,1e-12));
      split=split.copyWith(drives:next.drives,baselines:next.baselines,lastTickAt:at);
    }
    final once=DesireCorePolicy.advance(snapshot:snapshot,now:now.add(const Duration(minutes:30)));
    // Duty has no incoming coupling: its pure relaxation must be independent
    // of capture count. Other coupled axes use the existing numerical policy.
    expect(split.drives[DriveKey.duty],closeTo(once.drives[DriveKey.duty]!,1e-10));
  });

  test('expired usage does not lock a pack; exhausted small pools rotate',() async {
    final service=StickerExpressionService(db:db,packStorage:_SmallPack(db));
    final now=DateTime(2026,10,23,12);
    for(final record in _SmallPack.records)await service.markUsed(record,now:now);
    final rotated=await service.replyCandidates(seed:'rotation',context:'发个表情包',now:now);
    expect(rotated,isNotEmpty);
    expect(rotated.every((c)=>c.record.usageKey!=_SmallPack.records.last.usageKey),true);
    final expired=await service.replyCandidates(seed:'expiry',context:'代码表情包',
      eligible:false,now:now.add(const Duration(days:15)));
    expect(expired,hasLength(3));
    expect(expired.any((c)=>c.record.toneScope=='bold'),true);
    await db.setSetting(StickerPackStorage.modeSetting,'off');
    expect(await service.replyCandidates(seed:'off',context:'发个表情包'),isEmpty);
  });

  test('explicit Agent sends also rotate an exhausted eligible pool',() async {
    final service=StickerExpressionService(db:db,packStorage:_SmallPack(db));
    for(final record in _SmallPack.records)await service.markUsed(record);
    final selected=await service.prepareForExplicitAgentRequest(messageId:'answer',intent:'发个表情包');
    expect(selected,isNotNull);
    expect(selected!.record.usageKey,_SmallPack.records.first.usageKey);
  });

  test('invitation reconciles only known play/none ambiguity, including after cache serialization',() {
    const compatible=JevChoiceDecision(choice:'play',probabilities:{'play':.51,'none':.43},ambiguous:true);
    const conflict=JevChoiceDecision(choice:'play',probabilities:{'play':.51,'pause':.48,'none':.01},ambiguous:true);
    expect(TurnTaskQuestionSet.invitationResolvesPlayNone(compatible),true);
    expect(TurnTaskQuestionSet.invitationResolvesPlayNone(conflict),false);
    const old=TurnTaskIntent(available:true,gameAction:'play',unresolvedFields:{'task_game'});
    expect(old.resolvePresentInvitation(cedarIntent:'accept',certain:true).gameExecutionResolved,false);
    final cached=TurnTaskIntent.fromJson(const TurnTaskIntent(available:true,gameAction:'play',
      invitationCanResolveAction:true,unresolvedFields:{'task_game','task_duration'}).toJson());
    expect(cached.resolvePresentInvitation(cedarIntent:'accept',certain:true).unresolvedFields,{'task_duration'});
  });

  test('explicit tool rejection retries same model as plain chat, then caches only that configuration',() async {
    final bodies=<Map>[];
    final ai=DeepSeekClient(streamClientFactory:()=>MockClient((request) async {
      final body=jsonDecode(request.body) as Map;bodies.add(body);
      if(body.containsKey('tools'))return http.Response('{"error":{"message":"tools are not supported by this model"}}',400);
      return http.Response.bytes(utf8.encode(_sse('正常回复')),200,
        headers:{'content-type':'text/event-stream; charset=utf-8'});
    }));addTearDown(ai.close);
    Future<void> reply(String model) async {
      final deltas=await ai.streamChat(apiKey:'fixture-compat-key',model:DeepSeekModelProfile.flash,
        modelName:model,effort:ReasoningEffort.low,messages:[{'role':'user','content':'随便聊聊'}],
        endpoint:'https://fixture.invalid/optional-tools',tools:[OnDemandAgentEntry.definition]).toList();
      expect(deltas.map((d)=>d.content).join(),'正常回复');
    }
    await reply('first-model');expect(bodies,hasLength(2));
    expect(bodies.first['model'],bodies.last['model']);expect(bodies.last.containsKey('tools'),false);
    await reply('first-model');expect(bodies,hasLength(3));
    await reply('changed-model');expect(bodies,hasLength(5));
  });

  for(final kind in ['auth','other400','requiredTool','cancel']) {
    test('$kind never triggers optional plain-chat recovery',() async {
      var calls=0;final cancellation=GenerationCancellationToken();
      final ai=DeepSeekClient(streamClientFactory:()=>MockClient((_) async {
        calls++;if(kind=='cancel')cancellation.cancel();
        return http.Response(kind=='other400'?'invalid context length':'tools unsupported',kind=='auth'?401:400);
      }));addTearDown(ai.close);
      await expectLater(ai.streamChat(apiKey:'fixture-$kind',model:DeepSeekModelProfile.flash,
        effort:ReasoningEffort.low,messages:const [],endpoint:'https://fixture.invalid/$kind',
        cancellationToken:cancellation,tools:kind=='requiredTool'?[{
          'type':'function','function':{'name':'cedar_toy_play','parameters':{'type':'object'}}
        }]:[OnDemandAgentEntry.definition]).toList(),throwsA(anything));
      expect(calls,1);
    });
  }

  for(final changed in [false,true]) {
    test('history read dependency ${changed?'rejects changed source':'allows unchanged source'} at actual final transaction',() async {
      await db.insertMessage(ChatMessage(id:'old-source',role:'user',content:'贝壳编号K735',createdAt:DateTime(2025,1,1)));
      final pending=await db.createGenerationTurn(user:ChatMessage(id:'current-user',role:'user',
        content:'查一下旧编号',createdAt:DateTime.now()),assistantMessageId:'answer',
        model:'fixture',reasoningEffort:'low');
      final job=(await db.claimGenerationJob(pending.id))!;
      final attempt=(await db.captureGenerationAttemptFence(job))!;
      final read=await ConversationHistoryReader(db).read({'source_id':'old-source'});
      expect(read.status,AgentToolStatus.succeeded);expect(read.historySources,isNotEmpty);
      if(changed) {
        final sql=await db.database;
        await sql.transaction((tx) async {
          await tx.update('messages',{'content':'编号已经修正'},where:'id = ?',whereArgs:['old-source']);
          await ConversationSourceStore.sourceChanged(tx,'old-source');
        });
      }
      final accepted=await db.completeGenerationJobIfCurrent(jobId:job.id,runToken:job.runToken,
        generationAttempt:attempt,historySources:read.historySources,
        assistant:ChatMessage(id:'answer',role:'assistant',content:'原文是K735',createdAt:DateTime.now()));
      expect(accepted,!changed);
      expect(await db.messageById('answer'),changed?isNull:isNotNull);
    });
  }
}
