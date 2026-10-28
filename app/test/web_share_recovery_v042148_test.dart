import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/autonomy/layered_public_web_provider.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_deepseek_appraiser.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_coordinator.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_recovery.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';

const _body='这是合成的可核验公开资料正文。研究对不同环境作了连续观察，只能说明所测样本，不能推广到全部情况。'
    '文中列出结果及限制，也指出仍需独立复核。这段文字用于本地协议与失败恢复测试，不读取任何真实网页。';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);});
  tearDown(() async {await db.closeForTesting();});
  Future<String> seed() async {
    final id=await db.seedDiagnosticPublicWebShareCandidate();
    await (await db.database).update('public_web_candidates',{'page_body':_body},where:'id=?',whereArgs:[id]);return id;
  }
  PublicWebShareCoordinator failing({String error='agnes_timeout'}) => PublicWebShareCoordinator(db:db,desire:DesireEngine(db),
    refreshBeforeShare:true,reader:(page,_,__) async=>page.copyWith(readState:'summary_failed',semanticState:'pending_appraisal',
      appraisalState:'discard',appraisalReason:error));

  test('transient share refresh keeps verified history, defers once, then stops within its bound',() async {
    final id=await seed(),sql=await db.database;var calls=0;
    final coordinator=PublicWebShareCoordinator(db:db,desire:DesireEngine(db),refreshBeforeShare:true,reader:(page,_,__) async {
      calls++;return page.copyWith(readState:'summary_failed',semanticState:'pending_appraisal',appraisalState:'discard',appraisalReason:'agnes_timeout');
    });
    final first=await coordinator.stageNextCandidate();expect(first.state,'refresh_retry_scheduled');expect(calls,1);
    var row=(await sql.query('public_web_candidates',where:'id=?',whereArgs:[id])).single;
    expect(row['read_state'],'verified');expect(row['page_body'],_body);expect(row['lifecycle_state'],'unread');
    expect(row['share_retry_count'],1);expect(row['share_last_error'],'agnes_timeout');
    expect(await db.getSetting('public_web_share_last_outcome'),'refresh_retry_scheduled');
    expect(await db.nextPublicWebCandidateForSharing(),isNull);
    expect((await db.nextPublicWebCandidateForSharing(now:DateTime.now().add(PublicWebShareRecovery.cooldown+const Duration(seconds:1))))?.id,id);
    await sql.update('public_web_candidates',{'share_retry_at':0},where:'id=?',whereArgs:[id]);
    final second=await coordinator.stageNextCandidate();expect(second.state,'refresh_failed');expect(calls,2);
    row=(await sql.query('public_web_candidates',where:'id=?',whereArgs:[id])).single;
    expect(row['lifecycle_state'],'reviewed');expect(row['share_retry_count'],PublicWebShareRecovery.maxFailures);
    expect(await db.nextPublicWebCandidateForSharing(),isNull);expect(await db.getSetting('public_web_share_last_outcome'),'refresh_failed');
  });
  test('a failed first source leaves a good sibling eligible and only one can become ready',() async {
    final id=await seed(),sql=await db.database,other=const Uuid().v4();
    final original=(await sql.query('public_web_candidates',where:'id=?',whereArgs:[id])).single;
    await sql.insert('public_web_candidates',{...original,'id':other,'fingerprint':List.filled(64,'b').join(),
      'share_score':.85,'discovered_at':(original['discovered_at'] as int)-1000});
    expect((await failing().stageNextCandidate()).candidateId,id);
    expect((await db.nextPublicWebCandidateForSharing())?.id,other);
    final success=await PublicWebShareCoordinator(db:db,desire:DesireEngine(db),refreshBeforeShare:true,
      reader:(page,_,__) async=>page.copyWith(appraisalState:'share_candidate')).stageNextCandidate();
    expect(success.ready,true);expect(success.candidateId,other);
    expect((await sql.query('public_web_candidates',where:"lifecycle_state='share_ready'")).length,1);
    expect((await sql.query('public_web_candidates',where:'id=?',whereArgs:[id])).single['lifecycle_state'],'reviewed');
    expect(await db.nextPublicWebCandidateForSharing(),isNull);
  });
  test('successful reread clears retry scheduling; restore cannot revive a pending retry',() async {
    final id=await seed(),sql=await db.database;await failing().stageNextCandidate();
    await PublicWebShareRecovery.restored(sql);
    expect((await sql.query('public_web_candidates',where:'id=?',whereArgs:[id])).single['lifecycle_state'],'reviewed');
    expect(await db.nextPublicWebCandidateForSharing(),isNull);
  });
  test('a verified semantic decline is terminal and does not pretend to be a network failure',() async {
    final id=await seed();
    final result=await PublicWebShareCoordinator(db:db,desire:DesireEngine(db),refreshBeforeShare:true,
      reader:(page,_,__) async=>page.copyWith(appraisalState:'hold',shareScore:.2,appraisalReason:'真实读完后决定不分享')).stageNextCandidate();
    expect(result.state,'refresh_declined');
    final row=(await (await db.database).query('public_web_candidates',where:'id=?',whereArgs:[id])).single;
    expect(row['lifecycle_state'],'declined');expect(row['share_retry_count'],0);
    expect(await db.getSetting('public_web_share_last_outcome'),'refresh_declined');
  });
  for(final kind in ['http','length','json']) {
    test('Agnes $kind failure remains a provider code rather than page garbling',() async {
      final id=await seed();final page=(await db.publicWebCandidateForRefresh(id))!;
      final client=MockClient((_) async => kind=='http'?http.Response('{}',503):http.Response(jsonEncode({'choices':[{
        'finish_reason':kind=='length'?'length':'stop','message':{'content':kind=='json'?'{}':'{"reader_summary":"片段"}'}}]}),200));
      final compact=AgnesWebCompactor(apiKey:'synthetic',endpoint:'https://relay.example.com/v1/chat/completions',model:'synthetic',client:client);
      final read=(await compact.summarizeExtracted(query:'合成测试',candidates:[page.copyWith(readState:'extracted')],extractedContents:{page.url:_body})).single;
      final code={'http':'agnes_http_503','length':'agnes_output_incomplete','json':'agnes_summary_format'}[kind]!;
      expect(read.readState,'summary_failed');expect(read.appraisalReason,code);
      final appraised=await DeepSeekPublicWebAppraiser(model:DeepSeekModelProfile.flash,apiKey:'synthetic',endpoint:'https://first.example.com',
        client:DeepSeekClient(jsonClientFactory:()=>MockClient((_) async=>throw StateError('must not call appraisal for failed read'))))
        .appraise(query:'合成',candidates:[read],sourceIntent:const DesireIntent(drive:DriveKey.curiosity,score:.8,reason:'合成',wantAction:'wildcard_share'),socialExcess:0);
      expect(appraised.single.semanticState,'pending_appraisal');expect(appraised.single.appraisalReason,code);client.close();
    });
  }
}
