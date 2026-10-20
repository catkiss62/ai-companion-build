import '../ai/jev_decision_gateway.dart';
import '../database/app_database.dart';
import '../model_dialogue/model_dialogue_repository.dart';
import '../model_dialogue/model_dialogue_time.dart';
import 'agent_tool.dart';

/// Short semantic questions share the existing request. They expose read-only
/// capabilities; write authorization remains in the existing task/runtime gates.
class SemanticToolRoute {
  const SemanticToolRoute({this.kind = 'none', this.roomId = '',
    this.roomKind = '', this.view = 'summary', this.phoneSection = 'all',
    this.available = false, this.uncertain = false, this.targetUncertain = false,
    this.singleRead = false, this.multiStep = false, this.candidateKinds = const {},
    this.dateFrom = '', this.dateTo = ''});
  final String kind, roomId, roomKind, view, phoneSection, dateFrom, dateTo;
  final bool available, uncertain, targetUncertain, singleRead, multiStep;
  final Set<String> candidateKinds;
  static const kinds = {'none','room','phone','web','memory','system','rules','album','device','mixed'};
  static const readKinds = {'room','phone','web','memory','system','rules','album','device'};
  Map<String, Object?> toJson() => {'kind':kind, 'room_id':roomId,
    'room_kind':roomKind, 'view':view, 'phone_section':phoneSection,
    'available':available, 'uncertain':uncertain, 'target_uncertain':targetUncertain,
    'single_read':singleRead,'multi_step':multiStep, 'candidate_kinds':candidateKinds.toList(),
    'date_from':dateFrom, 'date_to':dateTo};
  static SemanticToolRoute decode(Object? value) {
    if (value is! Map || !kinds.contains(value['kind'])) return const SemanticToolRoute();
    return SemanticToolRoute(kind:value['kind'] as String? ?? 'none',
      roomId:value['room_id'] as String? ?? '', roomKind:value['room_kind'] as String? ?? '',
      view:value['view'] as String? ?? 'summary', phoneSection:value['phone_section'] as String? ?? 'all',
      available:value['available'] == true || !value.containsKey('available') && readKinds.contains(value['kind']), uncertain:value['uncertain'] == true,
      targetUncertain:value['target_uncertain'] == true || value['kind']=='room' && (value['room_id'] as String? ?? '').isEmpty, singleRead:value['single_read'] == true, multiStep:value['multi_step'] == true || value['kind']=='mixed',
      candidateKinds:(value['candidate_kinds'] as List?)?.whereType<String>().where(readKinds.contains).toSet() ?? const {},
      dateFrom:value['date_from'] as String? ?? '', dateTo:value['date_to'] as String? ?? '');
  }
  static Set<String> idsFor(String kind) => switch (kind) {
    'room' => {'room_history.search','room_history.read'},
    'phone' => {'phone.search','phone.read'},
    'web' => {'public_web.search','public_web.read'},
    'memory' => {'memory.search','room_history.search','room_history.read'},
    'system' => {'system_self.read'}, 'rules' => {'rules.read'},
    'album' => {'album.search'}, 'device' => {'device_context.read'}, _ => {},
  };
  bool get needsTools => kind != 'none' || uncertain && candidateKinds.isNotEmpty;
  Set<String> get toolIds => {
    ...idsFor(kind),
    if (uncertain) ...candidateKinds.expand(idsFor),
    // Only actual multi-step tool tasks get the broader read-only menu.
    if (kind == 'mixed' || needsTools && !singleRead)
      ...readKinds.expand(idsFor),
  };
  Map<String,String> get timeFilter => {
    if(dateFrom.isNotEmpty) 'date_from':dateFrom,
    if(dateTo.isNotEmpty) 'date_to':dateTo,
  };
  AgentToolPlan? get directPlan {
    if (kind == 'room' && !uncertain && !targetUncertain &&
        roomId.isNotEmpty && const {'model_dialogue','immersive'}.contains(roomKind)) {
      return AgentToolPlan(calls:[AgentToolCall(toolId:'room_history.read',
        arguments:{'kind':roomKind,'room_id':roomId,'view':view},reasonTag:'semantic_room_recall')]);
    }
    return null;
  }
  AgentToolPlan? get discoveryPlan => kind == 'room' && targetUncertain && !uncertain
      ? AgentToolPlan(calls:[AgentToolCall(toolId:'room_history.search',
          arguments:{'kind':'all',...timeFilter},reasonTag:'semantic_room_discovery')]) : null;
  int planningRounds(int ordinaryLimit) => multiStep ? 5 : ordinaryLimit;
  bool canFinishAfterSummary({required bool succeeded, required bool otherGoalsPending}) =>
      available && singleRead && !uncertain && !targetUncertain && kind == 'room' &&
      view == 'summary' && roomId.isNotEmpty && succeeded && !otherGoalsPending;
  String get planningContext => !available || !needsTools ? '' :
    '【本轮工具需求】分类=$kind；判断${uncertain ? "仍有歧义" : "有效"}；'
    '${singleRead ? "仅一次明确读取" : "可能有多步骤或待定位的要求，某个工具成功不代表整轮完成"}。'
    '${targetUncertain ? "房间目标未唯一确定：先查目录，结合真实时间和标题定位；仍有歧义就询问，不可默认最新房间。" : ""}'
    '${dateFrom.isNotEmpty ? "实际发言日期范围（含起点、不含终点）：$dateFrom 至 $dateTo。跨天记录需核对该日期原文，不能混入其他日发言。" : ""}'
    '${roomId.isNotEmpty ? "已定位的房间：kind=$roomKind room_id=$roomId。" : ""}'
    '保留用户要求的后续查证、比较和其他目标；未完成不得声称完成。';
}

class SemanticToolQuestions {
  SemanticToolQuestions(this.rooms, {DateTime? now}) : now = now ?? DateTime.now();
  final Map<String, Map<String,Object?>> rooms;
  final DateTime now;
  static Future<SemanticToolQuestions> load(AppDatabase db, {DateTime? now}) async {
    final rooms = <String,Map<String,Object?>>{};
    final repository = ModelDialogueRepository(db);
    for (final r in (await repository.listRooms()).take(6)) {
      final times = ModelDialogueTime.range(await repository.messagesForRoom(r.id));
      rooms['r${rooms.length}'] = {'id':r.id,'kind':'model_dialogue',
        'title':r.title,'topic':r.topic.length > 120 ? r.topic.substring(0,120) : r.topic,
        'status':r.ended ? 'ended' : 'in_progress','updated_at':r.updatedAt,
        ..._times(times['first_message_at'],times['last_message_at'],r.data['ended_at'])};
    }
    final sql = await db.database;
    for (final r in await sql.query('immersive_rooms',columns:['id','title','status','updated_at','ended_at'],
        where:"status = 'ended'",orderBy:'updated_at DESC',limit:4)) {
      final times = (await sql.rawQuery('SELECT MIN(created_at) AS first_at, MAX(created_at) AS last_at '
        'FROM immersive_messages WHERE room_id = ?', [r['id']])).single;
      rooms['r${rooms.length}'] = {...r,'kind':'immersive',
        ..._times(times['first_at'],times['last_at'],r['ended_at'])};
    }
    return SemanticToolQuestions(rooms,now:now);
  }
  static Map<String,Object?> _times(Object? first,Object? last,Object? closed) => {
    'first_message_at':first,'last_message_at':last,'closed_at':closed,
    'actual_message_time':'${ModelDialogueTime.format((first as num?)?.toInt()??0)} 至 ${ModelDialogueTime.format((last as num?)?.toInt()??0)}',
    'closed_time':ModelDialogueTime.format((closed as num?)?.toInt()??0),
  };
  Map<String,Object?> get context => {'available_room_metadata':rooms,
    'current_local_time':ModelDialogueTime.format(now.millisecondsSinceEpoch),
    'utc_offset_minutes':now.timeZoneOffset.inMinutes,'room_candidates_bounded':true,
    'room_time_rule':'Actual message time describes yesterday/today discussion. Closure and updated_at are different events. Search the directory if the required room is absent.'};
  Map<String,JevChoiceQuestion> get questions => {
    'tool_route':const JevChoiceQuestion(
      'Does the latest real user request need an actual capability now? Resolve references using recent_context. '
      '对谈结束你看看 and 你调用工具看里面的内容刚结束 request room records. '
      '昨天是你调用工具看到的 requests verification of past tool provenance (system). '
      'Feature design, quotes, hypotheticals, negation and casual mentions are none. '
      'Assistant claims of inability do not define available capabilities. '
      'mixed means multiple capability families are requested, e.g. read a room THEN verify it on the web. '
      'Never choose external web for local room records alone.',
      {'none':'No present tool need','room':'Read actual room records','phone':'Read own saved phone records',
       'web':'External lookup now','memory':'Past conversation or stored memories','system':'Abilities or past tool outcomes',
       'rules':'Configured rules','album':'Saved album images','device':'Actual device state','mixed':'Multiple capability families now'},optional:true),
    if(rooms.isNotEmpty) 'tool_room_target':JevChoiceQuestion(
      'Select a supplied room only for a real room-reading request and only when uniquely identifiable. '
      'Use actual_message_time for discussion dates and closed_time for closure references; updated_at is metadata. '
      'An explicit latest/just-ended reference may identify a matching room. Recency alone is insufficient. '
      'none when ambiguous, multiple rooms are requested, the target is absent from this bounded list, or no room read is requested.',
      {'none':'No unique supplied target',for(final e in rooms.entries)e.key:e.value.toString()},optional:true),
    'tool_room_view':const JevChoiceQuestion('Required room view: summary for overview; transcript for actual words/current partial discussion; detail for thorough synthesis.',
      {'summary':'Overview','transcript':'Actual committed words','detail':'Detailed synthesis'},optional:true),
    'tool_scope':const JevChoiceQuestion('Judge the complete latest request in context, including THEN, comparisons, plural rooms and follow-up verification. '
      'single only for one self-contained read whose result can finish the whole request. multi for multiple reads/goals, cross-capability work, comparisons, or unresolved requirements. none for no tool need.',
      {'single':'One self-contained read','multi':'Multiple steps or unresolved requirements','none':'No tool request'},optional:true),
    'tool_room_period':const JevChoiceQuestion('For requested room DISCUSSION records, interpret a real relative-date constraint using current_local_time. '
      'Do not use a date from quoted text or an assistant guess. any for no such constraint or a closure-only reference. Other dates can be resolved by directory search.',
      {'any':'No relative discussion-date constraint','today':'Discussion today','yesterday':'Discussion yesterday','before_yesterday':'Discussion the day before yesterday'},optional:true),
  };
  SemanticToolRoute interpret(Map<String,String>? answers, {Map<String,JevChoiceDecision> details = const {}}) {
    final kind = answers?['tool_route'] ?? 'none';
    final available = answers != null && SemanticToolRoute.kinds.contains(kind) && answers.containsKey('tool_route');
    final routeDecision = details['tool_route'];
    final uncertain = routeDecision?.ambiguous == true;
    final best = routeDecision?.probabilities.values.fold<double>(0,(a,b)=>a>b?a:b) ?? 0;
    final candidates = uncertain ? routeDecision!.probabilities.entries.where((e)=>
      SemanticToolRoute.readKinds.contains(e.key) && best-e.value <= .10+1e-9).map((e)=>e.key).toSet() : <String>{};
    final target = rooms[answers?['tool_room_target']];
    final targetUncertain = kind == 'room' && (target == null || details['tool_room_target']?.ambiguous == true || details['tool_room_period']?.ambiguous == true);
    final period = details['tool_room_period']?.ambiguous == true ? 'any' : answers?['tool_room_period'];
    final days = switch(period) {'today'=>0,'yesterday'=>1,'before_yesterday'=>2,_=>null};
    final from = days == null ? null : DateTime(now.year,now.month,now.day-days);
    final to = from == null ? null : DateTime(from.year,from.month,from.day+1);
    final actualFirst = (target?['first_message_at'] as num?)?.toInt() ?? 0;
    final actualLast = (target?['last_message_at'] as num?)?.toInt() ?? 0;
    // A multi-day span does not prove a message exists on an intervening day.
    // Resolve it with an actual timestamp-filtered directory search first.
    final wrongDay = from != null && (actualFirst < from.millisecondsSinceEpoch || actualLast >= to!.millisecondsSinceEpoch || actualFirst <= 0);
    final single = answers?['tool_scope'] == 'single' && details['tool_scope']?.ambiguous != true && details['tool_room_view']?.ambiguous != true;
    final view = answers?['tool_room_view'] ?? 'summary';
    return SemanticToolRoute(kind:available ? kind : 'none',available:available,uncertain:uncertain,
      targetUncertain:targetUncertain || kind == 'room' && wrongDay,singleRead:single,
      multiStep:kind == 'mixed' || answers?['tool_scope']=='multi' && details['tool_scope']?.ambiguous != true,
      candidateKinds:candidates,
      roomId:kind == 'room' && !targetUncertain && !wrongDay ? (target?['id'] as String? ?? '') : '',
      roomKind:kind == 'room' ? (target?['kind'] as String? ?? '') : '',
      view:const {'summary','detail','transcript'}.contains(view) ? view : 'summary',
      dateFrom:from?.toUtc().toIso8601String() ?? '',dateTo:to?.toUtc().toIso8601String() ?? '');
  }
}
