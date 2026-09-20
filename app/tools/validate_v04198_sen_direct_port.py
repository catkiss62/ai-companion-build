#!/usr/bin/env python3
"""Source/provenance gate for v0.41.98 Sen direct port."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def path(name: str) -> Path:
    return (REPO if name.startswith((".github/", "AI_")) else ROOT) / name


def text(name: str) -> str:
    return path(name).read_text(encoding="utf-8")


def digest(name: str) -> str:
    return sha256(path(name).read_bytes()).hexdigest()


def require(name: str, *tokens: str) -> None:
    value = text(name)
    missing = [token for token in tokens if token not in value]
    assert not missing, f"{name}: missing {missing}"


require("pubspec.yaml", "version: 0.41.98+242")
require("lib/core/agent/agent_self_reader.dart", "v0.41.98+242")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.98'")
require("test/agent_self_reader_v0416_test.dart", "build=v0.41.98+242 schema=61")

sen_dir = path("android/app/src/main/java/com/catkiss/senlive2dcompanion")
sen_files = sorted(sen_dir.glob("*.java"))
assert len(sen_files) == 16, "AI package must contain exactly the 16 Sen runtime Java files"
sen_manifest = "".join(
    f"{item.name}:{sha256(item.read_bytes()).hexdigest()}\n" for item in sen_files
)
assert sha256(sen_manifest.encode("utf-8")).hexdigest() == (
    "093df0d06b451b8a9b0009cc4ace9fd67fdc03798c0e192e2d537e6017a853a2"
), "Sen runtime is not byte-identical to main@336b93a"

framework_dir = path("android/app/src/main/java/com/live2d/sdk/cubism/framework")
framework_files = sorted(framework_dir.rglob("*.java"))
assert len(framework_files) == 105, "Cubism Framework source count drifted"
framework_manifest = "".join(
    f"{item.relative_to(framework_dir).as_posix()}:{sha256(item.read_bytes()).hexdigest()}\n"
    for item in framework_files
)
assert sha256(framework_manifest.encode("utf-8")).hexdigest() == (
    "9d69a3f826412ed4b71642d587c658c007f5f97abc020d6f0aa0ca0f4f03c620"
), "Framework differs from pinned source plus Sen's exact no-mipmap patch"

assert digest("android/patches/cubism-java-no-mipmap.patch") == (
    "227d57f649dc29d83066811be84fdb2e7a0969eac8f36a0e1de7dae96b7ffad7"
)
assert digest("android/app/libs/Live2DCubismCore.aar") == (
    "3f05da57ab855e803000e6353888dd561c47758598c6c0200dcd0109312705f8"
)
assert digest("android/app/src/main/assets/sen-default-profile-v1.json") == (
    "8e0b16b1b734151156674747a94936b1b69df4b2db371ac4c1e06e0f1bd008d6"
)

shader = text(
    "android/app/src/main/java/com/live2d/sdk/cubism/framework/rendering/android/CubismShaderAndroid.java"
)
assert "GL_TEXTURE_MIN_FILTER, GL_LINEAR);" in shader
assert "GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);" in shader
assert "GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);" in shader
assert "GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);" not in shader

stage = text("lib/widgets/sen_live2d_stage.dart")
assert "AndroidView(" in stage
for forbidden in (
    "PlatformViewLink(",
    "AndroidViewSurface(",
    "initExpensiveAndroidView(",
    "forced_hybrid_composition",
):
    assert forbidden not in stage, f"failed +240 composition route returned: {forbidden}"

platform_view = text(
    "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/SenLive2DPlatformView.kt"
)
assert 'companion.applyExpression("glasses")' in platform_view
assert "setGlassesEnabled" not in platform_view
assert "SenTextureCompanionView" not in platform_view

require(
    ".github/workflows/build-apk.yml",
    "agent/v04198-sen-texture-direct-port",
    "AI-Companion-v0.41.98-242-Sen-Direct-Port-APK",
    "v0.41.98-sen-direct-port-test",
)
require(
    "docs/SEN_LIVE2D_DIRECT_PORT_v0.41.98.md",
    "336b93af1d96e1dd85799faf3df966600c1224a7",
    "cubism-java-no-mipmap.patch",
    "TRUE DEVICE PASSED",
)
require(
    "AI_Companion_当前总账.md",
    "6.15 v0.41.98+242 Sen 完整移植与固定兜底收口",
    "CI PENDING / TRUE DEVICE PENDING",
)
require("tools/validation_suite.txt", "validate_v04198_sen_direct_port.py")

print("v0.41.98 Sen direct-port validation passed")
