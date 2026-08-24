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

contract = read("lib/core/emotion/emotion_contract.dart")
classifier = read("lib/core/emotion/emotion_classifier_service.dart")
for token in (
    "_complete.allMatches(raw)",
    "_stripReservedMarkup(raw)",
    "streamingVisible(String raw)",
    "EmotionCatalog.isCanonicalLabel(candidate)",
):
    assert token in contract, token
for forbidden in ("MethodChannel", "_classifyOnAndroid", "source: '19emo'"):
    assert forbidden not in classifier, forbidden
assert "source: 'llm'" in classifier
assert "labelsByKey" in contract and contract.count("'affection': '心动'") == 1

runner = read("lib/core/ai/durable_generation_recovery.dart")
assert "cancelGenerationJobByUser(job.id)" in runner
assert "runner.run(job)" not in runner
assert "must never resend an LLM" in runner

chat = read("lib/features/chat/chat_page.dart")
assert "header label only changes" in chat
assert "legacy visual presentation label" in chat
streaming_block = chat[chat.index("if (controller.streamingContent.trim().isNotEmpty)"):chat.index("} else {", chat.index("if (controller.streamingContent.trim().isNotEmpty)"))]
assert "_currentEmotionLabel =" not in streaming_block

prompt = read("lib/core/ai/prompt_builder.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
segments = read("lib/core/models/chat_segment.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
for token in (
    "必须严格从兴奋、厌恶、伤心",
    "不得自造标签",
    "绝不能在正文中重复或解释",
):
    assert token in prompt, token
for token in (
    "全角括号“（）”",
    "括号块后空一行",
    "动作与对白混插",
):
    assert token in rules, token
for token in (
    "quotedLine",
    "ChatSegmentKind.action",
    "return '（${segment.text}）';",
    "join('\\n\\n')",
):
    assert token in segments + visuals, token

gradle = read("android/app/build.gradle.kts")
main = read("android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt")
overlay = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
assert "onnxruntime" not in gradle.lower()
assert "EmotionClassifierBridge" not in main + overlay
assert not (ROOT / "android/app/src/main/kotlin/com/aicompanion/localfirst/EmotionClassifierBridge.kt").exists()
assert not (ROOT / "android/app/src/test/kotlin/com/aicompanion/localfirst/EmotionWordPieceTokenizerTest.kt").exists()

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.37.3+92 APK",
    "validate_v0372_emotion_crash_hotfix.py",
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

print("v0.37.2 emotion crash, Stop semantics and action-format hotfix validation passed")
