#!/usr/bin/env python3
"""Static contracts for +217 Cedar entry and reply-completion hotfix."""

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


require("pubspec.yaml", "version: 0.41.73+217")
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "catalogMentionedGameId",
    "catalogMentionedGameIds",
    "_mentionsCatalogTitle",
    "requestsImmediateGameEntry",
    "return matches.length == 1 ? matches.single : '';",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "explicitCedarGameId",
    "reasonTag: 'explicit_game_mention'",
    "reasonTag: 'explicit_arcade_catalog'",
    "immediateCedarEntry",
    "【明确游戏请求·零调用重试】",
    "旧 session 仍保留可恢复",
    "cedarState = await cedarActivityStore.loadState()",
    "GenerationStreamIncompleteException catch (error)",
    "FinalReplyFailurePolicy.hasStrongIncompleteStructure",
    "notice: '回复已截断。当前文字尚未进入上下文或记忆",
)
require(
    "lib/core/agent/agent_participation_consent.dart",
    "_standaloneRoomCode",
    "r'^[A-Z0-9]{5,16}$'",
)
require(
    "lib/core/ai/final_reply_failure_policy.dart",
    "hasStrongIncompleteStructure",
    "reason == 'stream_incomplete'",
    "_count(text, '「') > _count(text, '」')",
)
require(
    "lib/core/desire/proactive_engine.dart",
    "sawTerminalSignal",
    "finishReason",
    "【主动消息完整性重试】",
    "reasonTag: 'reply_incomplete'",
    "未把半句发送或写入聊天",
)
require(
    "lib/features/chat/chat_page.dart",
    "!item.message!.isProactive",
)
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieRuntimeAssetStore.kt",
    "ai-companion-v04173-build217-jiuhu-four-voices-v1",
)
require(
    "test/cedar_toy_game_switching_v04169_test.dart",
    "catalogMentionedGameId('去游戏厅里玩双弈吧', catalog)",
    "现在去花园与猫开一个存档吧",
    "你可以玩玩瓶中生态和花园与猫",
    "garden_party·花园与猫咪派对",
    "'duel'",
    "'garden_cat'",
)
require(
    "test/agent_mcp_runtime_hardening_v04170_test.dart",
    "describesExistingRoom('5JH5MDVT')",
    "explicitlyGranted('5JH5MDVT')",
)
require(
    "test/final_reply_failure_policy_test.dart",
    "hasStrongIncompleteStructure('「我现在满脑子')",
    "hasStrongIncompleteStructure('忽然有点想你')",
    "isIncompleteFinishReason('stream_incomplete')",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04173-cedar-deterministic-entry-reply-completion",
    "AI-Companion-v0.41.73-217-Cedar-Entry-Reply-Completion-APK",
    "validate_v04173_cedar_reply_completion.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.73+217 双弈确定性入口与回复完整性热修",
    "LOCAL IMPLEMENTED",
)

runner = read("lib/core/ai/durable_generation_runner.dart")
assert runner.count("FinalReplyFailurePolicy.hasStrongIncompleteStructure") >= 2
assert "notice: 'Gemini 回复已截断。当前文字尚未进入上下文或记忆" not in runner

voice_surfaces = "".join(
    read(path)
    for path in (
        "lib/core/tts/tts_voice_profile.dart",
        "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt",
        "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/VoiceProfileCatalog.kt",
        ".github/workflows/build-apk.yml",
    )
)
for retired in ("jiuhu_soft_speech", "jiuhu_whisper", "jiuhu_breathy"):
    assert retired not in voice_surfaces, retired

print("v0.41.73+217 Cedar entry/reply completion validation passed.")
