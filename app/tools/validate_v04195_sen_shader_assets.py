#!/usr/bin/env python3
"""Regression gate for v0.41.95 Sen Cubism shader-assets hotfix."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def path(name: str) -> Path:
    return (
        REPO
        if name == ".gitattributes" or name.startswith((".github/", "AI_"))
        else ROOT
    ) / name


def text(name: str) -> str:
    return path(name).read_text(encoding="utf-8")


def require(name: str, *tokens: str) -> None:
    value = text(name)
    missing = [token for token in tokens if token not in value]
    assert not missing, f"{name}: missing {missing}"


require("pubspec.yaml", "version: 0.41.95+239")
require("lib/core/agent/agent_self_reader.dart", "v0.41.95+239")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.95'")
require(
    "test/agent_self_reader_v0416_test.dart",
    "build=v0.41.95+239 schema=61",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04195-sen-shader-assets",
    "AI-Companion-v0.41.95-239-Sen-Cubism-Shader-Hotfix-APK",
    "v0.41.95-sen-cubism-shader-hotfix-test",
    "All 36 hash-exact Cubism standardES shader assets are present in the APK.",
)
require(
    ".gitattributes",
    "app/android/app/src/main/assets/com/live2d/sdk/cubism/framework/shaders/standardES/** binary",
)

shader_dir = path(
    "android/app/src/main/assets/com/live2d/sdk/cubism/framework/shaders/standardES"
)
shader_files = sorted(item for item in shader_dir.iterdir() if item.is_file())
assert len(shader_files) == 36, "expected the complete 36-file standardES set"
shader_tree_digest = sha256(
    "".join(
        f"{item.name}:{sha256(item.read_bytes()).hexdigest()}\n"
        for item in shader_files
    ).encode("utf-8")
).hexdigest()
assert shader_tree_digest == (
    "2130c2079aaade0352f3abb2fde51f864a32b01466ea47ee3a9f8fe859b69250"
), "Cubism shader bytes differ from the pinned Framework commit"
assert sha256((shader_dir / "VertShaderSrcCopy.vert").read_bytes()).hexdigest() == (
    "d56e015be2348f1fd42cf7ccaef7bb869c5cd2095759d1ffc806dddca4339a74"
)
require(
    "android/app/src/main/java/com/live2d/sdk/cubism/framework/rendering/android/CubismShaderAndroid.java",
    'SHADER_BASE_PATH = "com/live2d/sdk/cubism/framework/shaders/standardES"',
    'loadShaderProgramFromFile("VertShaderSrcCopy.vert"',
)
require(
    "docs/SEN_LIVE2D_SHADER_HOTFIX_v0.41.95.md",
    "VertShaderSrcCopy.vert",
    "36",
    "TRUE DEVICE PASSED",
)
require(
    "AI_Companion_当前总账.md",
    "6.12 v0.41.95+239 Sen Cubism shader assets 热修",
    "CI PENDING / TRUE DEVICE PENDING",
)
require("tools/validation_suite.txt", "validate_v04195_sen_shader_assets.py")

print("v0.41.95 Sen Cubism shader-assets validation passed")
