#!/usr/bin/env python3
"""Static contracts for v0.41.30 presentation/ablation/upload diagnostics."""

from pathlib import Path


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
presentation = read("app/lib/core/presentation/generation_presentation_policy.dart")
chat_page = read("app/lib/features/chat/chat_page.dart")
chat_controller = read("app/lib/features/chat/chat_controller.dart")
grouping = read("app/lib/core/rules/rule_layer_grouping.dart")
rules_page = read("app/lib/features/settings/rule_layers_page.dart")
attachment = read("app/lib/core/diagnostics/attachment_pipeline_telemetry.dart")
ablation = read(
    "app/lib/core/diagnostics/conversation_initiative_ablation_telemetry.dart"
)
runner = read("app/lib/core/ai/durable_generation_runner.dart")
preflight = read("app/lib/core/diagnostics/preflight_diagnostics.dart")
personality_page = read("app/lib/features/self/personality_appearance_page.dart")
moe_default = read("app/lib/core/integration/moe_expression_default_policy.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert "version: 0.41.30+169" in pubspec
assert "static const int schemaVersion = 45;" in database
assert "buildLabel = 'v0.41.30+169'" in self_reader

for token in (
    "typewriterPlaybackReady",
    "markPresentedOnDiscovery",
    "animateRequested && !generationActive",
):
    assert token in presentation, token
for token in (
    "playbackReady: typewriterPlaybackReady",
    "!oldWidget.playbackReady && widget.playbackReady",
    "unawaited(_markLatestAssistantPresented())",
):
    assert token in chat_page, token

for token in (
    "migratedEmptyRuleLayerPlaceholderKeys",
    "01_relationship",
    "02_daily",
    "03_behavior",
    "03_personality_seed",
    "09_action_expression_experiment",
    "isHiddenMigratedRuleLayerPlaceholder",
):
    assert token in grouping, token
for token in (
    "editableRuleLayerGroup(group)",
    "hiddenMigratedRuleLayerPlaceholderCount(group)",
    "底层 key 与导出仍保留",
):
    assert token in rules_page, token

for token in (
    "moe_expression_default_v04130_applied",
    "enabledValue = '1'",
    "expressionMode = 'obvious'",
    "marker != '1'",
):
    assert token in moe_default, token
assert "MoeExpressionDefaultPolicy.shouldApply" in database
assert "新版本默认开启并使用“明显”" in personality_page

for token in (
    "attachment_pipeline_telemetry_v1",
    "durationBucket",
    "byteBucket",
    "pixelBucket",
    "possible && preceding != null",
    "rawErrorsIncluded': false",
    "causalityEstablished': false",
):
    assert token in attachment, token
for token in (
    "stage: 'picker'",
    "stage: 'overlay_guard'",
    "stage: 'prepare'",
):
    assert token in chat_page, token
for token in ("stage: 'commit'", "stage: 'vision'"):
    assert token in chat_controller, token

for token in (
    "conversation_initiative_ablation_v1",
    "PromptResponsibilityShape",
    "rawReasonCounts",
    "finalReasonCounts",
    "layerCorrelations",
    "safetyOrIdentityLayersRemoved': false",
):
    assert token in ablation, token
for token in (
    "rawExpressionVerification",
    "promptResponsibilityShape",
    "ablationTransformation",
    "ConversationInitiativeAblationTelemetry.record",
):
    assert token in runner, token
for token in (
    "attachmentPipeline",
    "attachmentAnrCorrelation",
    "conversationInitiativeAblation",
):
    assert token in preflight, token

for token in (
    "Build AI Companion v0.41.30+169 APK (Presentation + Ablation + Upload Diagnostics)",
    "agent/v04130-presentation-ablation-upload-diagnostics",
    "AI-Companion-v0.41.30-169-Presentation-Ablation-Upload-Diagnostics-APK",
    "validate_v04130_presentation_ablation_upload_diagnostics.py",
    ".ci/v04130-monitor.txt",
):
    assert token in workflow, token
for token in (
    "v0.41.30 呈现、上传诊断与 Phase 2A.5 责任消融",
    "不删除、重排或重新编号 rule layer 稳定 key",
    "不提前打开 Phase 2B",
):
    assert token in ledger, token

print("v0.41.30 presentation/ablation/upload diagnostics validation passed")
