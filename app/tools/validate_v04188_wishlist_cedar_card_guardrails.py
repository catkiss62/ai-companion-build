#!/usr/bin/env python3
"""Cross-module gate for +232 wishlist, Cedar card, and extension guardrails."""

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


assert any(
    version in read("pubspec.yaml")
    for version in ("version: 0.41.88+232", "version: 0.41.89+233")
), "pubspec.yaml: expected +232 or +233 successor"
require("lib/core/agent/agent_self_reader.dart", "v0.41.88+232")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.88'")
require(
    "lib/core/phone/simulated_phone_policy.dart",
    "wishPresentationVersion = 2",
    "wishSemanticKey(CompanionThought thought)",
    "canonicalWishTopic",
    "wishTextForThought",
    "cedar_game:",
    "shared.activity.",
    "想把最近那趟钓鱼继续认真玩下去",
    "The private Thought body is deliberately never used",
)
require(
    "lib/core/phone/simulated_phone_repository.dart",
    "eligibleBySemanticKey",
    "retainedSemanticKeys",
    "source_topic_key",
    "semantic_key",
    "presentation_version",
    "SimulatedPhonePolicy.wishTextForThought",
)
activity = read("lib/features/chat/cedar_toy_activity_window.dart")
recent = activity.split("cedar_recent_progress_narrow_card", 1)[1]
recent = recent.split("if (session.events.isNotEmpty", 1)[0]
assert "margin: EdgeInsets.zero" in recent
assert "surfaceContainerHighest" not in recent
assert "DecoratedBox" not in recent
require(
    "test/simulated_phone_policy_v0388_test.dart",
    "wish identity merges recurring thoughts about the same safe topic",
    "wish copy is topic-aware without exposing private thought text",
    "shared.activity.fishing",
    "PRIVATE FISHING REASONING",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.88+232",
    "agent/v04188-wishlist-cedar-card-guardrails",
    "唯一循环所有权",
    "循环能力首版诊断",
    "https://github.com/Pal-AI-Lab/Cortico",
    "DeepSeek 缓存命中优化",
    "北京时间 2026-09-21 下午至晚上",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04188-wishlist-cedar-card-guardrails",
    "AI-Companion-v0.41.88-232-Wishlist-Cedar-Card-Guardrails-APK",
    "v0.41.88-wishlist-cedar-card-guardrails-test",
)
require(
    "tools/validation_suite.txt",
    "validate_v04188_wishlist_cedar_card_guardrails.py",
)

print("v0.41.88+232 wishlist, Cedar card, and guardrails validation passed.")
