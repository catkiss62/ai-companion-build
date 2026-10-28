import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/cedar_media_schema.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_activity_media.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);final String path;
  @override Future<String?> getApplicationSupportPath()async=>path;
  @override Future<String?> getTemporaryPath()async=>path;
}
class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_synthetic');int calls=0;bool photo=true;
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,{GenerationCancellationToken? cancellationToken})async {
    calls++;
    final state={'ok':true,'status':'playing','room_id':'ROOM150','revision':2,'your_turn':false,
      'current_actor':{'player_id':'human','role':'human'},'wait_scope':'current_request_only',
      'next_call':{'game':'duel','action':'state','params':{'room_id':'ROOM150','wait':true}},
      if(photo)'photo_url':'https://cdn.example.com/actual.png'};
    return McpToolOutcome(isError:false,structuredContent:state,content:[McpContentBlock(kind:McpContentKind.text,text:jsonEncode(state))]);
  }
}
class _Media extends CedarActivityMedia {
  _Media(super.db,this.client);final http.Client client;
  @override Future<int> receive({required CedarGameSession session,required McpToolOutcome outcome,
    required String executionId,GenerationCancellationToken? cancellationToken,http.Client? client}) =>
      super.receive(session:session,outcome:outcome,executionId:executionId,cancellationToken:cancellationToken,client:this.client);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late CedarToyActivityStore store;late _Game game;late DeepSeekClient ai;
  late Directory root;late PathProviderPlatform oldPaths;late http.Client downloads;
  final clock=DateTime(2026,10,29,12);
  const native=MethodChannel('ai_companion/system');
  final png=base64Decode('iVBORw0KGgoAAAANSUhEUgAAACAAAAAYCAIAAAAUMWhjAAAAJElEQVR4nGP8z0BbwERj80ctGLVg1IJRC0YtGLVg1IJRC6gEAPHIAS8Wxt4fAAAAAElFTkSuQmCC');
  setUp(()async {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(native,
      (call)async=>call.method=='runtimeProcessEpoch'?'fixture-150':null);
    root=await Directory.systemTemp.createTemp('cedar-150-');oldPaths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(root.path);
    db=await AppDatabase.createForTesting(databaseFactoryFfi);store=CedarToyActivityStore(db);game=_Game();
    ai=DeepSeekClient(streamClientFactory:()=>MockClient((_)async=>throw StateError('No model work expected')));
    downloads=MockClient((_)async=>http.Response.bytes(png,200,headers:{'content-type':'image/png'}));
    await store.save(CedarGameSession(id:'session-150',gameId:'duel',guide:'多人游戏。state 查询；move 落子。',guideComplete:true,
      mode:CedarParticipationMode.multiplayer,phase:CedarActivityPhase.waitingUser,updatedAt:clock,
      nextActor:'wait',invitationApproved:true,nextActionAt:clock.subtract(const Duration(seconds:1)),
      continuationAction:'state',continuationParamsJson:jsonEncode({'room_id':'ROOM150','wait':true}),continuationWaitScope:'current_request_only'));
  });
  tearDown(()async {ai.close();downloads.close();await db.closeForTesting();PathProviderPlatform.instance=oldPaths;await root.delete(recursive:true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(native,null);});
  CedarToyAutonomyEngine engine({Future<String> Function()? endpoint})=>CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,
    tokenReader:()async=>'fixture',apiKeyReader:()async=>'fixture',endpointReader:endpoint??()async=>'https://fixture.invalid/chat',
    clientFactory:(_)=>game,mediaFactory:(db)=>_Media(db,downloads));
  for(final control in ['pause','restore','switch']) {
    test('$control during continuation setup blocks the old execution before any game call',()async {
      final entered=Completer<void>(),release=Completer<void>();
      final pending=engine(endpoint:()async {entered.complete();await release.future;return 'https://fixture.invalid/chat';}).continueDue(now:clock);
      await entered.future.timeout(const Duration(seconds:3));
      if(control=='restore')await db.setSetting('runtime_state_epoch_v1','new-restored-epoch');
      else if(control=='switch')await store.pauseAndRelease(source:'changed_game');
      else await store.pause();
      release.complete();final result=await pending;
      expect(result.state,startsWith('preempted_'));expect(game.calls,0);expect((await store.loadState()).execution,isNull);
    });
  }
  test('real continuation path persists protocol media without counting a new play round',()async {
    final result=await engine().continueDue(now:clock);
    expect(result.state,'remote_wait_renewed');expect(game.calls,1);
    final state=await store.loadState(),session=(await store.loadSession('duel'))!;
    expect(state.completedPlayRounds,0);expect(session.events.last.imageReference,startsWith('media/'));
    final rows=await (await db.database).query(CedarMediaSchema.table);expect(rows,hasLength(1));
    expect(rows.single['event_id'],session.events.last.id);expect(await store.pendingDirectShares(),isEmpty);
    await store.clear();expect(await (await db.database).query(CedarMediaSchema.table),isEmpty);
  });
  test('pause during observation image download keeps text but commits no stale image',()async {
    downloads.close();downloads=MockClient((_)async {await store.pause();return http.Response.bytes(png,200,headers:{'content-type':'image/png'});});
    await engine().continueDue(now:clock);
    expect(game.calls,1);expect((await store.loadSession('duel'))!.phase,CedarActivityPhase.paused);
    expect((await store.loadSession('duel'))!.lastOutcome,contains('ROOM150'));
    expect(await (await db.database).query(CedarMediaSchema.table),isEmpty);
    expect(await (await db.database).query('pending_media_owners'),isEmpty);
  });
}
