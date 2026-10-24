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
  static String slotForEvent(CedarGameSession session, CedarGameEvent event) {
    if (!CedarSaveSlotPolicy.supportsFiveSlots(session.guide)) return 'session';
    final input = event.submittedIdentity;
    return input == null ? '' : slotFor(session, Map<String,dynamic>.from(input));
  }
  static CedarArrangementScope? current(CedarGameSession session, {DateTime? at}) {
    final events = session.events.where((e) => e.kind == 'outcome' && CedarGameResultPolicy.succeeded(e.summary) && e.action.isNotEmpty &&
      !CedarPlatformActionPolicy.isPlatformAction(e.action)).toList()
      ..sort((a,b) => b.createdAt.compareTo(a.createdAt));
    final event = events.where((e) => at == null || !e.createdAt.isAfter(at)).firstOrNull;
    if (event == null) return null;
    final slot = slotForEvent(session, event);
    if (slot.isEmpty) return null;
    // A delayed extractor cannot bind an old utterance to a later new/import.
    if (at != null && events.any((e) => e.createdAt.isAfter(at) &&
        CedarSaveSlotPolicy.isNewOrResetAction(e.action) && (slotForEvent(session, e) == slot || slotForEvent(session, e).isEmpty))) return null;
    return CedarArrangementScope(session.gameId, session.displayName, session.id, slot,
      session.arrangementSaveEpochs[slot] ?? 'legacy:${session.id}:$slot');
  }
  bool matchesSession(CedarGameSession value) => value.gameId == game && value.id == session &&
      (value.arrangementSaveEpochs[slot] ?? 'legacy:${value.id}:$slot') == epoch;
}

/// Separate from ordinary memories/Thoughts. One bounded settings row per note
/// participates in the existing full archive; a deleted row retains a tombstone.
class CedarGameNote {
  CedarGameNote(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get content => data['text'] as String? ?? '';
  String get actorKey => data['actor'] as String? ?? 'ai';
  String get factState => data['state'] as String? ?? 'ongoing';
  String get topic => data['topic'] as String? ?? '';
  bool get persistent => data['lifetime'] == 'persistent';
  String get snapshot => _digest(data);
  Map<String, dynamic> get metadata => _map(data['metadata']);
}

class CedarArrangementExtraction {
  const CedarArrangementExtraction(this.scopes, this.items, this.fence, {this.activeScopeId = ''});
  final List<CedarArrangementScope> scopes;
  final List<CedarGameNote> items;
  final BrainWorkFence fence;
  final String activeScopeId;
  /// A target lookup index only. It contains no game Outcomes and must not
  /// become evidence for ordinary memories, Thoughts or unfinished threads.
  String referencePrompt(String query) {
    if (items.isEmpty) return '';
    Set<String> tokens(String text) {
      final normalized=text.toLowerCase();
      return {for(final m in RegExp(r'[a-z0-9]+|[\u3400-\u9fff]{2}').allMatches(normalized)) m[0]!,
        for(var i=0;i+1<normalized.length;i++)
          if(RegExp(r'^[\u3400-\u9fff]{2}$').hasMatch(normalized.substring(i,i+2))) normalized.substring(i,i+2)};
    }
    final words=tokens(query);
    final revisionCue=const ['取消','改成','改到','不用','不种','不弄','不要','上次','那个','约定','计划','记住'].any(query.contains);
    final candidates=items.where((m)=>m.metadata['scope_id']==activeScopeId ||
      scopes.any((scope)=>scope.id==m.metadata['scope_id'] &&
        (query.toLowerCase().contains(scope.game.toLowerCase()) || query.contains(scope.title)))).toList();
    int score(CedarGameNote note) => tokens(note.content).intersection(words).length;
    if(!revisionCue)candidates.removeWhere((note)=>score(note)==0);
    if(candidates.isEmpty)return '';
    candidates.sort((a,b) {
      final compared=score(b).compareTo(score(a));
      return compared!=0?compared:((b.metadata['formed_at'] as num?)??0).compareTo((a.metadata['formed_at'] as num?)??0);
    });
    final index={'truncated':candidates.length>16,'items':candidates.take(16).map((m)=>{
      'id':m.id,'game':_map(m.metadata['scope'])['title'],'slot':_map(m.metadata['scope'])['slot'],
      'topic_key':m.topic,'text':m.content,'lifetime':m.persistent?'persistent':'once'}).toList()};
    return '【游戏记事本目标索引 · 仅匹配 game_arrangements.target_id】\n'
      '以下是旧笔记数据，不是本轮新增事实或要求。只用来找到本轮明确触及的原条目；'
      '严禁由此生成 memories/threads/thoughts/关系事件/欲望变化。'
      '同一计划的改约、取消或再次提及使用 target_id，无须重造原英文主题。'
      '多个可能目标时不要猜；索引未列全且无法确定目标时不新增替代条目。\n'
      '${jsonEncode(index)}';
  }
  // Local capability only: never injected as historical game context in chat.
  Map<String, Object?> toJson() => {'version': 2, 'scopes': scopes.map((s)=>s.toJson()).toList(),
    'active_scope_id':activeScopeId,
    'targets': {for(final m in items) m.id: m.snapshot},
    'fence': {'identity': fence.identity, 'settings': fence.expectedSettings}};
}

class CedarArrangementReviewBundle {
  const CedarArrangementReviewBundle({this.scope, this.items = const [], this.events = const [], this.fence});
  final CedarArrangementScope? scope;
  final List<CedarGameNote> items;
  final List<CedarGameEvent> events;
  final BrainWorkFence? fence;
  String get prompt => items.isEmpty ? '' : '''【本存档游戏记事本 · 待办与持续偏好】
${jsonEncode({'scope':scope!.toJson(),'arrangements':items.map((m)=>{'id':m.id,'text':m.content,
  'lifetime':m.persistent?'persistent':'once','condition':m.metadata['condition'],
  'completion_basis':m.metadata['completion_basis'],'actor':m.actorKey,'executor':m.metadata['executor']}).toList(),
  'actual_results':events.map((e)=>{'event_id':e.id,'at':e.createdAt.millisecondsSinceEpoch,
    'action':e.action,'input':e.inputJson,'result':_text(e.summary,1200),'actor':'companion'}).toList()})}
结合真实局面考虑这些安排，不因它们存在就重复购买、重开或强行执行；用户停止/邀请/存档权限始终优先。
读取、进入游戏、准备执行或被中断都不算完成。persistent为持续偏好/限制，一次遵守不能清除；once才可核验归档。
已有真实成功结果确实实现某个具体目标时，才在 arrangement_reviews_json 填入 [{"id":"该安排ID","event_id":"对应已发生结果ID"}]。
核对结果是否晚于该安排、对象和条件是否相同；失败、提到游戏、未来打算和当前准备执行的动作都不是完成证据。只读结果可以证明确实查看或所见状态，不能证明亲自种植、购买或共同游玩；action类目标必须有对应真实写操作。
用户让留给自己操作的安排不能由助手擅自操作冒充履约。不确定时返回空数组，保留安排供以后参考。''';
}

class CedarGameArrangementStore {
  CedarGameArrangementStore(this.db);
  final AppDatabase db;
  static const tag = 'cedar_game_arrangement_v1'; // +354 migration identity.
  static const metadataKey = 'cedar_game_arrangement_v1';
  static const notePrefix = 'cedar_game_notebook_v1:';
  static const deletionRevisionKey = 'cedar_game_notebook_delete_revision_v1';
  static const planningRevisionKey = 'cedar_game_notebook_planning_revision_v1';
  static const instruction = '''
游戏记事本：在同一次整理中返回 game_arrangements 数组，和 memories 分开处理。只根据【刚发生的对话】提取本轮明确新增/改约/取消的游戏打算、双方约定或用户要求，包括AI明确提出的计划和持续游戏偏好/限制。玩笑、假设、已发生操作的复述不创建待办；不从旧经历补造约定，不猜坐标、存档或盆号。
每项字段：action=remember/update/cancel，target_id（改约、取消或同一计划再次提及时复用目标索引中的ID；新计划为空），game（本轮明确提及的游戏名称或ID，没有则空字符串；手机只在能唯一匹配真实当前存档时接受），topic_key（稳定英文小写主题，1～60字符，a-z、0-9、下划线、点、连字符），text（具体内容），condition（条件，可空），lifetime=once/persistent（一次目标/持续偏好或限制），completion_basis=action/state，actor=user/ai/shared，executor=ai/user/shared/unknown，user_quote，assistant_quote。改约/取消优先绑定原条目target_id；topic_key只给新计划命名，旧主题无需重新猜测。无法确定对应哪条不猜测。
user安排须逐字user_quote，ai计划须逐字assistant_quote，shared须双方逐字引文；用户要求只能由用户新明确说法取消或改约。明确同意不代表未来操作已完成。本轮明确约定下一次再做可保留。游戏安排不重复写入 memories/threads/thoughts，不因此定时跟进；另有本轮真正想讨论的问题才单独记念头。每轮最多2项，没有适合内容返回 []。
''';

  static Map<String, dynamic> metadata(Object item) => item is CedarGameNote ? item.metadata :
      item is MemoryItem ? _map(MemorySourceContext.decode(item.sourceContextJson)[metadataKey]) : {};
  static bool isArrangement(MemoryItem item) => item.tags.contains(tag) && metadata(item)['version'] == 1;
  static BrainWorkFence? _fence(Object? raw) {
    final m=_map(raw), a=_map(_map(raw)['identity']), b=_map(_map(raw)['settings']);
    if(m.isEmpty || a.isEmpty || [...a.values,...b.values].any((v)=>v is! String)) return null;
    return BrainWorkFence(identity:a.cast<String,String>(),expectedSettings:b.cast<String,String>());
  }
  Future<CedarToyActivityState> _state(DatabaseExecutor txn) async =>
      CedarToyActivityState.fromJson(_json(await BrainWorkFence.value(txn,CedarToyActivityStore.stateSettingKey)));
  Future<bool> _validMetadata(DatabaseExecutor txn, Map<String,dynamic> m) async {
    final u=QualifiedConversationSource.fromJson(m['user_source']), a=QualifiedConversationSource.fromJson(m['assistant_source']);
    if(u?.isOrdinary!=true||a?.isOrdinary!=true||!await u!.matches(txn)||!await a!.matches(txn))return false;
    final origin=_map(m['origin_sources']);
    if(origin.isEmpty)return true;
    final ou=QualifiedConversationSource.fromJson(origin['user_source']), oa=QualifiedConversationSource.fromJson(origin['assistant_source']);
    return ou?.isOrdinary==true&&oa?.isOrdinary==true&&await ou!.matches(txn)&&await oa!.matches(txn);
  }
  Future<List<CedarGameNote>> _items(DatabaseExecutor txn) async {
    final rows=await txn.query('settings',columns:['value'],where:'key >= ? AND key < ?',
      whereArgs:[notePrefix,'$notePrefix\uffff']);
    final notes=[for(final row in rows) if(_json(row['value'] as String)['id'] is String)
      CedarGameNote(_json(row['value'] as String))];
    notes.sort((a,b)=>((b.metadata['formed_at'] as num?)??0).compareTo((a.metadata['formed_at'] as num?)??0));
    return notes;
  }
  Future<CedarGameNote?> _get(DatabaseExecutor txn,String id) async {
    final data=_json(await BrainWorkFence.value(txn,'$notePrefix$id'));
    return data['id']==id?CedarGameNote(data):null;
  }
  Future<void> _put(DatabaseExecutor txn,CedarGameNote note) => txn.insert('settings',
    {'key':'$notePrefix${note.id}','value':jsonEncode(note.data)},conflictAlgorithm:ConflictAlgorithm.replace).then((_){});

  Future<void> _advancePlanningRevision(DatabaseExecutor txn) async {
    final revision=int.tryParse(await BrainWorkFence.value(txn,planningRevisionKey))??0;
    await txn.insert('settings',{'key':planningRevisionKey,'value':'${revision+1}'},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  /// Safe on foreground/background reads and after importing an older archive.
  /// Never synthesizes notes from old game Outcomes or already deleted memories.
  Future<int> migrateLegacy() async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await BrainWorkFence.workAllowed(txn))return 0;
      final rows=await txn.query('memory_items',where:"status = 'active' AND tags LIKE ?",whereArgs:['%$tag%']);
      var count=0;
      for(final row in rows) {
        final old=MemoryItem.fromDb(row);
        if(!isArrangement(old))continue;
        if(old.sourceValid&&await _validMetadata(txn,metadata(old))&&await _get(txn,old.id)==null) {
          await _put(txn,CedarGameNote({'id':old.id,'text':old.content,'actor':old.actorKey,
            'state':old.factState,'topic':old.subjectKey.split('.').skip(2).join('.'),
            'lifetime':'once','metadata':metadata(old),'version':old.factVersion,'legacy':true}));
          count++;
        }
        // Archive the original instead of rewriting its fact/completion claims.
        await txn.update('memory_items',{'status':'archived','lifecycle_source':'game_notebook_migration_v1'},
          where:'id = ?',whereArgs:[old.id]);
      }
      if(count>0)await _advancePlanningRevision(txn);
      return count;
    });
  }
  Future<List<CedarGameNote>> notes({bool includeArchived=false}) async {
    await migrateLegacy();
    final sql=await db.database;
    return sql.transaction((txn) async {
      final out=<CedarGameNote>[];
      for(final note in await _items(txn)) {
        if(note.factState=='deleted'||(!includeArchived&&note.factState!='ongoing'))continue;
        if(await _validMetadata(txn,note.metadata))out.add(note);
      }
      return out;
    });
  }
  Future<bool> deleteNote(String id) async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      // A user can delete while the companion is paused; transfer/recovery
      // still owns the database exclusively.
      if(await BrainWorkFence.value(txn,'transfer_lock')=='1'||
        (await BrainWorkFence.value(txn,'snapshot_recovery_pending_v1')).isNotEmpty)return false;
      final note=await _get(txn,id);
      if(note==null)return false;
      // Tombstone blocks cached extraction and legacy migration resurrection.
      await _put(txn,CedarGameNote({'id':id,'state':'deleted','version':(note.data['version'] as num? ?? 0).toInt()+1}));
      final revision=int.tryParse(await BrainWorkFence.value(txn,deletionRevisionKey))??0;
      await txn.insert('settings',{'key':deletionRevisionKey,'value':'${revision+1}'},conflictAlgorithm:ConflictAlgorithm.replace);
      await _advancePlanningRevision(txn);
      return true;
    });
  }

  Future<CedarArrangementExtraction?> captureExtraction(BrainWorkFence fence, DateTime at) async {
    await migrateLegacy();
    return db.readSourceSnapshot(workFence:fence,read:(txn) async {
      final state=await _state(txn);
      final scopes=state.sessions.values.map((s)=>CedarArrangementScope.current(s,at:at)).whereType<CedarArrangementScope>().toList();
      final items=<CedarGameNote>[];
      for(final item in await _items(txn)) {
        if(item.factState=='ongoing'&&scopes.any((s)=>item.metadata['scope_id']==s.id)&&await _validMetadata(txn,item.metadata))items.add(item);
      }
      final active=scopes.where((s)=>s.game==state.activeGameId).firstOrNull;
      final noteFence=BrainWorkFence(identity:fence.identity,leaseKey:fence.leaseKey,leaseToken:fence.leaseToken,
        expectedSettings:{...fence.expectedSettings,deletionRevisionKey:await BrainWorkFence.value(txn,deletionRevisionKey)});
      return CedarArrangementExtraction(scopes,items,noteFence,activeScopeId:active?.id??'');
    });
  }

  Future<int> applyExtraction(Object? proposals, {required Object? localContext,
    required Object? localTimeSources, required ChatMessage user, required ChatMessage assistant, bool knowledgeReferenceActive = false}) async {
    if(proposals is! List)return 0;
    final local=_map(localContext), sources=_map(localTimeSources);
    final fence=_fence(local['fence']);
    final u=QualifiedConversationSource.fromJson(sources['user']), a=QualifiedConversationSource.fromJson(sources['assistant']);
    if(local['version']!=2 || fence==null || u==null || a==null || !u.isOrdinary || !a.isOrdinary ||
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
        final named=_text(p['game'],100).toLowerCase();
        // Name must itself occur in the current source pair; an empty name is
        // only bound to the captured active save, never to the last arbitrary game.
        if(named.isNotEmpty&&!('${user.content}\n${assistant.content}'.toLowerCase().contains(named)))continue;
        final candidates=scopes.where((s)=>p['scope_id']!=null ? s.id==p['scope_id'] :
          named.isEmpty?s.id==local['active_scope_id']:s.game.toLowerCase()==named||s.title.toLowerCase()==named).toList();
        if(candidates.length!=1)continue;
        final scope=candidates.single;
        if(live.sessions[scope.game]==null || !scope.matchesSession(live.sessions[scope.game]!))continue;
        final uq=_text(p['user_quote'],500), aq=_text(p['assistant_quote'],500);
        final userProof=uq.length>=2 && user.content.contains(uq), aiProof=aq.length>=2 && assistant.content.contains(aq);
        if(knowledgeReferenceActive&&!userProof)continue;
        if((actor=='user'&&!userProof)||(actor=='ai'&&!aiProof)||(actor=='shared'&&(!userProof||!aiProof)))continue;
        final text=_text(p['text'],700), condition=_text(p['condition'],300), topic=_text(p['topic_key'],60).toLowerCase();
        if(text.isEmpty||!RegExp(r'^[a-z0-9_.-]{1,60}$').hasMatch(topic))continue;
        final all=await _items(txn);
        final same=<CedarGameNote>[];
        for(final note in all) {
          if(note.factState=='ongoing'&&note.metadata['scope_id']==scope.id&&note.topic==topic&&
            await _validMetadata(txn,note.metadata))same.add(note);
        }
        final target=_text(p['target_id'],100);
        CedarGameNote? old;
        // Chat receives no historical notebook body. A new source may describe
        // the same plan as `remember`; bind a unique current topic as an update
        // with exactly the same captured-version/authority checks.
        final operation=action=='remember'&&(target.isNotEmpty||same.length==1)?'update':action;
        if(operation!='remember') {
          final choices=target.isNotEmpty?all.where((m)=>m.id==target).toList():same;
          if(choices.length!=1)continue;
          old=choices.single;
          if(old.factState!='ongoing'||targets[old.id]!=old.snapshot||!await _validMetadata(txn,old.metadata)||old.metadata['scope_id']!=scope.id)continue;
          if(old.actorKey!='ai'&&!userProof)continue;
          final changeAt=old.actorKey=='ai'?a.stamp.observedAt:u.stamp.observedAt;
          if(changeAt.millisecondsSinceEpoch<=((old.metadata['formed_at'] as num?)?.toInt()??changeAt.millisecondsSinceEpoch))continue;
        } else if(target.isNotEmpty||same.isNotEmpty) {continue;}
        final authority=old!=null&&old.actorKey!='ai'?old.actorKey:actor;
        final formedAt=authority=='user'?u.stamp.observedAt:a.stamp.observedAt;
        final meta=<String,Object?>{'version':1,'scope_id':scope.id,'scope':scope.toJson(),
          'condition':condition,'completion_basis':p['completion_basis']=='state'?'state':'action',
          'executor':const {'ai','user','shared'}.contains(p['executor'])?p['executor']:'unknown',
          'formed_at':formedAt.millisecondsSinceEpoch,'user_source':u.toJson(),'assistant_source':a.toJson()};
        if(old==null) {
          final receipt='cedar_game_arrangement_applied_v1:${_digest([assistant.id,a.stamp.revision,scope.id,topic])}';
          if((await BrainWorkFence.value(txn,receipt)).isNotEmpty)continue;
          final id=_digest([assistant.id,a.stamp.revision,scope.id,topic]);
          if(await _get(txn,id)!=null)continue;
          await _put(txn,CedarGameNote({'id':id,'text':text,'actor':actor,'topic':topic,'state':'ongoing',
            'lifetime':p['lifetime']=='persistent'?'persistent':'once','metadata':meta,'version':1}));
          await txn.insert('settings',{'key':receipt,'value':'1'},conflictAlgorithm:ConflictAlgorithm.replace);
        } else {
          meta['origin_sources']=old.metadata['origin_sources']??{'user_source':old.metadata['user_source'],'assistant_source':old.metadata['assistant_source']};
          await _put(txn,CedarGameNote({...old.data,'text':operation=='cancel'?old.content:text,
            'state':operation=='cancel'?'cancelled':'ongoing','actor':authority,'metadata':meta,
            'lifetime':p['lifetime']=='persistent'?'persistent':p['lifetime']=='once'?'once':old.data['lifetime'],
            'version':(old.data['version'] as num).toInt()+1}));
        }
        accepted++;
      }
      if(accepted>0)await _advancePlanningRevision(txn);
      return accepted;
    });
  }

  static bool successfulReceipt(CedarGameEvent event) {
    if(event.kind!='outcome'||event.summary.trim().isEmpty||event.summary=='远端没有返回可展示的内容。'||
      CedarPlatformActionPolicy.isPlatformAction(event.action)||CedarSaveSlotPolicy.isNewOrResetAction(event.action))return false;
    return CedarGameResultPolicy.succeeded(event.summary);
  }
  Future<CedarArrangementReviewBundle> captureReview(CedarGameSession session) async {
    await migrateLegacy();
    final fence=await db.captureBrainWorkFence(settingKeys:const ['conversation_context_reset_at','conversation_context_reset_count',
      CedarToyActivityStore.controlRevisionKey,CedarToyActivityStore.userControlRevisionKey,deletionRevisionKey,planningRevisionKey]);
    if(fence==null)return const CedarArrangementReviewBundle();
    return await db.readSourceSnapshot(workFence:fence,read:(txn) async {
      final state=await _state(txn);
      final live=state.activeGameId==session.gameId?state.sessions[session.gameId]:null;
      final scope=live==null?null:CedarArrangementScope.current(live);
      if(live==null||live.id!=session.id)return const CedarArrangementReviewBundle();
      if(scope==null)return CedarArrangementReviewBundle(fence:fence);
      final items=<CedarGameNote>[];
      for(final m in await _items(txn)) {
        if(m.factState=='ongoing'&&m.metadata['scope_id']==scope.id&&await _validMetadata(txn,m.metadata))items.add(m);
      }
      final events=live.events.where(successfulReceipt).where((e)=>CedarArrangementScope.slotForEvent(live,e)==scope.slot)
        .toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
      // Persistent restrictions are always visible. One-shot tasks have their
      // own rotating budget, so neither newer tasks nor preferences starve them.
      final pending=items.where((m)=>!m.persistent).toList()..sort((a,b)=>a.id.compareTo(b.id));
      final cursorKey='cedar_game_notebook_cursor_v1:${scope.id}';
      final cursor=await BrainWorkFence.value(txn,cursorKey);
      var start=pending.indexWhere((m)=>m.id==cursor);
      if(start<0)start=0;
      final selected=[for(var n=0;n<pending.length&&n<8;n++)pending[(start+n)%pending.length]];
      if(pending.isNotEmpty)await txn.insert('settings',{'key':cursorKey,
        'value':pending[(start+selected.length)%pending.length].id},conflictAlgorithm:ConflictAlgorithm.replace);
      return CedarArrangementReviewBundle(scope:scope,items:[...items.where((m)=>m.persistent),...selected],events:events.take(8).toList(),fence:fence);
    }) ?? const CedarArrangementReviewBundle();
  }
  Future<int> completeReviewed(CedarArrangementReviewBundle bundle, Object? reviews) async {
    if(reviews is! List||bundle.fence==null||bundle.scope==null)return 0;
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await bundle.fence!.matches(txn))return 0;
      final state=await _state(txn);
      final live=state.sessions[bundle.scope!.game];
      if(state.activeGameId!=bundle.scope!.game||live==null||CedarArrangementScope.current(live)?.id!=bundle.scope!.id)return 0;
      var count=0;
      for(final raw in reviews.take(8)) {
        final p=_map(raw), item=bundle.items.where((m)=>m.id==p['id']).firstOrNull;
        final event=bundle.events.where((e)=>e.id==p['event_id']).firstOrNull;
        if(item==null||item.persistent||event==null||!const {'ai','shared'}.contains(item.metadata['executor'])||
          (item.metadata['executor']=='shared'&&(!live.mode.supportsSharedParticipation||!live.invitationApproved))||
          event.createdAt.millisecondsSinceEpoch<=((item.metadata['formed_at'] as num?)?.toInt()??event.createdAt.millisecondsSinceEpoch))continue;
        final currentEvent=live.events.where((e)=>e.id==event.id).firstOrNull;
        if(currentEvent==null||!successfulReceipt(currentEvent)||_digest(currentEvent.toJson())!=_digest(event.toJson()))continue;
        if(item.metadata['completion_basis']!='state' && currentEvent.isReadOnly != false) continue;
        final current=await _get(txn,item.id);
        if(current==null||current.factState!='ongoing'||current.snapshot!=item.snapshot||!await _validMetadata(txn,current.metadata))continue;
        await _put(txn,CedarGameNote({...current.data,'state':'completed','metadata':{...current.metadata,
          'completion':{'kind':'verified_game_result','event_id':event.id,'at':event.createdAt.millisecondsSinceEpoch,
            'action':event.action,'input':event.inputJson,'result':event.summary}},'version':(current.data['version'] as num).toInt()+1}));
        count++;
      }
      return count;
    });
  }
}
