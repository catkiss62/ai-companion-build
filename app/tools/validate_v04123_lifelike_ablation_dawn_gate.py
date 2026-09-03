#!/usr/bin/env python3
"""Static contracts for v0.41.23 lifelike ablation and dawn Gate repair."""

from pathlib import Path
import re


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
rules = read("app/lib/core/rules/rule_layer_content_v0353.dart")
experiment = read("app/lib/core/rules/rule_layer_content_v04123.dart")
defaults = read("app/lib/core/rules/rule_layer_defaults.dart")
grouping = read("app/lib/core/rules/rule_layer_grouping.dart")
dialogue = read("app/lib/core/ai/dialogue_expression_plan.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
memory = read("app/lib/core/ai/memory_extractor.dart")
dawn = read("app/lib/core/desire/proactive_dawn_gate_policy.dart")
outcome = read("app/lib/core/desire/proactive_outcome_fit_policy.dart")
proactive = read("app/lib/core/desire/proactive_engine.dart")
rhythm = read("app/lib/core/desire/proactive_rhythm_engine.dart")
dialogue_test = read("app/test/dialogue_expression_plan_test.dart")
dawn_test = read("app/test/proactive_dawn_gate_policy_test.dart")
outcome_test = read("app/test/proactive_outcome_fit_policy_test.dart")
rules_test = read("app/test/rule_layer_defaults_test.dart")
prompt_test = read("app/test/prompt_generation_reminder_test.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert re.search(r"^version:\s*0\.41\.23\+162\s*$", pubspec, re.MULTILINE)
assert "static const int schemaVersion = 44;" in database
assert "buildLabel = 'v0.41.23+162'" in self_reader

for token in (
    "DialogueResponseMode.feedback",
    "seed % 100 < 30",
    "先把它当作真实反馈",
    "不要反射性自证人格",
    "可编辑动作神态实验规则",
    "不要把这段检查写进可见思考或正文",
):
    assert token in dialogue, token

for token in (
    "【直接反馈与认识边界】",
    "不把它脑补成调情、激将、斗嘴邀请",
    "承认失手、没逗笑、没听懂或一时卡住",
    "不替用户命名情绪",
    "表态—解释—反问/挑战—收尾",
    "它是低剂量副产物，不是每轮任务",
    "允许“确实没做好”成为完整反应",
):
    assert token in rules, token
for rejected in (
    "我就是抖M",
    "怪不得你挨两句损就开始精神抖擞",
    "普通聊天示例：只学节奏与反应",
):
    assert rejected not in rules, rejected

for token in (
    "零或一段短动作",
    "不强制每轮出现",
    "不要写“动作—对白—动作”的夹心结构",
    "不替用户写动作、表情、身体反应、台词或内心",
    "清空或停用本规则即为纯对白对照组",
):
    assert token in experiment, token
assert "09_action_expression_experiment" in defaults
assert "ruleContentV04123ActionExpressionExperiment" in defaults
assert "09_action_expression_experiment': '02'" in grouping
assert "legacyEditableRuleLayerSha256V04122LifelikeRevision" in defaults
assert "...legacyEditableRuleLayerSha256V04122LifelikeRevision.entries" in database
for token in (
    "ordinaryActionExperimentActive",
    "当前动作神态消融实验已启用",
    "当前动作神态消融实验未启用或内容为空",
    "layer.content.trim().isNotEmpty",
):
    assert token in prompt, token
assert "action-expression reminder has removable A/B branches" in prompt_test

for token in (
    "now.hour >= 5",
    "now.hour < 9",
    "activityContext == 'screen_off'",
    "maxIdleBoost = 0.04",
    "thresholdPenalty = 0.10",
    "suppressLongIdleRelief: true",
):
    assert token in dawn, token
for token in (
    "ProactiveDawnGatePolicy.adjust",
    "dawnAdjustment.suppressLongIdleRelief",
    "dawnAdjustment.thresholdPenalty",
    "'dawnScreenOff': dawnAdjustment.active",
):
    assert token in proactive, token
assert "hour < 5" in rhythm
assert "hour < 9" in rhythm
assert "return 'dawn'" in rhythm
assert "ProactiveOutcomeFitPolicy.timing" in rhythm
assert "ProactiveOutcomeFitPolicy.topic" in rhythm

for token in (
    "outcome == 'deferred'",
    "return value < -0.60 ? value : -0.60",
    "latency > 2 * 3600",
    "return value < -0.15 ? value : -0.15",
):
    assert token in outcome, token
assert "ProactiveOutcomeFitPolicy.timing" in memory
assert "ProactiveOutcomeFitPolicy.topic" in memory

for token in (
    "direct negative feedback is literal",
    "lower thirty hash buckets",
    "DialogueResponseMode.feedback",
):
    assert token in dialogue_test, token
for token in (
    "screen-off dawn removes long-idle acceleration",
    "strong intent still has a score path",
):
    assert token in dawn_test, token
for token in (
    "deferred can never teach a positive delivery time",
    "three-hour and very late replies cannot reinforce timing",
):
    assert token in outcome_test, token
for token in (
    "09_action_expression_experiment",
    "清空或停用本规则即为纯对白对照组",
    "legacyEditableRuleLayerSha256V04122LifelikeRevision.length, 5",
):
    assert token in rules_test, token

for token in (
    "Build AI Companion v0.41.23+162 APK (Lifelike Ablation Dawn Gate)",
    "agent/v04123-lifelike-ablation-dawn-gate",
    "AI-Companion-v0.41.23-162-Lifelike-Ablation-Dawn-Gate-APK",
    "validate_v04123_lifelike_ablation_dawn_gate.py",
    ".ci/v04123-monitor.txt",
):
    assert token in workflow, token

for token in (
    "v0.41.23",
    "不设“深夜至 9 点最多一条”硬上限",
    "活人感消融",
    "schema 44",
    "Phase 2B/3/4 继续关闭",
):
    assert token in ledger, token

print("v0.41.23 lifelike ablation and dawn Gate validation passed")
