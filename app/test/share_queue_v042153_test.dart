import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_coordinator.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/automatic_memory_permit.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_private_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_runtime.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_share_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  late DateTime now;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db=await AppDatabase.createForTesting(databaseFactoryFfi);
    now=DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);
  });
  tearDown(() async => db.closeForTesting());

  Future<(String,String,String)> webPair() async {
    final old=await db.seedDiagnosticPublicWebShareCandidate(now:now);
    final ready=await PublicWebShareCoordinator(db:db,desire:DesireEngine(db)).stageNextCandidate(now:now);
    expect(ready.ready,true);
    final sql=await db.database;
    final row=(await sql.query('public_web_candidates',where:'id=?',whereArgs:[old])).single;
    final fresh=const Uuid().v4();
    await sql.insert('public_web_candidates',{...row,'id':fresh,'fingerprint':fresh,
      'lifecycle_state':'unread','last_viewed_at':null,'share_score':.9});
    return (old,ready.thoughtId!,fresh);
  }
  for(final state in ['missing','dormant','snoozed','wrong_source','expired']) {
    test('web $state binding does not block preview or atomic stage claim',() async {
      final (old,thought,fresh)=await webPair(); final sql=await db.database;
      switch(state) {
        case 'missing': await db.deleteThought(thought);
        case 'dormant': await sql.update('thoughts',{'lifecycle_state':'dormant'},where:'id=?',whereArgs:[thought]);
        case 'snoozed': await sql.update('thoughts',{'snoozed_until':now.add(const Duration(hours:1)).millisecondsSinceEpoch},where:'id=?',whereArgs:[thought]);
        case 'wrong_source': await sql.update('thoughts',{'source':'conversation_turn:other'},where:'id=?',whereArgs:[thought]);
        case 'expired': await sql.update('public_web_candidates',{'expires_at':now.millisecondsSinceEpoch},where:'id=?',whereArgs:[old]);
      }
      expect(await db.activeReadyPublicWebShareCandidate(now:now),isNull);
      expect((await db.nextPublicWebCandidateForSharing(now:now))?.id,fresh);
      final fence=(await db.captureBrainWorkFence())!;
      expect((await db.claimNextPublicWebCandidateForSharing(now:now,workFence:fence))?.id,fresh);
      final original=await db.thoughtById(thought);
      if(state=='missing') expect(original,isNull);
      if(state=='dormant') expect(original!.lifecycleState,'dormant');
      if(state=='snoozed') expect(original!.isSnoozedAt(now),true);
    });
  }
  for(final state in ['active','fixation']) {
    test('web $state binding still owns its normal ready opportunity',() async {
      final (old,thought,_)=await webPair();
      await (await db.database).update('thoughts',{'lifecycle_state':state},where:'id=?',whereArgs:[thought]);
      expect((await db.activeReadyPublicWebShareCandidate(now:now))?.id,old);
      expect(await db.nextPublicWebCandidateForSharing(now:now),isNull);
      expect(await db.claimNextPublicWebCandidateForSharing(now:now,workFence:(await db.captureBrainWorkFence())!),isNull);
    });
  }
  test('a snoozed ready binding is preserved and becomes eligible only when due',() async {
    final (old,thought,_)=await webPair();
    final until=now.add(const Duration(minutes:30));
    await (await db.database).update('thoughts',{'snoozed_until':until.millisecondsSinceEpoch},where:'id=?',whereArgs:[thought]);
    expect(await db.activeReadyPublicWebShareCandidate(now:now),isNull);
    expect((await db.activeReadyPublicWebShareCandidate(now:until))?.id,old);
    expect((await db.thoughtById(thought))!.snoozedUntil,until);
  });

  Future<String> qqNote() async {
    await db.ensureStateLineageId(); await db.setSetting('post_turn_queue_enabled','0');
    const config=QqPrivateConfig(appId:'12345',secret:'fixture-only',namespace:'share153',owner:'owner',replyChannel:'first');
    await config.save(); await QqPrivateConfig.bind(config.namespace,config.owner);
    await QqOptions(namespace:'share153',groups:const {'group'},ownerShare:true).save(db:db);
    await db.setSetting('qq_master_enabled_v2','1');
    final store=QqStore(db),scope=QqRuntime.scope(config);
    final cid=QqStore.conversationId(scope,'group','group'),fence=await store.capture();
    await store.append(fence:fence,scope:scope,kind:'group',target:'group',platformId:'source',sender:'peer',
      text:'群友讨论周末看珊瑚',observedAt:now.subtract(const Duration(minutes:2)).millisecondsSinceEpoch,receivedAt:now.millisecondsSinceEpoch);
    final sql=await db.database,rows=await sql.query('qq_archive',where:'conversation_id=?',whereArgs:[cid]);
    final stamps=<Map<String,Object?>>[],reader=QqArchiveReader(sql);
    for(final row in rows) {await reader.render(row,stamp:stamps);}
    final permit=await AutomaticMemoryPermit.capture(sql,'auto_memory');
    expect(await store.saveNote(fence,cid,rows,stamps,permit,'群友讨论周末看珊瑚','群里聊到珊瑚',now.millisecondsSinceEpoch),true);
    return QqStore.hash(['note',cid,rows.last['seq']]);
  }
  test('App WAIT skips exactly its claim and leaves another pending story reachable',() async {
    final id=await qqNote(),store=QqShareStore(db),sql=await db.database;
    final offer=(await store.claim(id,'app',now))!;
    final row=(await sql.query('qq_shares',where:'id=?',whereArgs:[id])).single;
    await sql.insert('qq_shares',{...row,'id':'other','state':'pending','destination':'','updated_at':now.millisecondsSinceEpoch});
    expect(await sql.transaction((txn)=>offer.settleUnsentApp(txn,declined:true,now:now)),true);
    expect((await sql.query('qq_shares',where:'id=?',whereArgs:[id])).single['state'],'skipped');
    expect((await store.candidates(now)).map((r)=>r['id']),['other']);
    expect(await sql.transaction((txn)=>offer.settleUnsentApp(txn,declined:false,now:now)),false);
  });
  for(final reason in ['preempted','exception','commit_rejected']) {
    test('App $reason releases only an unsent claim with a bounded retry time',() async {
      final id=await qqNote(),store=QqShareStore(db),sql=await db.database;
      final offer=(await store.claim(id,'app',now))!;
      if(reason=='commit_rejected') {
        await db.insertMessage(ChatMessage(id:'new-user',role:'user',content:'新消息',createdAt:now.add(const Duration(seconds:1))));
        expect(await db.commitProactiveMessageIfCurrent(message:ChatMessage(id:'blocked',role:'assistant',content:'群里聊起珊瑚',createdAt:now,isProactive:true),
          evaluationStartedAt:now,qqEvidence:offer.evidence,qqShare:offer),isNotNull);
      }
      expect(await sql.transaction((txn)=>offer.settleUnsentApp(txn,declined:false,now:now)),true);
      expect(await store.candidates(now),isEmpty);
      expect((await store.candidates(now.add(const Duration(seconds:61)))).single['id'],id);
      expect(await db.messageById('blocked'),isNull);
    });
  }
  test('late cleanup and late delivery from an older claim cannot consume a newer claim',() async {
    final id=await qqNote(),store=QqShareStore(db),sql=await db.database;
    final old=(await store.claim(id,'app',now))!;
    await sql.transaction((txn)=>old.settleUnsentApp(txn,declined:false,now:now));
    final newer=(await store.claim(id,'app',now.add(const Duration(seconds:61))))!;
    expect(newer.claimedAt,greaterThan(old.claimedAt)); expect(await old.matches(sql),false);
    expect(await sql.transaction((txn)=>old.settleUnsentApp(txn,declined:false,now:now)),false);
    expect(await newer.matches(sql),true);
  });
  test('atomic App delivery stays sent when finally attempts unsent cleanup',() async {
    final id=await qqNote(),sql=await db.database;
    final offer=(await QqShareStore(db).claim(id,'app',now))!;
    expect(await db.commitProactiveMessageIfCurrent(message:ChatMessage(id:'sent153',role:'assistant',content:'群里在聊珊瑚',createdAt:now,isProactive:true),
      evaluationStartedAt:now,qqEvidence:offer.evidence,qqShare:offer),isNull);
    expect(await sql.transaction((txn)=>offer.settleUnsentApp(txn,declined:false,now:now)),false);
    expect((await sql.query('qq_shares')).single['state'],'sent');
    expect((await sql.query('qq_receipts')).single['message_id'],'sent153');
  });
  for(final state in ['sending','send_uncertain','sent_archive_pending','sent_archive_failed','partially_sent','sent']) {
    test('cleanup and stale recovery never reopen $state delivery',() async {
      final id=await qqNote(),store=QqShareStore(db),sql=await db.database;
      final offer=(await store.claim(id,'app',now))!;
      await sql.update('qq_shares',{'state':state,'updated_at':now.subtract(const Duration(hours:1)).millisecondsSinceEpoch},where:'id=?',whereArgs:[id]);
      expect(await sql.transaction((txn)=>offer.settleUnsentApp(txn,declined:false,now:now)),false);
      expect(await store.recoverAbandonedAppClaims(now),0);
      expect((await sql.query('qq_shares')).single['state'],state);
    });
  }
  test('old App claims are repaired after the lease bound; fresh and QQ claims are preserved',() async {
    final id=await qqNote(),store=QqShareStore(db),sql=await db.database;
    await store.claim(id,'app',now);
    expect(await store.recoverAbandonedAppClaims(now.add(const Duration(minutes:9))),0);
    final old=now.subtract(const Duration(minutes:20)).millisecondsSinceEpoch;
    await sql.update('qq_shares',{'updated_at':old},where:'id=?',whereArgs:[id]);
    final row=(await sql.query('qq_shares')).single;
    await sql.insert('qq_shares',{...row,'id':'qq-owned','destination':'qq'});
    expect(await store.recoverAbandonedAppClaims(now),1);
    expect((await sql.query('qq_shares',where:'id=?',whereArgs:['qq-owned'])).single['state'],'claimed');
    expect((await store.candidates(now.add(const Duration(seconds:61)))).map((r)=>r['id']),isEmpty);
    // The QQ claim intentionally still owns the cross-entrance exclusion.
    expect((await sql.query('qq_shares',where:'id=?',whereArgs:[id])).single['state'],'pending');
  });
  test('cleanup captured before a restore cannot alter the restored brain',() async {
    final id=await qqNote(),sql=await db.database;
    final offer=(await QqShareStore(db).claim(id,'app',now))!;
    await db.setSetting('runtime_state_epoch_v1','restored153');
    expect(await sql.transaction((txn)=>offer.settleUnsentApp(txn,declined:false,now:now)),false);
    expect((await sql.query('qq_shares')).single['state'],'claimed');
  });
}
