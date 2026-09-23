#!/usr/bin/env python3
"""Lock the v0.42.3 media-only empty-turn routing hotfix."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parent


def read(path: str) -> str:
    base = REPOSITORY if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    planner = read("lib/core/agent/agent_tool_planner.dart")
    test = read("test/agent_tool_planner_fast_route_test.dart")
    workflow = read(".github/workflows/build-apk.yml")
    ledger = read("AI_Companion_当前总账.md")

    require(
        any(
            version in read("pubspec.yaml")
            for version in ("version: 0.42.3+247", "version: 0.42.4+248")
        ),
        "version mismatch",
    )
    require(
        "final toolIds = <String>{..._routeToolIds(text)};" in planner,
        "tool route results are not defensively copied before Cedar mutation",
    )
    require(
        "media-only empty text safely accepts Cedar stage tool injection" in test,
        "media-only planner regression is missing",
    )
    for token in (
        "image-only",
        "sticker-only",
        "visionModel: 'sticker_index'",
        "cedarStageToolIds: const <String>{'cedar_toy.list_games'}",
        "expect(AgentToolPlanner.nativeToolDefinitionsFor(''), isEmpty)",
    ):
        require(token in test, f"media-only regression missing: {token}")
    require(
        "agent/v04203-media-empty-turn-hotfix" in workflow,
        "hotfix branch trigger missing",
    )
    require("v0.42.3+247" in workflow, "workflow build identity mismatch")
    require(
        "纯媒体空文本回合路由崩溃修复" in ledger,
        "current ledger entry missing",
    )
    require(
        "tools/validate_v04203_media_empty_turn_hotfix.py"
        in read("tools/validation_suite.txt"),
        "validator is not registered",
    )

    print("v0.42.3 media-only empty-turn routing hotfix contract passed")


if __name__ == "__main__":
    main()
