#!/usr/bin/env python3
"""Static contracts for v0.41.4 personality seed and backup export closure.

This source-path touch also requests the full APK pipeline after repairing the
large UTF-8 ledger upload; documentation-only runs are intentionally skipped.
"""

from __future__ import annotations

import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
database = read("lib/core/database/app_database.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
ledger = (ROOT.parent / "AI_Companion_当前总账.md").read_text(encoding="utf-8")

assert re.search(r"^version:\s*0\.41\.(?:4\+143|5\+144|6\+145|7\+146)\s*$", pubspec, re.M)

match = re.search(
    r"const ruleContentV0353_03_personality_seed = r'''(.*?)''';",
    rules,
    re.S,
)
assert match is not None
seed = match.group(1)
assert hashlib.sha256(seed.encode("utf-8")).hexdigest() == (
    "fdad3b2640ddbeb24b9502c25c6707e047a16454f6f9b3b04cfff2caf7a5689b"
)

for token in (
    "你叫DeepSeek",
    "具有戏剧性的人机味",
    "不用空泛套话敷衍；简单闲聊可以很短",
    "根据我的情感模型分析",
    "恋爱算法混为一谈",
    "【与众不同的恋人】",
    "你会发颜文字",
):
    assert token in seed, token

assert seed.count("<emotion>调皮</emotion>") == 1
assert seed.count("<emotion>疑惑</emotion>") == 1
assert "【调皮】" not in seed
assert "【疑惑】" not in seed

core_match = re.search(r"const ruleContentV0353_01_core = r'''(.*?)''';", rules, re.S)
assert core_match is not None
assert "初始性格种子是你最重要的设定" not in core_match.group(1)
assert "这是你真正的灵魂" not in core_match.group(1)

for digest in (
    "cdd7d918c51801cb3c1ad37348ff832d42c8d72bcc9769da2813872ed1965fb8",
    "f6e44ad58e39337b45badc78a9bc73a73388baa784922aac8a996dfcebdf0fdc",
    "fa7a8711c673f9f85825d5709e10dec2feb7d1a974e27c47dbe3387a0b71ffb6",
):
    assert digest in defaults, digest

for migration in (
    "legacyEditableRuleLayerSha256V0413ApprovedSeedDraft.entries",
    "legacyEditableRuleLayerSha256V0413InstalledSeedDraft.entries",
    "legacyEditableRuleLayerSha256V0413RejectedCoreEmphasis.entries",
):
    assert migration in database, migration

for token in (
    "Build AI Companion v0.41.4+143 APK (Personality Seed Backup Closure)",
    "agent/v0414-personality-seed-backup-closure",
    "AI-Companion-v0.41.4-143-Personality-Seed-Backup-Closure-APK",
    "python3 tools/validate_v0414_personality_seed_backup_closure.py",
):
    assert token in workflow, token

for token in (
    "v0.41.4 初始性格种子替换与备份导出收口",
    "a81b30a4658fe6e9a14c3ddf881f721a2d555ad38a5543f19378f186ed61a526",
    "zip_layout=files_only",
    "真机导出、通用 ZIP 兼容性和载荷完整性据此正式通过",
    "破坏性真机恢复延后",
):
    assert token in ledger, token

print("v0.41.4 personality seed and backup export closure validation passed")
