#!/usr/bin/env python3
"""Source/provenance gate for v0.41.94 Sen Live2D migration."""

from hashlib import sha256
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


def digest(name: str) -> str:
    return sha256(path(name).read_bytes()).hexdigest()


require("pubspec.yaml", "version: 0.41.94+238")
require("lib/core/agent/agent_self_reader.dart", "v0.41.94+238")
require("lib/core/mcp/mcp_http_client.dart", "'version': '0.41.94'")
require(
    ".github/workflows/build-apk.yml",
    "agent/v04194-sen-live2d-migration",
    "AI-Companion-v0.41.94-238-Sen-Live2D-Migration-APK",
    "v0.41.94-sen-live2d-migration-test",
)

framework = path("android/app/src/main/java/com/live2d/sdk/cubism")
assert len(list(framework.rglob("*.java"))) == 105, "Cubism Framework source set drifted"
assert digest("android/app/src/main/java/com/live2d/sdk/cubism/framework/model/CubismModel.java") == (
    "a1ce732460a977ed6c070a3ddf1dc4807fedfafe4d0e3add07b5a0d41ca79140"
)
assert digest("android/app/libs/Live2DCubismCore.aar") == (
    "3f05da57ab855e803000e6353888dd561c47758598c6c0200dcd0109312705f8"
)
shaders = path(
    "android/app/src/main/assets/com/live2d/sdk/cubism/framework/shaders/standardES"
)
shader_files = sorted(item for item in shaders.iterdir() if item.is_file())
assert len(shader_files) == 36, "Cubism standardES shader asset set drifted"
shader_tree_digest = sha256(
    "".join(
        f"{item.name}:{sha256(item.read_bytes()).hexdigest()}\n"
        for item in shader_files
    ).encode("utf-8")
).hexdigest()
assert shader_tree_digest == (
    "2130c2079aaade0352f3abb2fde51f864a32b01466ea47ee3a9f8fe859b69250"
)
assert digest(
    "android/app/src/main/java/com/catkiss/senlive2dcompanion/SenPerformanceEngine.java"
) == "492b6c12170b681e14ada78b0046dabd9644ed809001a0384676e4a430863218"
assert digest(
    "android/app/src/main/java/com/catkiss/senlive2dcompanion/SenOutfitPresets.java"
) == "acdcb49cb91bb6d798086f31cec142db5cd5f44ec959f60717716ab1a09cc25a"

require(
    "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/SenModelRepository.kt",
    "MAX_EXTRACTED_BYTES = 1_500_000_000L",
    "MAX_ZIP_ENTRIES = 8_000",
    "output.canonicalPath",
    "confirmPendingImport",
    "rollbackPendingImport",
)
require(
    "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/SenLive2DPlatformView.kt",
    "companion.setTouchFollowEnabled(true)",
    "duration >= 120L",
    "view.width * .075f",
    "Math.random() < .10",
    "small_nod",
    "continuation_owner",
    "sen_view_lifecycle",
)
require(
    "android/app/src/main/java/com/catkiss/senlive2dcompanion/SenRenderer.java",
    "screenToModelNormalized",
    "setTouchTarget",
    "releaseHeadPat",
)
require(
    "android/app/src/main/java/com/catkiss/senlive2dcompanion/SenLive2DModel.java",
    "ahogeRootAnchor",
    "glassesEnabled",
    "setExpression(String name)",
)
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt",
    "playbackHeadFrames(activeTrack)",
    "ENVELOPE_BIN_FRAMES = 256",
    "SenLive2DRuntime.setSpeechAmplitude(0f)",
)
require(
    "lib/core/presentation/sen_live2d_presentation.dart",
    "senLive2DEmotionKeys",
    "'romantic_shy'",
    "'nervous' => 'tense'",
    "'crying' => 'sad'",
    "'embarrassed' => 'ashamed'",
)
require(
    "lib/features/chat/chat_page.dart",
    "_senLive2DEnabled",
    "SenLive2DStage(",
    "SenLive2DQuickControls(",
    "_senStageKey.currentState?.listen()",
)
require(
    "lib/widgets/sen_live2d_stage.dart",
    "AndroidView(",
    "widget.emotion.effectAsset",
    "女仆装",
    "白衬衫",
    "兔女郎",
    "'undressed': '脱'",
)
require(
    "test/sen_live2d_presentation_v04194_test.dart",
    "all existing chat emotions map into Sen authored emotions",
    "undressed presentation uses visual-only romantic shy",
)
require(
    "docs/SEN_LIVE2D_INTEGRATION_v0.41.94.md",
    "336b93af1d96e1dd85799faf3df966600c1224a7",
    "AudioTrack.playbackHeadPosition",
    "TRUE DEVICE PASSED",
)
require(
    "AI_Companion_当前总账.md",
    "6.11 v0.41.94+238 Sen Live2D 首阶段完整移植",
    "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
)
require("tools/validation_suite.txt", "validate_v04194_sen_live2d_migration.py")

print("v0.41.94 Sen Live2D migration validation passed")
