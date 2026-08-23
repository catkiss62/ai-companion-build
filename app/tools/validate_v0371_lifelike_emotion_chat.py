#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert "version: 0.37.1+90" in read("pubspec.yaml")
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
    "confidence >= 0.42",
    "margin >= 0.06",
    "source: 'llm'",
    "source: '19emo'",
    "EmotionEnvelope.streamingVisible(content)",
    "emotionClassifier.resolve(",
):
    assert token in contract + classifier + runner, token

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
catalog = read("lib/core/personality/personality_catalog.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
assert "从最具体处开始" in rules
assert "从不具体处开始" not in rules
for token in (
    "具体对话参照（只学反应因果，不照抄句子）",
    "_conversationExamples(b.key)",
    "<emotion>情绪</emotion>",
    "最终决定不发送，仍只输出 WAIT",
):
    assert token in catalog + prompt, token

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
bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/EmotionClassifierBridge.kt")
for token in (
    "onnxruntime-android:1.22.0",
    "EmotionClassifierBridge(this, flutterEngine)",
    '"input_ids" to inputIds',
    '"attention_mask" to attentionMask',
    "MODEL_BYTES = 60_004_728L",
):
    assert token in gradle + main + bridge, token

model = ROOT / "android/app/src/main/assets/emotion_model_19emo/model.onnx"
vocab = ROOT / "android/app/src/main/assets/emotion_model_19emo/vocab.txt"
mapping = ROOT / "android/app/src/main/assets/emotion_model_19emo/label_mapping.json"
assert model.stat().st_size == 60_004_728
assert sha256(model.read_bytes()).hexdigest() == "677b784abed285d22532df725b8e1947957a1d254b0c899a37a4a93a2a5b473e"
assert sha256(vocab.read_bytes()).hexdigest() == "45bbac6b341c319adc98a532532882e91a9cefc0329aa57bac9ae761c27b291c"
assert sha256(mapping.read_bytes()).hexdigest() == "925c356c9a692e8d6a0466cc8d1bc0d40c40cf0ccc5b59695916d925319d4a78"

print("v0.37.1 lifelike personality, 19emo and chat polish validation passed")
