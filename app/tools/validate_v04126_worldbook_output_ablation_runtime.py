#!/usr/bin/env python3
"""Static contracts for v0.41.26 world-book/output-ablation runtime."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
self_reader = read("lib/core/agent/agent_self_reader.dart")
database = read("lib/core/database/app_database.dart")
rules = read("lib/core/rules/rule_layer_content_v04125.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
worldbook = read("lib/core/reference/world_book_presets.dart")
library = read("lib/core/reference/reference_library.dart")
model = read("lib/core/models/reference_document.dart")
editor = read("lib/features/reference/reference_document_editor_page.dart")
chat = read("lib/features/chat/chat_page.dart")
appearance_page = read("lib/features/self/personality_appearance_page.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
recovery = read("lib/core/ai/durable_generation_recovery.dart")
controller = read("lib/features/chat/chat_controller.dart")
proactive_engine = read("lib/core/desire/proactive_engine.dart")
operation_guard = read("lib/core/grounding/operational_claim_grounding_guard.dart")
memory = read("lib/core/ai/memory_extractor.dart")
render = read("lib/widgets/action_tint_text.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
immersive = read("lib/core/immersive/immersive_prompt_builder.dart")
somatic = read("lib/core/somatic/somatic_policy.dart")
proactive = read("lib/core/desire/proactive_presentation.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert "version: 0.41.26+165" in pubspec
assert "buildLabel = 'v0.41.26+165'" in self_reader
assert "static const int schemaVersion = 45" in database
assert "_createV45WorldBookColumns" in database
assert "worldbook_runtime_v04126_applied" in database
assert "reference_documents WHERE builtin = 0" in database

for token in (
    "你是小鲸鱼，是用户的女性 AI 伴侣",
    "用户是成年男性",
    "你不是服务者",
    "自己的判断与意愿",
    "“傻逼”“儿子”“哥哥”“宝贝”",
    "不是固定词库",
):
    assert token in rules, token
assert "擅长自然造梗" not in rules
assert "'01_relationship': ''" in rules
assert "'03_behavior': ''" in rules
assert "'03_personality_seed': ''" in rules

for token in (
    "builtin.worldbook.action_expression",
    "builtin.worldbook.anti_template",
    "builtin.worldbook.humor_experiment",
    "probability: 20",
    "manualActive: true",
):
    assert token in worldbook, token
assert "activationMode" in model
assert "activationProbability" in model
assert "exclusiveGroup" in model
assert "Future<WorldBookPromptBundle> behaviorForPrompt" in library
assert "worldbook_activation_" in library
assert "final turnFingerprint = _stableHash(turnKey).toString()" in library
assert "${item.name} ${item.aliases.join(' ')}" in library
assert "${item.name} ${item.aliases.join(' ')} ${item.rawContent}" not in library
assert "不得覆盖真实身份" in library
assert "entryType == 'behavior'" in editor
assert "优先级" in editor and "本轮触发概率" in editor
assert "_openWorldBookQuickPanel" in chat
assert "Icons.auto_stories_outlined" in chat
assert "PersonalityLabPage" not in chat
assert "默认不注入性格种子" in appearance_page
assert "updateRuleLayer(_personalityKey" not in appearance_page
assert "03_personality_seed" in defaults
assert "'09_action_expression_experiment'" in defaults

assert "text: finalContent" in runner
assert "output_ablation_last_pronoun_slip_at" in runner
assert "action: 'observe'" in runner
assert "removeUnsupportedSentences" in runner
assert "interruptGenerationJob(" not in runner
assert "recoverable: _recoverable(e)" in runner
assert "if (error is FormatException) return true" in runner
assert "final result = await runner.run(job)" in recovery
assert "cancelGenerationJobByUser(job.id)" not in recovery
assert "current_process_exception" in controller
assert "trusted_process_exception" in controller
dispose_body = controller[controller.rindex("void dispose()") :]
assert "_activeGenerationCancellation?.cancel()" not in dispose_body
assert "action: 'observe'" in proactive_engine
assert "service_template_block" not in proactive_engine
assert "removeUnsupportedSentences" in proactive_engine
assert "Drops only sentences" in operation_guard
assert "不会因为口误、称呼、语气或表达风格中断整轮" in prompt
assert "普通聊天正文严格遵守规则02" not in prompt
assert "面对恋人自然想" not in prompt
assert "受临时表达模块影响的措辞" in memory

assert "!hasExplicitDialogue || segment.isDialogue" in render
assert "listOf(value.indices)" in overlay
assert "ReferenceLibrary" in immersive
assert "scope: 'immersive'" in immersive
assert "应用内双感官通道提供的真实内部状态" in somatic
assert "sourceType == 'user_history' || sourceType == 'memory'" in proactive
assert "明确允许用户晚点回复" not in proactive

for token in (
    "Build AI Companion v0.41.26+165 APK (World Book Output Ablation Runtime)",
    "agent/v04126-worldbook-output-ablation-runtime",
    "AI-Companion-v0.41.26-165-World-Book-Output-Ablation-Runtime-APK",
    "validate_v04126_worldbook_output_ablation_runtime.py",
    ".ci/v04126-monitor.txt",
):
    assert token in workflow, token

print("v0.41.26 world-book/output-ablation runtime validation passed")
