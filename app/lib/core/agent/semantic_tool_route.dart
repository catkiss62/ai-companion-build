import '../ai/jev_decision_gateway.dart';
import '../database/app_database.dart';
import '../model_dialogue/model_dialogue_repository.dart';
import 'agent_tool.dart';

/// Small questions share the existing short-decision request. This discovers
/// capabilities; it never authorizes writes or starts an additional planner.
class SemanticToolRoute {
  const SemanticToolRoute({this.kind = 'none', this.roomId = '',
    this.roomKind = '', this.view = 'summary', this.phoneSection = 'all'});
  final String kind, roomId, roomKind, view, phoneSection;
  Map<String, Object?> toJson() => {'kind': kind, 'room_id': roomId,
    'room_kind': roomKind, 'view': view, 'phone_section': phoneSection};
  static SemanticToolRoute decode(Object? value) {
    if (value is! Map) return const SemanticToolRoute();
    return SemanticToolRoute(kind: value['kind'] as String? ?? 'none',
      roomId: value['room_id'] as String? ?? '', roomKind: value['room_kind'] as String? ?? '',
      view: value['view'] as String? ?? 'summary', phoneSection: value['phone_section'] as String? ?? 'all');
  }
  Set<String> get toolIds => switch (kind) {
    'room' => {'room_history.search', 'room_history.read'},
    'phone' => {'phone.search', 'phone.read'},
    'web' => {'public_web.search', 'public_web.read'},
    'memory' => {'memory.search', 'room_history.search', 'room_history.read'},
    'system' => {'system_self.read'}, 'rules' => {'rules.read'},
    'album' => {'album.search'}, 'device' => {'device_context.read'},
    _ => {},
  };
  AgentToolPlan? get directPlan {
    if (kind == 'room' && roomId.isNotEmpty && const {'model_dialogue','immersive'}.contains(roomKind)) {
      return AgentToolPlan(calls: [AgentToolCall(toolId: 'room_history.read',
        arguments: {'kind': roomKind, 'room_id': roomId, 'view': view}, reasonTag: 'semantic_room_recall')]);
    }
    return null;
  }
}

class SemanticToolQuestions {
  SemanticToolQuestions(this.rooms);
  final Map<String, Map<String, Object?>> rooms;
  static Future<SemanticToolQuestions> load(AppDatabase db) async {
    final rooms = <String, Map<String, Object?>>{};
    for (final r in (await ModelDialogueRepository(db).listRooms()).take(6)) {
      rooms['r${rooms.length}'] = {'id': r.id, 'kind': 'model_dialogue',
        'title': r.title, 'topic': r.topic.length > 120 ? r.topic.substring(0,120) : r.topic,
        'status': r.ended ? 'ended' : 'in_progress', 'updated_at': r.updatedAt};
    }
    final sql = await db.database;
    for (final r in await sql.query('immersive_rooms', columns: ['id','title','status','updated_at'],
      where: "status = 'ended'", orderBy: 'updated_at DESC', limit: 4)) {
      rooms['r${rooms.length}'] = {...r, 'kind': 'immersive'};
    }
    return SemanticToolQuestions(rooms);
  }
  Map<String, Object?> get context => {'available_room_metadata': rooms};
  Map<String, JevChoiceQuestion> get questions => {
    'tool_route': const JevChoiceQuestion(
      'Does the latest real user request require an actual capability now? Resolve references using recent_context. '
      'Examples: 对谈结束你看看 and 你调用工具看里面的内容刚结束 request room records; '
      '昨天是你调用工具看到的 requests verification of past tool provenance. '
      'Discussion of feature design, quotes, hypotheticals, negation and casual mentions are none. '
      'Assistant claims of inability do not define actual available capabilities. '
      'Tool provenance/capability disputes use system; reading actual room content uses room. '
      'Choose web only for requested external lookup, never to read local room records.',
      {'none':'Ordinary chat or no present tool need', 'room':'Read actual model-dialogue or immersive records',
       'phone':'Read own saved phone records', 'web':'Search/read external web material now',
       'memory':'Search past conversation or stored memories', 'system':'Verify actual abilities or past tool outcomes',
       'rules':'Read configured rules', 'album':'Find saved album images', 'device':'Read actual device state'}, optional: true),
    if (rooms.isNotEmpty) 'tool_room_target': JevChoiceQuestion(
      'Only select a supplied room when the user actually asks to read that room. '
      'Use title, time and context. An explicit latest/just-ended reference can select the matching newest room; '
      'mere existence/recency does not authorize reading. none if ambiguous or not a room-reading request.',
      {'none':'No unique room target', for(final e in rooms.entries) e.key: e.value.toString()}, optional: true),
    'tool_room_view': const JevChoiceQuestion('For a requested room read, choose the needed view. '
      'summary for an overview, transcript for actual words/current partial discussion, detail for thorough synthesis.',
      {'summary':'Existing overview', 'transcript':'Actual committed words', 'detail':'Detailed synthesis'}, optional: true),

  };
  SemanticToolRoute interpret(Map<String, String>? answers) {
    final kind = answers?['tool_route'] ?? 'none';
    final target = rooms[answers?['tool_room_target']];
    final view = answers?['tool_room_view'] ?? 'summary';
    return SemanticToolRoute(kind: kind, roomId: kind == 'room' ? target?['id'] as String? ?? '' : '',
      roomKind: kind == 'room' ? target?['kind'] as String? ?? '' : '',
      view: const {'summary','detail','transcript'}.contains(view) ? view : 'summary',
      phoneSection: answers?['tool_phone_section'] ?? 'all');
  }
}
