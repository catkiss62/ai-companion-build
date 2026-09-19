#!/usr/bin/env python3
"""Cross-module gate for +231 capability help and Cedar activity UI."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"


require("pubspec.yaml", "version: 0.41.87+231")
require("lib/core/agent/agent_self_reader.dart", "v0.41.87+231")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.87'")
require(
    "lib/features/settings/settings_page.dart",
    "帮助与真实能力",
    "CapabilityHelpPage",
)
require(
    "lib/features/settings/capability_help_page.dart",
    "AgentToolRegistry.all",
    "tool.executable && tool.userTurnAvailable",
    "tool.executable && tool.autonomousAvailable",
    "!tool.executable",
    "【检查系统】看看你有哪些真实功能",
    "通用 MCP Registry 尚未开放",
    "停止、刷新与卡住时怎么办",
    "权限与隐私边界",
)
require(
    "lib/features/chat/cedar_toy_activity_window.dart",
    "cedar_recent_progress_narrow_card",
    "widthFactor: 0.84",
    "活动记录详情",
    "onTap: () => _showEventDetails(event)",
    "SelectableText(event.summary)",
)
require(
    "test/settings_information_architecture_test.dart",
    "帮助与真实能力",
    "【检查系统】看看你有哪些真实功能",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.87+231",
    "agent/v04187-help-cedar-activity-ui",
    "IMPLEMENTED LOCALLY",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04187-help-cedar-activity-ui",
    "AI-Companion-v0.41.87-231-Help-Cedar-Activity-UI-APK",
    "v0.41.87-help-cedar-activity-ui-test",
)
require("tools/validation_suite.txt", "validate_v04187_help_cedar_activity_ui.py")

print("v0.41.87+231 help and Cedar activity UI validation passed.")
