#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
reference = read("lib/core/reference/reference_library.dart")
history = read("lib/core/reference/world_book_history_policy.dart")
presets = read("lib/core/reference/world_book_presets.dart")
immersive = read("lib/core/rules/rule_layer_content_immersive.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert "version: 0.41.41+180" in pubspec
assert "static const int schemaVersion = 53;" in database
assert "_stabilizeV53RoleplayPronounPriority" in database
assert "legacyRuleContentV04125_08RuntimeIdentity" in database
for name, priority in {
    "角色表达自然化": 1000,
    "日常对话规则": 950,
    "性格光谱": 850,
    "造梗能力": 650,
}.items():
    assert f"'{name}': {priority}" in presets

for source in (prompt, reference):
    assert "同一个小鲸鱼" in source
    assert "未声明部分" in source
assert "场景身份的完整接管" not in prompt
assert "角色卡完整决定" not in reference
assert "continuityBeforeRetainedTurns" in prompt
assert "continuityBeforeRetainedTurns" in history
assert "消息的说话者只由消息 role 决定" in prompt
assert "不得把用户明确写出的名词擅自替换" in prompt

# Immersive narration is deliberately unchanged: AI=她, user=你.
assert "AI角色在正文中始终写作“她”" in immersive
assert "成年男性用户在正文中始终写作“你”" in immersive
assert "固定“她/你”人称坐标" in immersive

assert (
    "Build AI Companion v0.41.41+180 APK" in workflow
    or "Build AI Companion v0.41.42+181 APK" in workflow
    or "Build AI Companion v0.41.43+182 APK" in workflow
    or "Build AI Companion v0.41.44+183 APK" in workflow
    or "Build AI Companion v0.41.45+184 APK" in workflow
)
assert (
    "AI-Companion-v0.41.41-180-Roleplay-Pronoun-Priority-APK" in workflow
    or "AI-Companion-v0.41.42-181-Phase3A-Interest-Evidence-APK" in workflow
    or "AI-Companion-v0.41.43-182-Phase3B-Question-Autonomy-APK" in workflow
    or "AI-Companion-v0.41.44-183-Autonomy-Arbitration-Rework-APK" in workflow
    or "AI-Companion-v0.41.45-184-Sticker-Expression-APK" in workflow
)
print("v0.41.41 roleplay/pronoun/priority validation passed")
