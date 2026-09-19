#!/usr/bin/env python3
"""Cross-module gate for +229 Cedar protocol-media attachment delivery."""

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


require("pubspec.yaml", "version: 0.41.85+229")
require("lib/core/agent/agent_self_reader.dart", "v0.41.85+229")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.85'")
require(
    "lib/core/mcp/cedar_outcome_media.dart",
    "class CedarOutcomeMediaBridge",
    "photo_url",
    "image_url",
    "maxRemoteAttachmentsPerOutcome = 3",
    "GenerationCancelledByUserException",
    "Optional remote media must never erase a successful game Outcome",
)
media_bridge = read("lib/core/mcp/cedar_outcome_media.dart")
assert "public_web" not in media_bridge, "Cedar media bridge must not invoke public web"
assert "RegExp(r'https://" not in media_bridge, "must not scrape prose URLs"
require(
    "lib/core/agent/agent_tool_runner.dart",
    "SafePublicImageDownloader.download",
    "assistant_mcp_image:cedar:",
    "cedar_protocol_media",
    "attachMediaToEvent",
    "CEDAR IMAGE ATTACHMENT · TERMINAL COMMIT PENDING",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "imageReference",
    "withAttachmentImage",
    "attachMediaToEvent",
    "image_reference",
)
require(
    "lib/features/chat/cedar_toy_activity_window.dart",
    "session.events.last.imageReference",
    "MessageAttachmentStorage().fileFor(event.imageReference)",
    "Image.file",
)
require(
    "test/cedar_outcome_media_v04185_test.dart",
    "extracts travel photo_url from nested JSON text only",
    "rejects prose URLs, unsafe schemes, duplicates and excess media",
    "activity event preserves the same durable attachment reference",
    "Stop discards every materialized but undelivered attachment",
)
media_test = read("test/cedar_outcome_media_v04185_test.dart")
assert media_test.count("import 'dart:convert';") == 1, "duplicate dart:convert import"
assert "\nimport " not in media_test[media_test.index("void main()") :], (
    "test imports must precede declarations"
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.85+229",
    "agent/v04185-cedar-media-bridge",
    "正式记录（无容量上限）",
)
ledger = read("AI_Companion_当前总账.md")
assert any(
    status in ledger
    for status in (
        "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
        "CI PASSED / APK READY / TRUE DEVICE PENDING",
    )
), "ledger must carry a valid +229 delivery state"
require(
    ".github/workflows/build-apk.yml",
    "agent/v04185-cedar-media-bridge",
    "AI-Companion-v0.41.85-229-Cedar-Media-Bridge-APK",
    "v0.41.85-cedar-media-bridge-test",
)
require("tools/validation_suite.txt", "validate_v04185_cedar_outcome_media.py")

print("v0.41.85+229 Cedar outcome-media validation passed.")
