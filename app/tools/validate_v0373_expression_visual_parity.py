#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert "version: 0.37.3+92" in read("pubspec.yaml")
assert "static const int schemaVersion = 28;" in read(
    "lib/core/database/app_database.dart"
)

visuals = read("lib/core/presentation/chat_visuals.dart")
assert visuals.count("key: '") == 20
for token in (
    "key: 'normal'",
    "key: 'disgust'",
    "key: 'happy'",
    "key: 'worried'",
    "key: 'angry'",
    "key: 'nervous'",
    "key: 'afraid'",
    "key: 'shy'",
    "key: 'flustered'",
    "key: 'serious'",
    "key: 'helpless'",
    "key: 'excited'",
    "key: 'confused'",
    "key: 'crying'",
    "key: 'affection'",
    "key: 'playful'",
    "key: 'embarrassed'",
    "key: 'confident'",
    "key: 'surprised'",
    "key: 'calm'",
):
    assert token in visuals, token

portrait = read("lib/widgets/chat_portrait_stage.dart")
for token in (
    "gaplessPlayback: true",
    "Transform.translate",
    "Transform.scale",
    "ChatPortraitAnimation.happyBounce",
    "const Duration(milliseconds: 600)",
    "const Duration(milliseconds: 800)",
    "const Duration(milliseconds: 300)",
    "const Duration(seconds: 2)",
    "const Cubic(0.175, 0.885, 0.32, 1.275)",
    "Curves.easeOut",
    ".clamp(0.85, 1.80)",
    ".clamp(-0.45, 0.45)",
    ".clamp(-0.35, 0.35)",
):
    assert token in portrait, token

chat = read("lib/features/chat/chat_page.dart")
for token in (
    "chat_portrait_scale",
    "chat_portrait_offset_x",
    "chat_portrait_offset_y",
    "ChatPortraitStage(",
    "ChatPortraitTransformEditor(",
    "自定义立绘",
):
    assert token in chat, token
assert "duration: const Duration(milliseconds: 240)" not in chat

contract = read("lib/core/emotion/emotion_contract.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
for token in (
    "'crying': '伤心'",
    "'哭泣': 'crying'",
    "'羞耻': 'embarrassed'",
    "'尴尬': 'embarrassed'",
    "'无语': 'helpless'",
    "'情动': 'affection'",
    "'慌乱': 'flustered'",
):
    assert token in contract, token
assert "从兴奋、厌恶、伤心" in prompt
assert "从兴奋、厌恶、哭泣" not in prompt

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.37.3+92 APK (19-Expression Visual Parity)",
    "Restore pinned LingChat 19-expression presentation assets",
    "bash tools/fetch_lingchat_visual_assets.sh",
    "validate_v0373_expression_visual_parity.py",
    "AI-Companion-v0.37.3-92-19-Expression-Visual-Parity-APK.apk",
    ".ci/v0373-monitor.txt",
):
    assert token in workflow, token
for forbidden in (
    "Restore pinned LingChat 19emo ONNX payload",
    "onnxruntime-android:1.22.0",
    "EmotionWordPieceTokenizerTest",
):
    assert forbidden not in workflow, forbidden

assert not (
    ROOT / "android/app/src/main/assets/emotion_model_19emo/model.onnx"
).exists()
print("v0.37.3 19-expression visual parity and portrait customization validation passed")
