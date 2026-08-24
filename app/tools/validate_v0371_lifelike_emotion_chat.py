#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert "version: 0.37.3+92" in read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
for token in (
    "static const int schemaVersion = 28;",
    "emotion_raw_tag TEXT NOT NULL DEFAULT ''",
    "emotion_confidence REAL NOT NULL DEFAULT 0",
    "'show_emotion_label': '1'",
):
    assert token in database, token

contract = read("lib/core/emotion/emotion_contract.dart")
classifier = read("lib/core/emotion/emotion_classifier_service.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
for token in (
    "class EmotionEnvelope",
    "labelsByKey",
    "minimaxByKey",
    "source: 'llm'",
    "EmotionEnvelope.streamingVisible(content)",
    "emotionClassifier.resolve(",
):
    assert token in contract + classifier + runner, token
assert contract.count("'") > 19
assert "MethodChannel" not in classifier
assert "source: '19emo'" not in classifier

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
catalog = read("lib/core/personality/personality_catalog.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
for token in (
    "具体对话参照（只学反应因果与排版，不照抄句子）",
    "_conversationExamples(b.key)",
    "<emotion>情绪</emotion>",
    "最终决定不发送，仍只输出 WAIT",
):
    assert token in catalog + prompt, token
assert "全角括号“（）”" in rules
assert "括号块后空一行" in rules + prompt

chat = read("lib/features/chat/chat_page.dart")
action = read("lib/widgets/action_tint_text.dart")
overlay = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
for token in (
    "show_emotion_label",
    "_currentEmotionLabel",
    "bubbleOpacity",
    "_followLatest",
    "FocusManager.instance.primaryFocus?.unfocus()",
    "fontStyle: FontStyle.italic",
    "fontWeight: FontWeight.normal",
    "hideKeyboard()",
    "exitChatInputMode()",
    "messageBubbleBackground",
    "StyleSpan(Typeface.NORMAL)",
):
    assert token in chat + action + overlay, token

gradle = read("android/app/build.gradle.kts")
main = read("android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt")
assert "onnxruntime" not in gradle.lower()
assert "EmotionClassifierBridge" not in main + overlay
assert not (ROOT / "android/app/src/main/kotlin/com/aicompanion/localfirst/EmotionClassifierBridge.kt").exists()
assert not (ROOT / "android/app/src/main/assets/emotion_model_19emo/model.onnx").exists()

print("v0.37.1 lifelike personality and 19-label contract remain present in v0.37.3")
