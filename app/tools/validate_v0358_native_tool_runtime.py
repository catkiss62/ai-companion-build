from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

client = (root / "lib/core/ai/deepseek_client.dart").read_text()
planner = (root / "lib/core/agent/agent_tool_planner.dart").read_text()
runner = (root / "lib/core/ai/durable_generation_runner.dart").read_text()
server = (root / "lib/core/platform/background_chat_command_server.dart").read_text()
snapshot = (root / "lib/core/platform/overlay_generation_snapshot.dart").read_text()
overlay = (
    root
    / "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
).read_text()
planner_test = (root / "test/agent_tool_planner_fast_route_test.dart").read_text()
deepseek_test = (root / "test/deepseek_temperature_test.dart").read_text()

assert "List<Map<String, Object?>> tools" in client
assert "'tool_choice': toolChoice ?? 'auto'" in client
assert "toolCallDeltas" in client
assert "reasoning_content" in runner
assert "'role': 'tool'" in runner
assert "AgentToolPlanner.nativeToolDefinitions" in runner
assert "agentToolPlanner.plan" not in runner
assert "正在判断是否需要调用工具" not in runner
assert "model_selected" in planner
assert "public_web_search" in planner
assert "变聪明了" in planner_test
assert "finishReason == 'tool_calls'" in deepseek_test

assert "blockingGenerationJob()" in server
assert "partialReasoning" in server and "content: ''" in server
assert "status_text" in snapshot
assert "(chatSending || appGenerationActive)" in overlay
assert 'map["status_text"]' in overlay
assert "beginGenerationPolling()" in overlay

pubspec = (root / "pubspec.yaml").read_text()
assert re.search(r"^version:\s*(?:0\.35\.(?:8\+83|9\+84)|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112|0\.38\.14\+113|0\.38\.15\+114|0\.38\.16\+115|0\.38\.18\+117|0\.39\.0\+118|0\.39\.1\+119|0\.39\.2\+120|0\.39\.3\+121|0\.39\.4\+122|0\.39\.5\+123|0\.39\.6\+124|0\.39\.7\+125|0\.39\.8\+126|0\.39\.9\+127|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132)|0\.40\.4\+133)\s*$", pubspec, re.M)

print("v0.35.8 native tool calling and shared runtime validation passed")
