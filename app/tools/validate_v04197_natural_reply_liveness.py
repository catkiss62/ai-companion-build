#!/usr/bin/env python3
"""Regression gate for user-turn liveness without canned persona replies."""

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


require("pubspec.yaml", "version: 0.41.97+241", "version: 0.41.98+242", "version: 0.42.1+245")
require("lib/core/agent/agent_self_reader.dart", "v0.41.98+242", "v0.41.99+243", "v0.42.1+245")
require(
    "lib/core/grounding/recent_reply_repetition_guard.dart",
    "exact_recent_reply",
    "class UserReplyLivenessPolicy",
    "UserReplyCandidateSource.corrected",
    "UserReplyCandidateSource.initial",
)
require(
    "lib/core/grounding/prompt_history_policy.dart",
    "isLegacyCannedPersonaReply",
    "preventing them from teaching later generations",
    "0x92a8b7f7",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "最后一条真实 role=user 消息",
    "UserReplyLivenessPolicy.choose",
    "grounded_reply_retry_degraded_pass",
    "finalProvider.isGeminiRelay",
    "await generateCheckedDeepSeek(correctionMessages)",
    "never call the paid final provider a second time",
    "User turns are reply-live",
)
runner = read("lib/core/ai/durable_generation_runner.dart")
assert "generated = await generateFinal(correctionMessages);" not in runner, (
    "grounding repair may call the paid final provider twice"
)
require(
    "lib/core/desire/proactive_engine.dart",
    "RecentReplyRepetitionGuard.evaluate",
    "return blockGrounding(operationGuard.reason)",
    "return blockGrounding(repetitionGuard.reason)",
)
require(
    "test/recent_reply_repetition_guard_test.dart",
    "blocks an exact recent assistant reply",
    "never selects blank over model speech",
)
require(
    "test/prompt_history_policy_v0311_test.dart",
    "legacy canned assistant lines stay stored but leave model history",
)

# Persona text may come from a model (including another configured model), but
# never from a hard-coded local sentence that is committed as if she said it.
runtime = "\n".join(
    read(path)
    for path in (
        "lib/core/ai/durable_generation_runner.dart",
        "lib/core/desire/proactive_engine.dart",
        "lib/core/immersive/immersive_room_controller.dart",
        "lib/features/chat/chat_controller.dart",
    )
)
for banned in (
    "我其实还没有去玩，只是又想起这件事了",
    "刚才那件事我其实还没做，先不拿它当开场了",
    "那件事我还没有真的执行，刚才说岔了",
):
    assert banned not in runtime, f"canned persona fallback remains: {banned}"

require(
    ".github/workflows/build-apk.yml",
    "agent/v04198-sen-texture-direct-port",
    "AI-Companion-v0.41.98-242-Sen-Direct-Port-APK",
    "v0.41.98-sen-direct-port-test",
)
require(
    "AI_Companion_当前总账.md",
    "6.14 v0.41.97+241 自然回复保活与固定兜底移除",
)
require("tools/validation_suite.txt", "validate_v04197_natural_reply_liveness.py")

print("v0.41.97 natural reply liveness validation passed")
