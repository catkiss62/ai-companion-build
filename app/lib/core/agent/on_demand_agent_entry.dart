import 'dart:convert';
import '../ai/deepseek_client.dart';
import 'agent_tool.dart';
import 'agent_tool_planner.dart';
import 'agent_tool_registry.dart';

/// The speaking model can choose this in its existing reply request. Choosing
/// nothing adds no planner request. This entry grants discovery/reading only;
/// existing explicit task routes remain responsible for game and other writes.
class OnDemandAgentEntry {
  const OnDemandAgentEntry(this.goal, this.families);
  final String goal;
  final Set<String> families;
  static const name = 'agent_request';
  static const prompt = '''你有可按需使用的 Agent 规划与读取能力。想到确实值得查证、追读记忆、了解游戏或核实刚才工具为什么没有结果时，可以调用 agent_request，再依据真实结果回复。是否使用由你判断；能直接聊就直接聊，不要求每轮调用，也不用向对方宣布启动 Agent。这个入口本身不执行游戏、创作、发送或设备操作；这些仍走已有真实权限与任务入口。''';
  static const familiesToTools = <String, Set<String>>{
    'web': {'public_web.search','public_web.read'},
    'memory': {'memory.search','chat_history.search','chat_history.read'},
    'game': {'cedar_toy.list_games','cedar_toy.get_guide'},
    'system': {'system_self.read'},
    'rules': {'rules.read'},
    'phone': {'phone.search','phone.read'},
    'room': {'room_history.search','room_history.read'},
    'album': {'album.search'},
    'device': {'device_context.read'},
  };
  static const definition = <String,Object?>{
    'type':'function', 'function':{
      'name':name, 'description':'按需请求内部 Agent 规划读取、查证或诊断；无需每轮使用。',
      'parameters':{'type':'object','properties':{
        'goal':{'type':'string','description':'这次真正想了解的问题，最多500字'},
        'families':{'type':'array','minItems':1,'maxItems':3,'items':{'type':'string',
          'enum':['web','memory','game','system','rules','phone','room','album','device']}},
      },'required':['goal','families'],'additionalProperties':false},
    },
  };
  static OnDemandAgentEntry? parse(List<DeepSeekToolCall> calls) {
    if(calls.length != 1 || calls.single.name != name) return null;
    try {
      final data=jsonDecode(calls.single.arguments);
      if(data is! Map || data['goal'] is! String || data['families'] is! List) return null;
      final goal=(data['goal'] as String).trim();
      final raw=data['families'] as List;
      if(goal.isEmpty || goal.length > 500 || raw.isEmpty || raw.length > 3 ||
          raw.any((v)=>v is! String || !familiesToTools.containsKey(v))) return null;
      return OnDemandAgentEntry(goal,raw.cast<String>().toSet());
    } catch(_){return null;}
  }
  Set<String> toolIds({bool cedarConfigured = false, bool cedarBlindPlay = false}) => {
    for(final family in families)
      if((family != 'game' || cedarConfigured) && (family != 'web' || !cedarBlindPlay))
        ...familiesToTools[family]!.where((id)=>AgentToolRegistry.byId(id)?.risk == AgentToolRisk.readOnly),
  };
  List<Map<String,Object?>> definitions(Set<String> ids) => AgentToolPlanner.nativeToolDefinitionsFor('',
    cedarStageToolIds: ids.where((id)=>id.startsWith('cedar_toy.')).toSet(),
    semanticToolIds:ids,semanticReadAuthoritative:true).where((d)=>ids.any((id)=>
      (d['function'] as Map?)?['name']==AgentToolPlanner.nativeNameForToolId(id))).toList();
}
