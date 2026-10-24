import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_task_loop.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';

void main() {
  DeepSeekToolCall native(String id,String command)=>DeepSeekToolCall(id:id,name:'cedar_toy_play',
    arguments:jsonEncode({'unknown_1':1,'unknown_2':2,'unknown_3':3,'unknown_4':4,'unknown_5':5,'unknown_6':6,
      'game':'bar','action':'cmd','params_json':jsonEncode({'command':command}),'participation_mode':'solo'}));
  test('structured arguments remain complete and unknown fields cannot displace required fields',(){
    final text='say '+List.filled(900,'鲸').join();
    final plan=AgentToolPlanner.fromNativeToolCalls([native('long',text)],latestUserText:'去游戏厅玩',
      cedarSessionActive:true,cedarStageToolIds:{'cedar_toy.play'});
    expect(plan.calls.single.arguments.keys,unorderedEquals(['game','action','params_json','participation_mode']));
    expect(jsonDecode(plan.calls.single.arguments['params_json']!)['command'],text);
    expect(plan.calls.single.nativeCallId,'long');
  });
  test('filtering first same-name call preserves second exact source identity',(){
    final first=native('old','serve wrong'); final second=native('new','serve correct');
    final original=AgentToolPlanner.fromNativeToolCalls([first],latestUserText:'去游戏厅玩',cedarSessionActive:true);
    final plan=AgentToolPlanner.fromNativeToolCalls([first,second],latestUserText:'去游戏厅玩',
      cedarSessionActive:true,excludedCallFingerprints:{AgentTaskLoopPolicy.callFingerprint(original.calls.single)});
    expect(plan.calls.single.nativeCallId,'new');
    expect(jsonDecode(plan.calls.single.arguments['params_json']!)['command'],'serve correct');
  });
  test('state reconciliation accepts only exact read-only snapshot commands',(){
    expect(CedarPlatformActionPolicy.isStateQuery('cmd',{'command':'status','slot':1}),true);
    expect(CedarPlatformActionPolicy.isStateQuery('cmd',{'command':'status;serve x'}),false);
    expect(CedarPlatformActionPolicy.isStateQuery('state',{'message':'hello'}),false);
    expect(CedarPlatformActionPolicy.isStateQuery('cmd',{'command':'guests'}),false);
  });
  test('explicit rejection is shared without altering service content',(){
    const input=McpToolOutcome(content:[],isError:false,structuredContent:{'text':'真实原因','action_accepted':false});
    final output=CedarPlatformActionPolicy.normalizeOutcome(input);
    expect(output.isError,true);expect(output.structuredContent,same(input.structuredContent));
    const normal=McpToolOutcome(content:[],isError:false,structuredContent:{'text':'正常结果'});
    expect(CedarPlatformActionPolicy.normalizeOutcome(normal),same(normal));
    expect(CedarPlatformActionPolicy.normalizeOutcome(normal,accepted:false).isError,true);
  });
}
