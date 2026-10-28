import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/cedar_media_schema.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_activity_media.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_execution_repair.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);final String path;
  @override Future<String?> getApplicationSupportPath()async=>path;
  @override Future<String?> getTemporaryPath()async=>path;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late Directory root;late PathProviderPlatform oldPaths;
  late CedarToyActivityStore store;late CedarGameSession session;
  final png=base64Decode('iVBORw0KGgoAAAANSUhEUgAAACAAAAAYCAIAAAAUMWhjAAAAJElEQVR4nGP8z0BbwERj80ctGLVg1IJRC0YtGLVg1IJRC6gEAPHIAS8Wxt4fAAAAAElFTkSuQmCC');
  setUp(() async {
    root=await Directory.systemTemp.createTemp('cedar-media-148-');oldPaths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(root.path);
    db=await AppDatabase.createForTesting(databaseFactoryFfi);store=CedarToyActivityStore(db);
    session=CedarGameSession(id:'synthetic-session',gameId:'travel',guide:'合成指南',guideComplete:true,
      mode:CedarParticipationMode.solo,phase:CedarActivityPhase.active,updatedAt:DateTime.now(),
      lastAction:'trip_go',lastOutcome:'远端实际返回的旅行文字',events:[CedarGameEvent(id:'synthetic-event',kind:'outcome',
        summary:'远端实际返回的旅行文字',createdAt:DateTime.now(),action:'trip_go',readOnly:false)]);
    await store.save(session);await db.setSetting(CedarToyActivityStore.executionFenceSettingKey,'synthetic-execution');
  });
  tearDown(() async {await db.closeForTesting();PathProviderPlatform.instance=oldPaths;await root.delete(recursive:true);});
  McpToolOutcome outcome({bool photo=true})=>McpToolOutcome(content:[McpContentBlock(kind:McpContentKind.text,
    text:jsonEncode({'result':jsonEncode(photo?{'photo_url':'https://cdn.example.com/photo.png'}:{'text':'https://cdn.example.com/not-a-protocol-image.png'})}))],isError:false);
  Future<int> receive(http.Client client)=>CedarActivityMedia(db).receive(session:session,outcome:outcome(),executionId:'synthetic-execution',client:client);

  test('background protocol image becomes an event-owned local blob and activity reference',() async {
    final client=MockClient((_)async=>http.Response.bytes(png,200,headers:{'content-type':'image/png'}));
    expect(await receive(client),1);client.close();
    final saved=(await store.loadSession('travel'))!;expect(saved.lastOutcome,session.lastOutcome);
    expect(saved.events.last.imageReference,startsWith('media/'));expect(saved.events.last.imageData,'');
    expect((await (await db.database).query(CedarMediaSchema.table)).single['event_id'],'synthetic-event');
    expect(await db.takeUnreferencedMediaBlobs(),isEmpty);
    final images=await CedarActivityMedia(db).available(saved,saved.events);expect(images,hasLength(1));
    expect(await CedarActivityMedia.matches(await db.database,images),true);
  });
  test('ordinary URLs are not harvested and a broken optional picture preserves game text',() async {
    var calls=0;final client=MockClient((_)async {calls++;throw http.ClientException('synthetic download failure');});
    expect(await CedarActivityMedia(db).receive(session:session,outcome:outcome(photo:false),executionId:'synthetic-execution',client:client),0);
    expect(calls,0);expect(await receive(client),0);expect(calls,1);client.close();
    expect((await store.loadSession('travel'))!.lastOutcome,session.lastOutcome);
    expect(await (await db.database).query(CedarMediaSchema.table),isEmpty);
    expect(await db.getSetting(CedarActivityMedia.errorKey),contains('text_outcome_preserved'));
  });
  test('control cancellation during download prevents a late attachment and leaves no pending owner',() async {
    final client=MockClient((_)async {
      await db.setSetting(CedarToyActivityStore.controlRevisionKey,'changed-control');
      return http.Response.bytes(png,200,headers:{'content-type':'image/png'});
    });
    expect(await receive(client),0);client.close();
    expect(await (await db.database).query(CedarMediaSchema.table),isEmpty);
    expect(await (await db.database).query('pending_media_owners'),isEmpty);
    expect((await store.loadSession('travel'))!.events.last.imageReference,'');
    expect(await db.allMediaBlobs(),isEmpty);
  });
  test('clear withdraws image ownership; GC can reclaim and a final share source guard rejects it',() async {
    final client=MockClient((_)async=>http.Response.bytes(png,200,headers:{'content-type':'image/png'}));await receive(client);client.close();
    final saved=(await store.loadSession('travel'))!,media=CedarActivityMedia(db),images=await media.available(saved,saved.events);
    await db.tryAcquireLocalLease('proactive_lease_until');
    final owner=PendingMediaOwner.proactive(messageId:'synthetic-share',fence:(await db.captureBrainWorkFence(leaseKey:'proactive_lease_until'))!);
    final attachment=await media.attach(images.single,owner.messageId,owner);
    await store.clear();expect(await CedarActivityMedia.matches(await db.database,images),false);
    final blocked=await db.commitProactiveMessageIfCurrent(message:ChatMessage(id:owner.messageId,role:'assistant',content:'图片',createdAt:DateTime.now(),attachments:[attachment]),
      evaluationStartedAt:DateTime.now(),workFence:owner.fence,pendingMediaOwner:owner,
      cedarMediaGuard:(sql)=>CedarActivityMedia.matches(sql,images));
    expect(blocked,'cedar_media_source_changed');expect(await db.messageById(owner.messageId),isNull);
    await db.releasePendingMedia(owner);
    expect(await db.takeUnreferencedMediaBlobs(),hasLength(1));
  });
  test('export/import keeps the event/blob binding and rejects a fabricated event owner',() async {
    final client=MockClient((_)async=>http.Response.bytes(png,200,headers:{'content-type':'image/png'}));await receive(client);client.close();
    final backup=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;
    CedarMediaSchema.validate(backup['tables'] as Map,version:AppDatabase.schemaVersion);
    await db.importAll(backup);
    expect(await (await db.database).query(CedarMediaSchema.table),hasLength(1));expect(await db.takeUnreferencedMediaBlobs(),isEmpty);
    final tables=jsonDecode(jsonEncode(backup['tables'])) as Map;
    (tables[CedarMediaSchema.table] as List).single['event_id']='not-an-event';
    expect(()=>CedarMediaSchema.validate(tables,version:AppDatabase.schemaVersion),throwsFormatException);
  });
  for(final text in ['干预方式必须是 listen/join/mediate/separate/story/challenge','参数 mode 必须为 solo/shared','可选值为 listen/join']) {
    test('explicit enum response is a parameter error: $text',()=>expect(CedarActionFeedback.parameterError(text),true));
  }
  for(final text in ['客人不喜欢这杯酒','客人说：你的方式必须是热情','答错了，下轮再来']) {
    test('ordinary story/refusal is not a parameter error: $text',()=>expect(CedarActionFeedback.parameterError(text),false));
  }
  test('real write progress clears earlier parameter failures',() {
    CedarGameEvent event(String id,String text)=>CedarGameEvent(id:id,kind:'outcome',summary:text,createdAt:DateTime.now(),action:'cmd',readOnly:false);
    final errors=[event('a','干预方式必须是 listen/join'),event('b','参数无效')];
    expect(CedarExecutionRepair.parameterFailures(session.copyWith(events:errors)),hasLength(2));
    expect(CedarExecutionRepair.parameterFailures(session.copyWith(events:[...errors,event('c','已加入谈话，关系发生变化')])),isEmpty);
  });
}
