#!/usr/bin/env python3
"""Regression gate for v0.41.96 Sen GLSurfaceView composition hotfix."""

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
for token in (
    "PlatformViewLink(",
    "AndroidViewSurface(",
    "PlatformViewsService.initExpensiveAndroidView(",
    "addOnPlatformViewCreatedListener(_onPlatformViewCreated)",
    "'compositionMode': 'forced_hybrid_composition'",
):
    assert token in stage, f"Sen stage lost forced HC token: {token}"
assert re.search(r"^\s*AndroidView\(", stage, re.MULTILINE) is None, (
    "Sen GLSurfaceView regressed to standard texture-layer AndroidView"
)

require(
    "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/SenLive2DPlatformView.kt",
    '"composition_mode" to compositionMode',
    '"native_surface_view" to true',
)
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
    "forced_hybrid_composition",
    "TRUE DEVICE PASSED",
)
require(
    "AI_Companion_当前总账.md",
    "6.13 v0.41.96+240 Sen 原生 Hybrid Composition 热修",
    "LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require("tools/validation_suite.txt", "validate_v04196_sen_hybrid_composition.py")

print("v0.41.96 Sen forced Hybrid Composition validation passed")
