#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    target = REPO / path if path.startswith("AI_") or path.startswith(".github/") else ROOT / path
    assert target.is_file(), f"missing {target}"
    return target.read_text(encoding="utf-8")


def contains(path: str, *needles: str) -> None:
    text = read(path)
    for needle in needles:
        assert needle in text, f"{path}: missing {needle!r}"


contains("pubspec.yaml", "version: 0.41.67+211")
contains("lib/core/agent/agent_self_reader.dart", "v0.41.67+211")
contains(
    "lib/core/mcp/mcp_http_client.dart",
    "protocolVersion = '2024-11-05'",
    "notifications/initialized",
    "tools/list",
    "tools/call",
    "mcp-session-id",
    "network_or_timeout",
    "GenerationCancelledByUserException",
    "whenCancelled",
)
contains(
    "lib/core/mcp/cedar_toy_client.dart",
    "https://toy.cedarstar.org/",
    "ctai_v1_",
    "login_or_register",
    "generate_binding_token",
    "list_games",
    "get_guide",
    "'play'",
    "redactSecrets",
)
contains(
    "lib/core/mcp/cedar_toy_arcade_skill.dart",
    "Cedar Toy 游戏厅 · 行为 Skill",
    "不自动变成永久爱好",
    "账号、密码、Token 与绑定码",
)
contains(
    "lib/core/agent/agent_tool_registry.dart",
    "cedar_toy.list_games",
    "cedar_toy.get_guide",
    "cedar_toy.play",
)
contains(
    "lib/core/agent/agent_tool_planner.dart",
    "cedarStageToolIds",
    "cedar_toy_list_games",
    "cedar_toy_get_guide",
    "cedar_toy_play",
    "game_not_in_current_list" if False else "必须来自 cedar_toy_list_games 真实结果",
)
contains(
    "lib/core/agent/agent_tool_runner.dart",
    "_cedarGameListsByScope",
    "_cedarGuidesByScopeAndGame",
    "game_not_in_current_list",
    "action_not_in_current_guide",
    "【Cedar Toy 真实 $action Outcome】",
)
contains(
    "lib/core/ai/durable_generation_runner.dart",
    "generateInternal",
    "requestApiKey: apiKey",
    "requestEndpoint: endpoint",
    "generateFinal",
    "configuredFinalApiKey",
    "configuredFinalEndpoint",
    "Cedar MCP transport itself is not a",
    "cedarStageToolIds",
)
contains(
    "lib/features/settings/cedar_toy_settings_page.dart",
    "注册 / 登录小机",
    "恢复现有小机",
    "安全保存 Token",
    "生成 10 分钟绑定码",
    "测试连接与游戏列表",
    "所有远端游戏都会动态开放",
)
contains(
    "lib/core/storage/secure_config.dart",
    "_cedarToyTokenName",
    "readCedarToyToken",
    "writeCedarToyToken",
    "clearCedarToyToken",
)
secure_config = read("lib/core/storage/secure_config.dart")
for declaration in (
    "static const _cedarToyTokenName",
    "Future<String?> readCedarToyToken()",
    "Future<void> writeCedarToyToken(String value)",
    "Future<void> clearCedarToyToken()",
):
    assert secure_config.count(declaration) == 1, f"duplicate Cedar declaration: {declaration}"
assert read("lib/core/mcp/cedar_toy_arcade_skill.dart").count(
    "static bool isRelevant(String text)"
) == 1, "duplicate CedarToyArcadeSkill.isRelevant declaration"
contains(
    "lib/core/models/chat_segment.dart",
    "immersiveDisplayText",
    ": segment.text",
)
for path in (
    "lib/core/autonomy/public_web_discovery_engine.dart",
    "lib/core/autonomy/public_web_question_planner.dart",
    "lib/core/desire/proactive_engine.dart",
    "lib/features/settings/settings_category_pages.dart",
):
    assert "AiInterestConsumption" not in read(path), f"{path}: Phase 3C consumption still active"

contains(
    "lib/core/rules/rule_layer_content_v04155_user_defaults.dart",
    "非性交姿势（例如手交、口交、乳交）不会同步高潮",
    "除非女性AI在非性交的同时在自慰",
)
assert "【以上“色情模块”玩法规则必须严格遵守】" not in read(
    "lib/core/rules/rule_layer_content_v04155_user_defaults.dart"
)
contains(
    "lib/core/rules/rule_layer_defaults.dart",
    "legacyEditableRuleLayerSha256V04167ClimaxClarification",
    "b30afa45447b14bb80aeccd0a851b114dbbaf0940575470a663db1729c898c99",
    "1685e3bc0567762e55d5c6bd07b39767b64af2d5f0af6d57477cb1c9a7d54c33",
)
contains(
    ".github/workflows/build-apk.yml",
    "agent/v04167-cedar-toy-mcp",
    "AI-Companion-v0.41.67-211-Cedar-Toy-MCP-APK",
    "validate_v04167_cedar_toy_mcp.py",
)
contains(
    "AI_Companion_当前总账.md",
    "模型/API 调用双通道永久合同",
    "同一对话轮必须先收齐 Prompt、工具 Outcome 与内部判断",
    "Cedar MCP 网络请求本身不是模型调用",
)

print("v0.41.67+211 Cedar Toy MCP validation passed.")
