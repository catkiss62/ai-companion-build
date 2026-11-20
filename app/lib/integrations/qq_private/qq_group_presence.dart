part of 'qq_runtime.dart';

/// Stable across wakes and restarts. All selected groups share one daily roll.
class QqPresenceWindow {
  QqPresenceWindow(String scope,DateTime at)
      : day=at.toIso8601String().split('T').first,
        hash=QqStore.hash(['group-presence',scope,at.year,at.month,at.day]);
  final String day,hash;
  int roll(int offset,int bound)=>int.parse(hash.substring(offset,offset+6),radix:16)%bound;
  bool get offered=>roll(0,100)<35;
  bool get offerPicture=>roll(12,4)==0;
  bool due(DateTime at) {
    final elapsed=at.hour*60+at.minute-(540+roll(6,14*60));
    return offered && elapsed>=0 && elapsed<10;
  }
}

extension _GroupPresence on QqRuntime {
  void _schedulePresence() {
    if(_checkingPresence || _stopped)return;
    _checkingPresence=true;
    _queueWork(() async {try {await _offerPresence();} finally {_checkingPresence=false;}},'presence_failed');
  }

  Future<void> _offerPresence() async {
    final at=now(), c=await configReader(), opts=await optionsReader();
    final groups=opts.groups.intersection(opts.presenceGroups).toList()..sort();
    if(groups.isEmpty || c.owner.isEmpty || !_sameDevice(c) || !await _enabled())return;
    final window=QqPresenceWindow(QqRuntime.scope(c),at);
    if(!window.due(at) || await resting())return;
    final target=groups[window.roll(18,groups.length)];
    final cid=QqStore.conversationId(QqRuntime.scope(c),'group',target);
    final fence=await store.capture(conversationId:cid);
    final key='qq_presence_last_day:${QqRuntime.scope(c)}';
    final id='presence:${window.hash}';
    final sql=await store.db.database;
    final convo=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid])).firstOrNull;
    if(convo==null || _enqueued.contains(cid) || _timers.containsKey(cid) || (await store.pending(cid)).isNotEmpty)return;
    final authorityKey=QqShareStore.policyKey(c.namespace);
    final authority=QqStore.hash(opts.toJson());
    Future<bool> authorized() async {
      final saved=await store.db.getSetting(authorityKey);
      return saved==null || saved==authority;
    }
    if(!await authorized())return;
    // Check silence and capture the draft's sequence fence in the same claim.
    // A busy group can still qualify later inside today's original window.
    final latest=await store.write(fence,(txn) async {
      if(await BrainWorkFence.value(txn,key)==window.day)return null;
      final cutoff=at.subtract(const Duration(minutes:10)).millisecondsSinceEpoch;
      final activity=await txn.rawQuery(
        "SELECT 1 FROM qq_archive WHERE conversation_id=? AND role='user' AND received_at>? LIMIT 1",
        [cid,cutoff]);
      if(activity.isNotEmpty)return null;
      final state=await txn.query('qq_conversations',columns:['last_reply_at'],
        where:'id=?',whereArgs:[cid],limit:1);
      if(state.isEmpty || at.millisecondsSinceEpoch-(state.single['last_reply_at'] as int)<30*60000)return null;
      final context=await txn.query('qq_archive',columns:['seq','role','content'],
        where:'conversation_id=?',whereArgs:[cid],orderBy:'seq DESC',limit:4);
      await txn.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',[key,window.day]);
      return context;
    });
    if(latest==null)return;
    final through=latest.firstOrNull?['seq'] as int? ?? 0;
    Future<bool> current() async {
      if(_enqueued.contains(cid) || _timers.containsKey(cid) || !await _enabled() || await resting() || !await store.current(fence) || !await authorized())return false;
      final fresh=await configReader();
      if(!_sameDevice(fresh) || QqRuntime.policy(fresh,await optionsReader())!=QqRuntime.policy(c,opts) ||
        now().difference(at)>const Duration(minutes:10))return false;
      return (await sql.rawQuery('SELECT 1 FROM qq_archive WHERE conversation_id=? AND seq>? AND role!=? LIMIT 1',[cid,through,'assistant'])).isEmpty;
    }
    final client=clientFactory(() async=>!await current());_clients.add(client);
    try {
      if(!await current())return;
      final connection=opts.illustrationEnabled && window.offerPicture && !_drawingBusy
        ? await secure.readIllustration() : const IllustrationConnection();
      final batch=QqBatch(id,convo,const [],fence);
      final imageAllowed=connection.configured && await QqDrawingPolicy.autonomousIllustrationOpportunity(store,batch,at.millisecondsSinceEpoch);
      final model=await FirstChannelModel.read(store.db);
      final generator=QqReplyGenerator(client:client,secure:secure,current:current,diagnosticDb:store.db,onStatus:status);
      final channel=c.replyChannel.isNotEmpty?c.replyChannel:(await secure.readChatProvider()).isGeminiRelay?'second':'first';
      final raw=await generator.generate(channel:channel,firstModel:model,firstEffort:await FirstChannelModel.readEffort(store.db),
        secondEffort:ReasoningEffort.fromApiName(await store.db.getSetting('reasoning_effort')),usageLane:'qq_group_presence',
        messages:[{'role':'system','content':'${QqGroupPersonaProjection.compose(card:opts.core,publicDraft:opts.publicPersona)}\n'
          '此刻你只是想在群里露个脸，随口一句就可以，发完可以继续潜水。没有人正在问你。不必找话题、找人回应或问候。只用群内公开身份。'
          '最近几句仅供判断场合，若不合适输出 WAIT。\n${imageAllowed?QqIllustrationChoice.prompt:"只发文字。"}'},
          {'role':'user','content':jsonEncode([for(final r in latest.reversed) {'role':r['role'],'text':String.fromCharCodes((r['content'] as String).runes.take(180))}])}]);
      var words=QqIllustrationChoice.visible(raw).trim();
      if(words=='WAIT' || words.runes.length>180 || words.contains(RegExp(r'[<>]')) || !await current())return;
      final choice=imageAllowed?QqIllustrationChoice.parse(raw):null;
      await store.illustrationAudit(batch,'choice',at.millisecondsSinceEpoch,{'group':true,'presence':true,
        'eligible':imageAllowed,'requested':false,'selected':choice!=null});
      if(choice==null && (words.isEmpty || QqIllustrationChoice.needsPictureCorrection('',true,words)))return;
      if(!await QqGroupJudge(client,secure,decisions:groupDecisions).addressSafe(model:model,text:words,sticker:choice?.brief??'',current:current))return;
      var fileInfo='',description='';
      if(choice!=null) {
        if(_drawingBusy)return;
        _drawingBusy=true;
        try {
          if(!await store.write(fence,(txn)=>QqDrawingPolicy.reserveAutonomousIllustration(txn,batch,now().millisecondsSinceEpoch)))return;
          final picture=await illustrations.generateReserved(batch:batch,choice:choice,connection:connection,secure:secure,
            planner:client,context:'在群中随意露个脸。',current:current);
          description=picture.description;
          await store.illustrationAudit(batch,'generated',now().millisecondsSinceEpoch,{'presence':true});
          fileInfo=await api.uploadImage(group:true,target:target,bytes:picture.image.bytes,filename:picture.filename,current:current);
          if(choice.only)words='';
        } catch(error) {
          if(!await current())return;
          await store.recordFailure(fence,'presence_illustration',error,operation:id,conversation:cid);
          words=description.isEmpty?'这次没画出来。':'画好了，图没传上来。';
        } finally {_drawingBusy=false;}
      }
      if(!await current())return;
      await QqReplyDelivery(api).send(group:true,target:target,messageId:'',text:words,fileInfo:fileInfo,requireMedia:fileInfo.isNotEmpty,
        current:current,beforeSend:() async {},sent:(seq,text,image) async {
          final time=now().millisecondsSinceEpoch;
          await store.write(fence,(txn) async {
            await txn.rawInsert('INSERT OR IGNORE INTO qq_archive(id,conversation_id,platform_id,sender,role,content,observed_at,received_at) VALUES(?,?,?,?,?,?,?,?)',
              ['$id:$seq',cid,api.receiptFor(group:true,target:target,messageId:'',sequence:seq).id,'assistant','assistant',
                [if(text.isNotEmpty)text,if(image)'[插画] $description'].join(' '),time,time]);
            await txn.update('qq_conversations',{'last_reply_at':time},where:'id=?',whereArgs:[cid]);
          });
        });
      if(fileInfo.isNotEmpty)await store.illustrationAudit(batch,'sent',now().millisecondsSinceEpoch,{'presence':true});
      status('presence_sent');
    } catch(error) {
      await store.recordFailure(fence,'presence',error,operation:id,conversation:cid);
    } finally {client.close();_clients.remove(client);}
  }
}
