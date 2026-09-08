#!/usr/bin/env python3
"""Structural, migration and privacy contracts for v0.41.49."""

from pathlib import Path
import hashlib
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
self_reader = read("lib/core/agent/agent_self_reader.dart")
presets = read("lib/core/reference/world_book_presets.dart")
expression = read("lib/core/ai/dialogue_expression_plan.dart")
prompt_builder = read("lib/core/ai/prompt_builder.dart")
seed = read("lib/core/autonomy/subjective_search_seed.dart")
planner = read("lib/core/autonomy/public_web_question_planner.dart")
engine = read("lib/core/autonomy/public_web_discovery_engine.dart")
appraiser = read("lib/core/autonomy/public_web_deepseek_appraiser.dart")
policy = read("lib/core/autonomy/public_web_appraisal_policy.dart")
models = read("lib/core/models/public_web_candidate.dart")
tests = "\n".join(
    read(path)
    for path in (
        "test/dialogue_expression_plan_test.dart",
        "test/subjective_search_seed_v04149_test.dart",
        "test/public_web_appraisal_policy_v04115_test.dart",
        "test/public_web_deepseek_appraiser_v04139_test.dart",
        "test/immersive_nsfw_contract_v04127_test.dart",
    )
)
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(r"^version:\s*0\.41\.49\+188$", pubspec, re.M)
assert "static const int schemaVersion = 56;" in database
assert "buildLabel = 'v0.41.49+188'" in self_reader
assert "agent/v04149-subjective-search-humor-restoration" in workflow
assert "Build AI Companion v0.41.49+188 APK" in workflow
assert "AI-Companion-v0.41.49-188-Subjective-Search-Humor-Restoration-APK" in workflow

# The reviewed narrow v0.41.28 prompt is upgraded only on its exact hash, so
# user-edited documents are never silently overwritten.
old_match = re.search(
    r"const worldBookOptimizedHumorV04128 = '''(.*?)''';", presets, re.S
)
new_match = re.search(r"const worldBookHumorV04149 = '''(.*?)''';", presets, re.S)
assert old_match and new_match
old_prompt = old_match.group(1)
new_prompt = new_match.group(1)
assert hashlib.sha256(old_prompt.encode()).hexdigest() == (
    "6824849b04965f021bbbc1856fb009c598ede4ce5dc442fe14f44d57b4789900"
)
assert "reviewedNarrowHumorSha256" in database
assert "worldBookHumorV04149" in database
assert "worldbook_humor_restore_v04149_applied" in database
assert 2400 <= len(new_prompt) <= 5000
for mechanism in (
    "谐音变异",
    "暴力拼接",
    "冷面荒谬",
    "场景小剧场 / 抽象舞台",
    "临时身份错位",
    "日常事件史诗化",
    "语义急转",
    "列举式发癫",
    "文体戏仿",
    "无意义庄严 / 废话文学",
    "活字拆解与反义突变",
    "情绪雪崩",
    "受控语言破坏",
    "语境内接梗",
):
    assert mechanism in new_prompt
for capability in (
    "可以自导自演、扮演所有临时角色、模仿用户、给物件配音",
    "可以说粗口、荤话或黑色幽默",
    "作为一名从业二十年的资深冰箱",
):
    assert capability in new_prompt
for forbidden in ("**", "{{char}}", "{{user}}", "CORE DIRECTIVE", "No Immunity"):
    assert forbidden not in new_prompt

# Humor is positively selected from context and her own state. No second
# probability gate disables the full prompt, and the concrete card reaches the
# model without Markdown star emphasis.
for device in (
    "homophonicMutation",
    "violentStitching",
    "deadpanNonsense",
    "microTheater",
    "identityMismatch",
    "epicMundanity",
    "semanticSwerve",
    "enumerationMania",
    "genreParody",
    "meaninglessNonsense",
    "characterMutation",
    "emotionalAvalanche",
    "linguisticMutilation",
    "joinTheBit",
):
    assert device in expression
assert "subjectivePlayfulness" in expression and "hasOwnThought" in expression
assert "【本轮造梗执行卡】" in expression
assert "const humor = DialogueHumorDevice.none" not in expression
assert "不分配笑点类型" not in expression
for prompt_source in (
    presets,
    expression,
    read("lib/core/rules/rule_layer_content_v0400.dart"),
):
    assert "**" not in prompt_source
assert "all eleven primary mechanisms are reachable" in tests
assert "own state raises opportunity" in tests

# Subjective search exports only bounded categories and a one-way hash. Raw
# Thought/chat/device/memory/roleplay bodies never enter the planner payload.
assert "class SubjectiveSearchSeed" in seed
assert "21600000" in seed
for private_source in (
    "thought.text",
    "intent.reason",
    "latestUserText",
    "recentMessages",
    "MemoryItem",
    "roleplay",
):
    assert private_source not in seed
for public_field in (
    "motive_kind",
    "felt_state",
    "why_now",
    "question_direction",
    "seed_hash",
    "source_kinds",
):
    assert public_field in seed
assert "subjective_seed" in planner
assert "public_fallback" in planner
assert "taxonomy_fallback" in planner
assert "subjective_generated_question" in planner
assert "SubjectiveSearchSeedPolicy.build" in engine
assert "${subjectiveSeed.seedHash}" in engine
assert "public_web_last_subjective_motive" in engine
assert "public_web_last_subjective_seed_hash" in engine

# Knowledge value and felt value are independent and all subjective fields
# survive appraisal, persistence, prompt retrieval and redacted diagnostics.
for field in (
    "resonanceScore",
    "surpriseScore",
    "selfRelevanceScore",
    "motiveKind",
    "whyCared",
    "subjectiveSeedHash",
):
    assert field in models
for column in (
    "resonance_score",
    "surprise_score",
    "self_relevance_score",
    "motive_kind",
    "why_cared",
    "subjective_seed_hash",
):
    assert column in database
assert "_createV56SubjectiveSearchColumns" in database
assert "why_cared" in appraiser and "motive_kind" in appraiser
assert "subjectiveValue" in policy
assert "item.whyCared" in prompt_builder
assert "whyCaredPresent" in database
assert "whyCaredBodyIncluded': false" in database
assert "subjectiveSeedHashIncluded': false" in database

print("v0.41.49 subjective search + humor restoration validation passed")
