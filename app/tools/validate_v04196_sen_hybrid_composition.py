#!/usr/bin/env python3
"""Preserve v0.41.96 failure evidence and require its v0.41.98 rollback."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def path(name: str) -> Path:
    return (REPO if name.startswith((".github/", "AI_")) else ROOT) / name


def text(name: str) -> str:
    return path(name).read_text(encoding="utf-8")


def require(name: str, *tokens: str) -> None:
    value = text(name)
    missing = [token for token in tokens if token not in value]
    assert not missing, f"{name}: missing {missing}"


require("pubspec.yaml", "version: 0.41.96+240")
require("lib/core/agent/agent_self_reader.dart", "v0.41.96+240")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.96'")
require("test/agent_self_reader_v0416_test.dart", "build=v0.41.96+240 schema=61")

stage = text("lib/widgets/sen_live2d_stage.dart")
assert re.search(r"^\s*return AndroidView\(", stage, re.MULTILINE), (
    "Sen stage must use the post-+240 standard AndroidView route"
)
for forbidden in (
    "PlatformViewLink(",
    "AndroidViewSurface(",
    "PlatformViewsService.initExpensiveAndroidView(",
    "forced_hybrid_composition",
):
    assert forbidden not in stage, f"failed +240 route returned: {forbidden}"

require(
    ".github/workflows/build-apk.yml",
    "agent/v04196-sen-hybrid-composition",
    "AI-Companion-v0.41.96-240-Sen-Hybrid-Composition-Hotfix-APK",
    "v0.41.96-sen-hybrid-composition-hotfix-test",
    "All 36 hash-exact Cubism standardES shader assets are present in the APK.",
)
require(
    "docs/SEN_LIVE2D_HYBRID_COMPOSITION_HOTFIX_v0.41.96.md",
    "initExpensiveAndroidView",
    "TRUE DEVICE FAILED",
    "ROLLED BACK IN v0.41.98+242",
)
require(
    "AI_Companion_当前总账.md",
    "6.13 v0.41.96+240 Sen 原生 Hybrid Composition 热修",
    "LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require("tools/validation_suite.txt", "validate_v04196_sen_hybrid_composition.py")

print("v0.41.96 Sen Hybrid Composition failure/rollback validation passed")
