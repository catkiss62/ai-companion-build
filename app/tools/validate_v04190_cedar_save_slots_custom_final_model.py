#!/usr/bin/env python3
"""Source gate for v0.41.90 Cedar save slots and custom final replies."""

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


require("pubspec.yaml", "version: 0.41.90+234")
require("lib/core/agent/agent_self_reader.dart", "v0.41.90+234")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.90'")
require(
    "lib/core/mcp/cedar_game_protocol.dart",
    "class CedarSaveSlotPolicy",
    "supportsFiveSlots",
    "outcomeIndicatesExistingSave",
    "blocksAutonomousAction",
    "userExplicitlyApprovesOverwrite",
    "不同 game 的同号槽也互不覆盖",
    "官方人类前端或服务自动建立",
)
require(
    "lib/core/mcp/cedar_toy_arcade_skill.dart",
    "每游戏5槽 / slot=1-5",
    "可自主选择已知空槽",
    "confirm:true",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "CedarSaveSlotPolicy.blocksAutonomousAction",
    "save_overwrite_blocked",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "CedarSaveSlotPolicy.isOverwriteConfirmation",
    "cedar_save_overwrite_confirmation_required",
)
require(
    "lib/core/agent/agent_tool_planner.dart",
    "slot=1..5",
    "后台永不使用",
)
require(
    "lib/core/ai/chat_api_provider.dart",
    "双模型（自定义最终回复）",
    "configuredModel",
    "modelName.toLowerCase().contains('gemini')",
)
require(
    "lib/core/storage/secure_config.dart",
    "aiwangyou_final_reply_endpoint",
    "aiwangyou_final_reply_model",
    "readFinalReplyModel",
    "writeAiWangYouEndpoint",
    "writeAiWangYouModel",
)
require(
    "lib/features/settings/settings_category_pages.dart",
    "controller: _aiWangYouEndpoint",
    "controller: _aiWangYouModel",
    "预填原玩游地址",
    "预填原 Gemini 模型",
)
require(
    "lib/core/ai/deepseek_client.dart",
    "ChatApiProvider? requestProvider",
    "String? modelName",
    "configuredModel: modelName",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "configuredFinalModel",
    "requestProvider: finalProvider",
    "requestModelName: configuredFinalModel",
)
require(
    "lib/core/immersive/immersive_room_controller.dart",
    "finalModelName",
    "requestProvider: finalProvider",
    "modelName: finalModelName",
)
require(
    "test/cedar_save_slot_autonomy_v04190_test.dart",
    "autonomy can use a known empty slot but cannot confirm overwrite",
    "existing turn-zero save redirects autonomy from new to continue",
)
require(
    "test/chat_api_provider_test.dart",
    "custom second lane sends the entered endpoint and model unchanged",
    "provider/another-model",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04190-cedar-save-slots-custom-final-model",
    "AI-Companion-v0.41.90-234-Cedar-Save-Slots-Custom-Final-Model-APK",
    "v0.41.90-cedar-save-slots-custom-final-model-test",
)
require(
    "AI_Companion_当前总账.md",
    "6.7 v0.41.90+234 Cedar 五槽自主性与可配置最终回复通道",
    "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require(
    "tools/validation_suite.txt",
    "validate_v04190_cedar_save_slots_custom_final_model.py",
)

print("v0.41.90 Cedar save-slot and custom final-reply validation passed")
