import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../memory/memory_revision.dart';
import '../models/chat_message.dart';
import '../models/memory_item.dart';
import 'cedar_game_protocol.dart';
import 'cedar_toy_activity.dart';

String _digest(Object? value) => sha256.convert(utf8.encode(jsonEncode(value))).toString();
Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : {};
Map<String, dynamic> _json(String value) {
  try { return _map(jsonDecode(value)); } catch (_) { return {}; }
}
String _text(Object? value, int limit) => value is String ? value.trim().substring(0, value.trim().length.clamp(0, limit).toInt()) : '';

/// A real game/save identity, not a slot number guessed by the extraction model.
class CedarArrangementScope {
  CedarArrangementScope(this.game, this.title, this.session, this.slot, this.epoch);
  final String game, title, session, slot, epoch;
  String get id => _digest([game, session, slot, epoch]);
  Map<String, Object?> toJson() => {'id': id, 'game': game, 'title': title,
    'session': session, 'slot': slot, 'epoch': epoch};
  static CedarArrangementScope? fromJson(Object? raw) {
    final m = _map(raw);
    if (['game','title','session','slot','epoch'].any((k) => m[k] is! String)) return null;
    final s = CedarArrangementScope(m['game'],m['title'],m['session'],m['slot'],m['epoch']);
    return s.game.isNotEmpty && s.session.isNotEmpty && m['id'] == s.id ? s : null;
  }
  static String slotFor(CedarGameSession session, Map<String, dynamic> input) {
    if (!CedarSaveSlotPolicy.supportsFiveSlots(session.guide)) return 'session';
    final slot = input['slot'] ?? 1; // Only this official five-slot contract defines default 1.
    return slot is num && slot == slot.toInt() && slot >= 1 && slot <= 5 ? '${slot.toInt()}' : '';
  }
  static CedarArrangementScope? current(CedarGameSession session, {DateTime? at}) {
    final events = session.events.where((e) => e.kind == 'outcome' && CedarGameResultPolicy.succeeded(e.summary) && e.action.isNotEmpty &&
      !CedarPlatformActionPolicy.isPlatformAction(e.action)).toList()
      ..sort((a,b) => b.createdAt.compareTo(a.createdAt));
    final event = events.where((e) => at == null || !e.createdAt.isAfter(at)).firstOrNull;
    if (event == null) return null;
    final slot = slotFor(session, _json(event.inputJson));
    if (slot.isEmpty) return null;
    // A delayed extractor cannot bind an old utterance to a later new/import.
    if (at != null && events.any((e) => e.createdAt.isAfter(at) &&
        CedarSaveSlotPolicy.isNewOrResetAction(e.action) && slotFor(session, _json(e.inputJson)) == slot)) return null;
    return CedarArrangementScope(session.gameId, session.displayName, session.id, slot,
      session.arrangementSaveEpochs[slot] ?? 'legacy:${session.id}:$slot');
  }
  bool matchesSession(CedarGameSession value) => value.gameId == game && value.id == session &&
      (value.arrangementSaveEpochs[slot] ?? 'legacy:${value.id}:$slot') == epoch;
}

class CedarArrangementExtraction {
  const CedarArrangementExtraction(this.scopes, this.items, this.fence, [this.facts = const []]);
  final List<CedarArrangementScope> scopes;
  final List<MemoryItem> items;
  final BrainWorkFence fence;
  final List<Map<String,Object?>> facts;
  Map<String, Object?> toJson() => {'version': 1, 'scopes': scopes.map((s)=>s.toJson()).toList(),
    'targets': {for(final m in items) m.id: {'snapshot': MemoryRevisionSnapshot.capture(m).toJson(),
      'metadata': CedarGameArrangementStore.metadata(m)}},
    'fence': {'identity': fence.identity, 'settings': fence.expectedSettings}};
  String get prompt => jsonEncode({'actual_progress_before_reply':facts,'scopes': scopes.map((s)=>s.toJson()).toList(),
    'existing': items.map((m)=>{'id':m.id,'text':m.content,
      'metadata':CedarGameArrangementStore.metadata(m)}).toList()});
}

class CedarArrangementReviewBundle {
  const CedarArrangementReviewBundle({this.scope, this.items = const [], this.events = const [], this.fence});
  final CedarArrangementScope? scope;
  final List<MemoryItem> items;
  final List<CedarGameEvent> events;
  final BrainWorkFence? fence;
  String get prompt => items.isEmpty ? '' : '''【本存档仍有效的口头安排 · 可调整的游戏参考】
${jsonEncode({'scope':scope!.toJson(),'arrangements':items.map((m)=>{'id':m.id,'text':m.content,
  'condition':CedarGameArrangementStore.metadata(m)['condition'],'completion_basis':CedarGameArrangementStore.metadata(m)['completion_basis'],'actor':m.actorKey,'executor':CedarGameArrangementStore.metadata(m)['executor']}).toList(),
  'actual_results':events.map((e)=>{'event_id':e.id,'at':e.createdAt.millisecondsSinceEpoch,
    'action':e.action,'input':e.inputJson,'result':_text(e.summary,1200),'actor':'companion'}).toList()})}
结合真实局面考虑这些安排，不因它们存在就重复购买、重开或强行执行；用户停止/邀请/存档权限始终优先。
已有真实成功结果确实实现某个具体目标时，才在 arrangement_reviews_json 填入 [{"id":"该安排ID","event_id":"对应已发生结果ID"}]。
核对结果是否晚于该安排、对象和条件是否相同；失败、提到游戏、未来打算和当前准备执行的动作都不是完成证据。只读结果可以证明确实查看或所见状态，不能证明亲自种植、购买或共同游玩；action类目标必须有对应真实写操作。
用户让留给自己操作的安排不能由助手擅自操作冒充履约。不确定时返回空数组，保留安排供以后参考。''';
}

/// Reuses normal source-bound Memory rows and the existing extraction/planning
/// requests. Deleting a memory immediately removes it from game planning too.
class CedarGameArrangementStore {
  CedarGameArrangementStore(this.db);
  final AppDatabase db;
  static const tag = 'cedar_game_arrangement_v1';
  static const metadataKey = 'cedar_game_arrangement_v1';
  static const instruction = '''
游戏口头安排：在同一次整理中返回 game_arrangements 数组，和 memories 分开处理。
只保留对真实游戏有后续意义的明确打算/双方约定/用户要求，包括 AI 自己明确提出的计划；玩笑、摆姿态、假设、已发生操作的复述不创建安排。
从【真实游戏与既有安排】选择真实 scope_id，不能猜游戏、存档或盆号；模糊的“正中间”保留为想法，不捏造坐标。
每项字段：action=remember/update/cancel，scope_id，topic_key（稳定英文小写主题，1～60字符，只用a-z、0-9、下划线、点或连字符），text（具体安排），condition（等待用户/条件等，可空），completion_basis=action/state（亲自操作选action，只查看或等待某状态选state），actor=user/ai/shared（谁提出/持有约定），executor=ai/user/shared/unknown（谁执行目标），user_quote，assistant_quote，target_id（update/cancel必须为既有ID）。
user安排须逐字user_quote；ai自己的打算须逐字assistant_quote；shared双方约定须两边逐字引文。用户要求只能由用户的新明确说法取消或改约；AI可以调整自己的计划。一次明确同意发生了，不代表未来游戏操作已经完成。结合当时已有真实进度区分操作复述和新计划，已经做过的操作不重复变成待做；明确约定下一次再做仍可保留。游戏安排不重复写入 threads/thoughts，也不因此安排定时跟进；另有需要讨论的具体问题才单独记录。
只处理本轮真实新增/改约，不从旧经历、旧操作补造约定；每轮最多2项。不要在 memories 重复创建或修改系统标记的游戏安排。没有适合内容返回 []。''';

  static Map<String, dynamic> metadata(MemoryItem item) =>
      _map(MemorySourceContext.decode(item.sourceContextJson)[metadataKey]);
  static bool isArrangement(MemoryItem item) => item.tags.contains(tag) && metadata(item)['version'] == 1;
  static BrainWorkFence? _fence(Object? raw) {
    final m=_map(raw), a=_map(_map(raw)['identity']), b=_map(_map(raw)['settings']);
    if(m.isEmpty || a.isEmpty || [...a.values,...b.values].any((v)=>v is! String)) return null;
    return BrainWorkFence(identity:a.cast<String,String>(),expectedSettings:b.cast<String,String>());
  }
  Future<CedarToyActivityState> _state(DatabaseExecutor txn) async =>
      CedarToyActivityState.fromJson(_json(await BrainWorkFence.value(txn,CedarToyActivityStore.stateSettingKey)));
  Future<bool> _validSource(DatabaseExecutor txn, MemoryItem item) async {
    if (!isArrangement(item) || !item.sourceValid || item.status != 'active') return false;
    final m=metadata(item);
    final u=QualifiedConversationSource.fromJson(m['user_source']);
    final a=QualifiedConversationSource.fromJson(m['assistant_source']);
    if(u?.isOrdinary!=true||a?.isOrdinary!=true||!await u!.matches(txn)||!await a!.matches(txn))return false;
    final origin=_map(m['origin_sources']);
    if(origin.isEmpty)return true;
    final ou=QualifiedConversationSource.fromJson(origin['user_source']), oa=QualifiedConversationSource.fromJson(origin['assistant_source']);
    return ou?.isOrdinary==true&&oa?.isOrdinary==true&&await ou!.matches(txn)&&await oa!.matches(txn);
  }
  Future<List<MemoryItem>> _items(DatabaseExecutor txn) async =>
      (await txn.query('memory_items',where:"status = 'active' AND source_valid = 1 AND fact_state = 'ongoing' AND tags LIKE ?",
        whereArgs:['%$tag%'],orderBy:'updated_at DESC',limit:40)).map(MemoryItem.fromDb).toList();

  Future<CedarArrangementExtraction?> captureExtraction(BrainWorkFence fence, DateTime at) =>
    db.readSourceSnapshot(workFence:fence,read:(txn) async {
      final state=await _state(txn);
      final scopes=state.sessions.values.map((s)=>CedarArrangementScope.current(s,at:at)).whereType<CedarArrangementScope>().toList();
      final items=<MemoryItem>[];
      for(final item in await _items(txn)) {
        if(items.length>=8)break;
        if(scopes.any((s)=>metadata(item)['scope_id']==s.id) && await _validSource(txn,item))items.add(item);
      }
      final facts=<Map<String,Object?>>[for(final s in state.sessions.values)
        for(final e in s.events) if(e.kind=='outcome'&&!e.createdAt.isAfter(at)&&CedarGameResultPolicy.succeeded(e.summary))
          {'game':s.gameId,'at':e.createdAt.millisecondsSinceEpoch,'action':e.action,'input':e.inputJson,'result':_text(e.summary,600)}]
        ..sort((a,b)=>(b['at'] as int).compareTo(a['at'] as int));
      return CedarArrangementExtraction(scopes,items,fence,facts.take(4).toList());
    });

  Future<int> applyExtraction(Object? proposals, {required Object? localContext,
    required Object? localTimeSources, required ChatMessage user, required ChatMessage assistant, bool knowledgeReferenceActive = false}) async {
    if(proposals is! List)return 0;
    final local=_map(localContext), sources=_map(localTimeSources);
    final fence=_fence(local['fence']);
    final u=QualifiedConversationSource.fromJson(sources['user']), a=QualifiedConversationSource.fromJson(sources['assistant']);
    if(local['version']!=1 || fence==null || u==null || a==null || !u.isOrdinary || !a.isOrdinary ||
      u.stamp.id!=user.id || a.stamp.id!=assistant.id ||
      ConversationSourceStore.messageHash(user)!=u.stamp.contentHash || ConversationSourceStore.messageHash(assistant)!=a.stamp.contentHash)return 0;
    final scopes=[for(final r in local['scopes'] is List ? local['scopes'] as List : const [])
      if(CedarArrangementScope.fromJson(r) case final s?) s];
    final targets=_map(local['targets']);
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await fence.matches(txn) || !await u.matches(txn) || !await a.matches(txn))return 0;
      final live=await _state(txn);var accepted=0;
      for(final raw in proposals.take(2)) {
        final p=_map(raw), action=p['action'], actor=p['actor'];
        if(!const {'remember','update','cancel'}.contains(action) || !const {'user','ai','shared'}.contains(actor))continue;
        final scope=scopes.where((s)=>s.id==p['scope_id']).firstOrNull;
        if(scope==null || live.sessions[scope.game]==null || !scope.matchesSession(live.sessions[scope.game]!))continue;
        final uq=_text(p['user_quote'],500), aq=_text(p['assistant_quote'],500);
        final userProof=uq.length>=2 && user.content.contains(uq);
        final aiProof=aq.length>=2 && assistant.content.contains(aq);
        if(knowledgeReferenceActive&&!userProof)continue;
        if((actor=='user'&&!userProof)||(actor=='ai'&&!aiProof)||(actor=='shared'&&(!userProof||!aiProof)))continue;
        final target=_text(p['target_id'],100), captured=_map(targets[target]);
        MemoryItem? old;
        if(action!='remember') {
          final snapshot=MemoryRevisionSnapshot.decode(captured['snapshot']);
          final rows=await txn.query('memory_items',where:'id = ?',whereArgs:[target],limit:1);
          if(snapshot==null||rows.isEmpty)continue;
          old=MemoryItem.fromDb(rows.single);
          if(old.pinned||old.factState!='ongoing'||!snapshot.matches(old)||!await _validSource(txn,old)||metadata(old)['scope_id']!=scope.id)continue;
          if(old.actorKey!='ai'&&!userProof)continue;
          final changeAt=old.actorKey=='ai'?a.stamp.observedAt:u.stamp.observedAt;
          if(changeAt.millisecondsSinceEpoch<=((metadata(old)['formed_at'] as num?)?.toInt()??changeAt.millisecondsSinceEpoch))continue;
        } else if(target.isNotEmpty) { continue; }
        final text=_text(p['text'],700), condition=_text(p['condition'],300);
        final topic=_text(p['topic_key'],60).toLowerCase();
        if(text.isEmpty||!RegExp(r'^[a-z0-9_.-]{1,60}$').hasMatch(topic))continue;
        final authority=old!=null&&old.actorKey!='ai'?old.actorKey:actor;
        final formedAt=authority=='user'?u.stamp.observedAt:a.stamp.observedAt;
        final meta=<String,Object?>{'version':1,'scope_id':scope.id,'scope':scope.toJson(),
          'condition':condition,'completion_basis':p['completion_basis']=='state'?'state':'action','executor':const {'ai','user','shared'}.contains(p['executor'])?p['executor']:'unknown','formed_at':formedAt.millisecondsSinceEpoch,
          'user_source':u.toJson(),'assistant_source':a.toJson()};
        if(old==null) {
          final receipt='cedar_game_arrangement_applied_v1:${_digest([assistant.id,a.stamp.revision,scope.id,topic])}';
          if((await BrainWorkFence.value(txn,receipt)).isNotEmpty)continue;
          if((await txn.query('memory_items',columns:['id'],where:'source = ? AND subject_key = ?',
            whereArgs:['game_arrangement:${assistant.id}@r${a.stamp.revision}','game_plan.${scope.id.substring(0,12)}.$topic'],limit:1)).isNotEmpty)continue;
          if((await _items(txn)).any((m)=>metadata(m)['scope_id']==scope.id && m.subjectKey=='game_plan.${scope.id.substring(0,12)}.$topic'))continue;
          final inserted=await db.insertMemory(kind:'shared_experience',content:text,importance:.64,confidence:.9,
            isolateSourceIdentity:true,tags:const [tag],source:'game_arrangement:${assistant.id}@r${a.stamp.revision}',
            subjectKey:'game_plan.${scope.id.substring(0,12)}.$topic',topicKey:'game_plan.${scope.game}',
            semanticType:'shared_experience',actorKey:actor as String,ownerKey:actor,
            relationKey:'plans',objectKey:'game.${scope.game}.slot_${scope.slot}',temporalScope:'scheduled',
            factState:'ongoing',attentionState:'snoozed',recallPolicy:'contextual',spontaneousSalience:0,
            sourceUserMessageId:user.id,sourceAssistantMessageId:assistant.id,
            sourceContextJson:jsonEncode({...MemorySourceContext.decode(MemorySourceContext.capture(user,assistant)),metadataKey:meta}),
            sourceObservedAt:formedAt,sourceGuard:(_) async=>await fence.matches(txn)&&await u.matches(txn)&&await a.matches(txn),transaction:txn);
          if(inserted) {
            // Generic prose completion checks cannot settle a future goal such
            // as ‘种下后完成’. Only the real-result review below can do that.
            await txn.update('memory_items',{'fact_state':'ongoing','attention_state':'snoozed',
              'recall_policy':'contextual','spontaneous_salience':0.0,'lifecycle_source':'game_arrangement_source_v1'},
              where:'source = ? AND subject_key = ?',
              whereArgs:['game_arrangement:${assistant.id}@r${a.stamp.revision}','game_plan.${scope.id.substring(0,12)}.$topic']);
            await txn.insert('settings',{'key':receipt,'value':'1'},conflictAlgorithm:ConflictAlgorithm.replace);
            accepted++;
          }
        } else {
          final cancelled=action=='cancel';
          // The original source remains part of the authority chain after a change.
          meta['origin_sources']=metadata(old)['origin_sources'] ?? {'user_source':metadata(old)['user_source'],'assistant_source':metadata(old)['assistant_source']};
          await txn.update('memory_items',{'content':cancelled?'已取消的游戏安排：${old.content}':text,
            'source_context_json':jsonEncode({...MemorySourceContext.decode(old.sourceContextJson),metadataKey:meta}),
            'fact_state':cancelled?'cancelled':'ongoing','attention_state':cancelled?'closed':'snoozed',
            'actor_key':authority,'owner_key':authority,'fact_version':old.factVersion+1,'updated_at':DateTime.now().millisecondsSinceEpoch},where:'id = ?',whereArgs:[old.id]);
          accepted++;
        }
      }
      return accepted;
    });
  }

  static bool successfulReceipt(CedarGameEvent event) {
    if(event.kind!='outcome'||event.summary.trim().isEmpty||event.summary=='远端没有返回可展示的内容。'||
      CedarPlatformActionPolicy.isPlatformAction(event.action)||CedarSaveSlotPolicy.isNewOrResetAction(event.action))return false;
    return CedarGameResultPolicy.succeeded(event.summary);
  }

  Future<CedarArrangementReviewBundle> captureReview(CedarGameSession session) async {
    final fence=await db.captureBrainWorkFence(settingKeys:const ['conversation_context_reset_at','conversation_context_reset_count',
      CedarToyActivityStore.controlRevisionKey,CedarToyActivityStore.userControlRevisionKey]);
    if(fence==null)return const CedarArrangementReviewBundle();
    return await db.readSourceSnapshot(workFence:fence,read:(txn) async {
      final state=await _state(txn);
      final live=state.activeGameId==session.gameId?state.sessions[session.gameId]:null;
      final scope=live==null?null:CedarArrangementScope.current(live);
      if(live==null||scope==null||live.id!=session.id)return const CedarArrangementReviewBundle();
      final items=<MemoryItem>[];
      for(final m in await _items(txn)) {
        if(items.length>=4)break;
        if(metadata(m)['scope_id']==scope.id&&await _validSource(txn,m))items.add(m);
      }
      final events=live.events.where(successfulReceipt).where((e)=>CedarArrangementScope.slotFor(live,_json(e.inputJson))==scope.slot)
        .toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
      return CedarArrangementReviewBundle(scope:scope,items:items,events:events.take(8).toList(),fence:fence);
    }) ?? const CedarArrangementReviewBundle();
  }
  Future<int> completeReviewed(CedarArrangementReviewBundle bundle, Object? reviews) async {
    if(reviews is! List||bundle.fence==null||bundle.scope==null)return 0;
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await bundle.fence!.matches(txn))return 0;
      final live=(await _state(txn)).sessions[bundle.scope!.game];
      if(live==null||CedarArrangementScope.current(live)?.id!=bundle.scope!.id)return 0;
      var count=0;
      for(final raw in reviews.take(4)) {
        final p=_map(raw), item=bundle.items.where((m)=>m.id==p['id']).firstOrNull;
        final event=bundle.events.where((e)=>e.id==p['event_id']).firstOrNull;
        if(item==null||event==null||item.pinned||!const {'ai','shared'}.contains(metadata(item)['executor'])||
          (metadata(item)['executor']=='shared'&&(!live.mode.supportsSharedParticipation||!live.invitationApproved))||event.createdAt.millisecondsSinceEpoch<=((metadata(item)['formed_at'] as num?)?.toInt()??event.createdAt.millisecondsSinceEpoch))continue;
        final currentEvent=live.events.where((e)=>e.id==event.id).firstOrNull;
        if(currentEvent==null||!successfulReceipt(currentEvent)||_digest(currentEvent.toJson())!=_digest(event.toJson()))continue;
        final command=_json(currentEvent.inputJson)['command'];
        final inner=command is String?command.trim().split(RegExp(r'\s+')).first:'';
        if(metadata(item)['completion_basis']!='state'&&(CedarPlatformActionPolicy.isReadOnly(currentEvent.action)||
          (currentEvent.action=='cmd'&&CedarPlatformActionPolicy.isReadOnly(inner))))continue;
        final rows=await txn.query('memory_items',where:'id = ?',whereArgs:[item.id],limit:1);
        if(rows.isEmpty)continue;
        final current=MemoryItem.fromDb(rows.single);
        if(current.factState!='ongoing'||!MemoryRevisionSnapshot.capture(item).matches(current)||!await _validSource(txn,current))continue;
        final data=MemorySourceContext.decode(current.sourceContextJson);
        data[metadataKey]={...metadata(current),'completion':{'kind':'verified_game_result','event_id':event.id,
          'at':event.createdAt.millisecondsSinceEpoch,'action':event.action,'input':event.inputJson,'result':event.summary}};
        await txn.update('memory_items',{'content':'已履行此前的游戏安排：${current.content}','fact_state':'completed','attention_state':'closed',
          'source_context_json':jsonEncode(data),'updated_at':DateTime.now().millisecondsSinceEpoch,
          'fact_version':current.factVersion+1},where:'id = ?',whereArgs:[current.id]);count++;
      }
      return count;
    });
  }
}
