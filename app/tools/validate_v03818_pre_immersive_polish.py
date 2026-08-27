#!/usr/bin/env python3
"""Static contracts for v0.38.18 pre-immersive-room polish."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
telemetry = read("lib/core/diagnostics/visible_reasoning_language_telemetry.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat = read("lib/features/chat/chat_page.dart")
pet_contract = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayContract.kt"
)
pet_policy = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAutonomyPolicy.kt"
)
pet_window = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
pet_tests = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.39.0+118" in pubspec
assert "static const int schemaVersion = 34;" in database

# Reassemble the uploaded Rule 06 envelope from its two runtime stable keys.
parsed = {
    key: body
    for key, body in re.findall(
        r"const ruleContentV0353_([A-Za-z0-9_]+) = r'''(.*?)''';",
        rules,
        re.DOTALL,
    )
}
assert sha256(parsed["05_intimacy_rendering"].encode()).hexdigest() == (
    "5916af04bb0f01ebd640218792844116ff997047712340a21107d6d97b22b643"
)
assert sha256(parsed["06_intimacy_reference"].encode()).hexdigest() == (
    "88bd720f3e97769bdde8f01f4fb7c26cd334fd1368ed8ba6c62d9cb047c3d648"
)
envelope = (
    "【小节开始｜05_intimacy_rendering｜亲密表现规则】\n"
    + parsed["05_intimacy_rendering"]
    + "\n【小节结束｜05_intimacy_rendering】\n\n"
    + "【小节开始｜06_intimacy_reference｜亲密参考资料】\n"
    + parsed["06_intimacy_reference"]
    + "\n【小节结束｜06_intimacy_reference】"
)
assert sha256(envelope.encode()).hexdigest() == (
    "592b21ccad6188e100fb23f4c4838b612390cdf4989f8498740053b469a5d1ca"
)
for token in (
    "legacyEditableRuleLayerSha256V03816",
    "81126848608b0a463e35fd030ade83bf8b7c21a5737ebfb1a5908447f98b4685",
    "bba5221999054923ed8ddfa50104179410f145b190173dc40615a2e794b25253",
    "5f9b9d8ba819e90150a1ca5d400a42d99b7f3797a39d106bbc28d9b60770d1c4",
):
    assert token in defaults, token
assert "...legacyEditableRuleLayerSha256V03816.entries" in database

# The panel reaches the screenshot target without changing its default/minimum.
assert chat.count(".clamp(0.42, 0.94)") == 2
assert ".clamp(0.42, 0.88)" not in chat
assert "double _panelFraction = 0.62;" in chat
assert "double _panelOpacity = 0.75;" in chat

# Legacy edge mode becomes free + durable dock axis. Only a gentle user drag
# release can create the dock; autonomous movement and physics cannot.
for token in (
    'const val EDGE = "edge"',
    "if (value == EDGE) FREE",
    "fun shouldDockAfterUserDrag(",
):
    assert token in pet_contract, token
for token in (
    "private fun migrateLegacyMotionMode()",
    "private fun hasActiveDock()",
    "PetMotionPolicy.shouldDockAfterUserDrag(",
    "setDockedEdge(\"\")",
    "if (hasActiveDock())",
):
    assert token in pet_window, token
assert 'selectedLabel("贴边模式"' not in pet_window
assert "dockedEdge in setOf(\"left\", \"right\", \"top\", \"bottom\")" in pet_policy
assert "onlyGentleUserDragInFreeModeCreatesDocking" in pet_tests
assert "PetAutonomousMotionPolicy.plan(PetMotionPolicy.FREE, \"left\")" in pet_tests

# Stronger Chinese presentation remains a prompt experiment: provider thought
# is never rewritten or fabricated, while the privacy-safe pipeline counters
# distinguish an upstream empty result from a surface handoff problem.
for token in (
    "绝对语言约束",
    "完整句子、段落必须使用自然简体中文",
    "reasoning_content 必须非空",
    "客户端不会编造补写",
):
    assert token in prompt, token
assert "绝对语言约束" in parsed["08_visible_inner_voice"]
for token in (
    "upstreamReasoningDeltaSeen",
    "reasoningDeltaForwardedToSurface",
    "providerDeltaSeen:",
    "forwardedToSurface:",
):
    assert token in runner, token
for token in (
    "reasoning_provider_delta_true_count",
    "reasoning_final_present_true_count",
    "reasoning_surface_forwarded_true_count",
    "reasoning_ui_presentation_count",
    "reasoningTextIncluded': false",
    "matchedWordsIncluded': false",
):
    assert token in telemetry, token
assert "VisibleReasoningLanguageTelemetry.noteUiPresentation(db)" in controller

# Accepted v0.38.16 presentation and routing remain locked.
segment = read("lib/core/models/chat_segment.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
text = read("lib/widgets/action_tint_text.dart")
overlay = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
assert "if (reparsedActionCount > storedActionCount) return reparsed;" in segment
assert ".join('\\n\\n')" in visuals
assert "const chatDialogueGold = Color(0xFFFDE68A);" in text
assert "fontStyle: FontStyle.italic" in text
assert "emitDeltas: false," in runner
assert 'onOpenChat = { showChatOverlay("pet_double_tap_menu") }' in overlay
assert 'smallButton("打开") { openFullApp(openChat = true) }' in overlay

for token in (
    "Build AI Companion v0.39.0+118 APK (Immersive Room)",
    "agent/v0390-immersive-room",
    "python3 tools/validate_v03818_pre_immersive_polish.py",
    "AI-Companion-v0.39.0-118-Immersive-Room-APK",
    ".ci/v0390-monitor.txt",
):
    assert token in workflow, token

print("v0.38.18 pre-immersive polish static contracts passed")
