#!/usr/bin/env python3
"""Structural, truth and privacy contracts for v0.41.46."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
tool = read("lib/core/agent/agent_tool.dart")
registry = read("lib/core/agent/agent_tool_registry.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
durable = read("lib/core/ai/durable_generation_runner.dart")
self_reader = read("lib/core/agent/agent_self_reader.dart")
service = read("lib/core/stickers/sticker_expression_service.dart")
message = read("lib/core/models/chat_message.dart")
guard = read("lib/core/grounding/operational_claim_grounding_guard.dart")
immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
immersive_controller = read("lib/core/immersive/immersive_room_controller.dart")
rules = read("lib/core/rules/rule_layer_content_v04125.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
tests = "\n".join(
    read(path)
    for path in (
        "test/agent_tool_registry_test.dart",
        "test/agent_tool_planner_fast_route_test.dart",
        "test/sticker_expression_test.dart",
        "test/operational_claim_grounding_guard_test.dart",
        "test/immersive_nsfw_contract_v04127_test.dart",
        "test/rule_layer_defaults_test.dart",
    )
)
design = read("docs/STICKER_AGENT_CONTINUATION_IDENTITY_v0.41.46.md")
notice = read("docs/THIRD_PARTY_NOTICES.md")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert "version: 0.41.46+185" in pubspec
assert "static const int schemaVersion = 55;" in database
assert "agent/v04146-sticker-agent-continuation-identity" in workflow
assert "Build AI Companion v0.41.46+185 APK" in workflow
assert "AI-Companion-v0.41.46-185-Sticker-Agent-Continuation-Identity-APK" in workflow
assert "validate_v04146_sticker_agent_continuation_identity.py" in workflow

for token in (
    "id: 'sticker.send'",
    "risk: AgentToolRisk.proposal",
    "userTurnAvailable: true",
    "autonomousAvailable: false",
):
    assert token in registry
assert "AgentToolRegistry.stickerSend.id" in planner
assert "_isExplicitStickerSend" in planner
assert "capability talk and negation never send media" in tests
assert "call.reasonTag == 'explicit_request'" in runner
assert "assistantMessageId.trim().isEmpty" in runner
assert "prepareForExplicitAgentRequest" in runner
assert "attachments: [selected.attachment]" in runner
assert "mediaUsageKeys" in tool and "mediaUsageKeys" in runner
assert "terminalCommitPending" in tool
assert "if (!result.terminalCommitPending)" in runner
assert "terminalCommitPending: true" in runner

# A prepared local file is part of the same durable assistant commit and is
# cleaned if ownership/cancellation/failure prevents that commit.
for token in (
    "attachments: preparedAgentAttachments",
    "completeGenerationJobIfCurrent",
    "agentAttachmentsCommitted = true",
    "recordCommittedMediaOutcome",
    "if (!agentAttachmentsCommitted)",
    "deleteAttachmentFiles(attachment)",
    "markUsedKey(usageKey)",
):
    assert token in durable
assert durable.index("completeGenerationJobIfCurrent") < durable.index(
    "agentAttachmentsCommitted = true"
)
for token in (
    "source: 'assistant_sticker:",
    "visionSummary: record.caption",
    "visionModel: 'sticker_index'",
    "StickerAgencyPolicy.isAssistantSelectable",
    "toneScope == 'bold' && !allowBold",
):
    assert token in service
assert "[我发送了一张表情包" in message
assert "id=sticker.send" not in self_reader  # registry rendering stays generic
assert "sticker_agent_v04146" in self_reader
assert "buildLabel = 'v0.41.46+185'" in self_reader
assert "ungrounded_sticker_send" in guard
assert "requiredToolId: 'sticker.send'" in guard

# Continuation is based on explicit truncation/syntax, never a word quota.
assert "static bool shouldContinue" in immersive_prompt
assert "finishReason == 'length'" in immersive_prompt
assert "opens > closes" in immersive_prompt
assert "不补字数" in immersive_prompt
for forbidden in ("尚未达到本轮硬下限", "达到至少1000个可见中文字符"):
    assert forbidden not in immersive_prompt
assert "ImmersivePromptBuilder.shouldContinue" in immersive_controller
assert "captureReasoning: true" in immersive_controller
assert "captureReasoning: false" in immersive_controller
assert "mergePersistedReasoning" in immersive_controller
assert "_visibleCharacterCount" not in immersive_controller

# Exact legacy-hash migration preserves any manually edited Rule 01.
assert "786a961b94cd1c190955d4b89eaebf81ea9706b56de6b05a46ab2668e209572c" in defaults
assert "legacyEditableRuleLayerSha256V04145NicknameExamples.entries" in database
assert "不要因为规则中出现过某个词就突然使用" in rules
assert "不要为了变化而刻意轮换" in rules
for forbidden in ("“傻逼”“儿子”“哥哥”“宝贝”", "固定词库或必选清单"):
    assert forbidden not in rules

for phrase in (
    "explicit sticker request takes the deterministic local Agent route",
    "sticker send claims require the current real media result",
    "continuation repairs truncation instead of filling a word quota",
    "continuation reasoning stays private",
):
    assert phrase in tests

for url in (
    "https://github.com/yyh-001/dsh-meme",
    "https://github.com/yyh-001/dsh-meme-packs",
    "https://github.com/nanbengxian-cyber/dafeiyu-qq-bot",
):
    assert url in design
    assert url in notice

# Public source and build configuration must not absorb private packs or test
# evidence. Only code/docs are allowed in this feature change.
private_media = [
    path
    for path in (ROOT / "lib/core/stickers").rglob("*")
    if path.is_file()
    and path.suffix.lower()
    in {".gif", ".jpg", ".jpeg", ".png", ".zip", ".aibackup"}
]
assert not private_media, private_media
assert "68 张私人图片" in design
assert "均不进入公开提交" in design

print("v0.41.46 sticker Agent + continuation identity validation passed")
