#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), f"{relative} is empty"
    return value


assert re.search(r"^version: (?:0\.35\.(?:6\+81|7\+82|8\+83|9\+84)|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112|0\.38\.14\+113|0\.38\.15\+114)$", read("pubspec.yaml"), re.MULTILINE)
assert "static const int schemaVersion = 26;" in read(
    "lib/core/database/app_database.dart"
)

registry = read("lib/core/agent/agent_tool_registry.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
generation = read("lib/core/ai/durable_generation_runner.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat = read("lib/features/chat/chat_page.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
coordinator = read("lib/core/autonomy/autonomous_action_coordinator.dart")

for token in (
    "public_web.search",
    "rules.read",
    "memory.search",
    "device_context.read",
    "memory.propose_change",
    "reminder.schedule",
    "mcp.invoke",
):
    assert token in registry, token
assert "userTurnExecutable" in planner
assert "nativeToolDefinitions" in planner
assert "fromNativeToolCalls" in planner
assert "LayeredPublicWebProvider" in runner
assert "CurrentDeviceContextRefresher" in runner
assert "agent_tool_user_turn_request_count" in diagnostics
assert "agentToolArgumentsIncluded': false" in diagnostics
assert "AgentToolRegistry.definitionForAutonomous" in coordinator
assert "agentToolResults:" in generation
assert "onAgentToolActivity" in generation and "onAgentToolActivity" in controller
assert "_AgentActivityLine" in chat
assert "AGENT_TOOL_RESULT" in prompt

runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt"
)
system = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
accessibility = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
)
for token in (
    "accessibility_authorization_change_count",
    "overlayCoverHistory",
    "noteAccessibilityStatusProbe",
):
    assert token in runtime, token
for token in (
    "getHistoricalProcessExitReasons",
    "historicalExitReason",
):
    assert token in system, token
assert "accessibilityLastAuthorizationChangedAt" in runtime
assert "privacyHash(sourcePackage)" in accessibility

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.35.6+81 APK",
    "validate_v0356_agent_tool_loop.py",
    "AI-Companion-v0.35.6-81-Agent-Tool-Loop-APK.apk",
    "v0.35.6-agent-tool-loop-test",
    ".ci/v0356-monitor.txt",
):
    assert token in workflow, token

print("v0.35.6 agent tool loop and exit/overlay diagnostics validation passed")
