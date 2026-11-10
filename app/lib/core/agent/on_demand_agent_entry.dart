import 'dart:convert';
import '../ai/deepseek_client.dart';
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
  static const prompt = '''你有可按需使用的 Agent 能力。需要查证、追读记忆、查看相册图片、了解游戏或核实工具结果时，可以调用 agent_request。分类只是起点，可按真实结果切换可用的读取工具、多步核验，直到足够回答或确实受阻。刚画好图后用户问你能不能看到或让你去相册看，就定位刚生成的那张并识图，文字索引只是线索。能直接聊就直接聊，不要求每轮调用，也不用宣布启动 Agent。游戏、创作和发送等操作使用本轮已有授权任务入口。排查任务时可用 system_self.read(scope=runtime/outcomes) 查看实际状态，不得从一次未执行推断网络或服务坏了。''';
  static const familyNames = ['web','memory','game','system','rules','phone','room','album','device','qq'];
  static const definition = <String,Object?>{
    'type':'function', 'function':{
      'name':name, 'description':'按需请求内部 Agent 规划读取、查证或诊断；无需每轮使用。',
      'parameters':{'type':'object','properties':{
        'goal':{'type':'string','description':'这次真正想了解的问题，最多500字'},
        'families':{'type':'array','minItems':1,'maxItems':3,'description':'最先考虑的工具分类，实际可按结果切换。','items':{'type':'string',
          'enum':familyNames}},
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
          raw.any((v)=>v is! String || !familyNames.contains(v))) return null;
      return OnDemandAgentEntry(goal,raw.cast<String>().toSet());
    } catch(_){return null;}
  }
  Set<String> toolIds({bool cedarConfigured = false, bool cedarBlindPlay = false}) => {
    for (final tool in AgentToolRegistry.userTurnExecutable)
      if (tool.id != AgentToolRegistry.screenObservation.id &&
          (cedarConfigured || !tool.id.startsWith('cedar_toy.')) &&
          (!cedarBlindPlay || !tool.id.startsWith('public_web.')))
        tool.id,
  };
  List<Map<String,Object?>> definitions(Set<String> ids) => AgentToolPlanner.nativeToolDefinitionsFor('',
    cedarStageToolIds: ids.where((id)=>id.startsWith('cedar_toy.')).toSet(),
    semanticToolIds:ids,semanticReadAuthoritative:true).where((d)=>ids.any((id)=>
      (d['function'] as Map?)?['name']==AgentToolPlanner.nativeNameForToolId(id))).toList();
}
