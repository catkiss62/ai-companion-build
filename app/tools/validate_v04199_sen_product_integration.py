#!/usr/bin/env python3
"""Regression gate for the v0.41.99 Sen product integration."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(name: str) -> str:
    base = REPO if name.startswith((".github/", "AI_")) else ROOT
    return (base / name).read_text(encoding="utf-8")


def require(name: str, *tokens: str) -> None:
    value = read(name)
    missing = [token for token in tokens if token not in value]
    assert not missing, f"{name}: missing {missing}"


require("pubspec.yaml", "version: 0.41.99+243")
require("lib/core/agent/agent_self_reader.dart", "v0.41.99+243")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.99'")
require(
    "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/SenLive2DPlatformView.kt",
    "companion.loadModel(info.modelFile, true, outfit)",
    '"toggleNativePreset"',
    '"resetNativePresets"',
    '"playNativeMotion"',
    '"stopNativeMotion"',
    '"setLookTarget"',
    '"setStageTransform"',
    "one-shot performances",
    "dressing-style state",
)
platform = read(
    "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/SenLive2DPlatformView.kt"
)
assert "loadModel(info.modelFile, info.expressions" not in platform
require(
    "lib/core/presentation/sen_live2d_presentation.dart",
    "outfit == 'undressed' || nsfwActive",
    "'nervous' => 'tense'",
    "'crying' => 'sad'",
    "'embarrassed' => 'ashamed'",
)
require(
    "lib/widgets/sen_live2d_stage.dart",
    "required this.nsfwActive",
    "required this.transform",
    "setStageTransform",
    "setLookTarget",
    "widget.transform.offset",
    "单指移动 · 双指缩放",
)
require(
    "lib/features/chat/chat_page.dart",
    "pointerRouter.addGlobalRoute",
    "pointerRouter.removeGlobalRoute",
    "MediaQuery.viewInsetsOf(context).bottom",
    "sen_live2d_scale",
    "调整 Live2D 位置与大小",
    "nsfwActive: controller.nsfwActive",
)
require("lib/app.dart", "resizeToAvoidBottomInset: false")
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt",
    "SenLive2DRuntime.setSpeechAmplitude(smoothed)",
    "SenLive2DRuntime.setSpeechAmplitude(0f)",
)
require(
    "test/sen_live2d_presentation_v04194_test.dart",
    "NSFW presentation uses visual-only romantic shy in every outfit",
    "ChatVisualResolver.values, hasLength(20)",
)
require(
    "docs/SEN_LIVE2D_PRODUCT_INTEGRATION_v0.41.99.md",
    "一次性表现",
    "装扮式持续状态",
    "必须同时定义开始",
    "输入法属于独立系统窗口",
)
require(
    "AI_Companion_当前总账.md",
    "6.16 v0.41.99+243 Sen 正式产品接入收口",
    "CI PENDING / TRUE DEVICE PENDING",
)
require("tools/validation_suite.txt", "validate_v04199_sen_product_integration.py")

print("v0.41.99 Sen product integration validation passed")
