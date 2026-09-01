#!/usr/bin/env python3
"""Validate the compact handoff index without rewriting preserved history."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "AI_Companion_当前总账.md"
PUBSPEC = ROOT / "app" / "pubspec.yaml"
DATABASE = ROOT / "app" / "lib" / "core" / "database" / "app_database.dart"

ARCHIVE_MARKER = "## 历史工作记录（原文保留，按需检索）"
ARCHIVE_START = (
    "## 0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA. "
    "2026-08-31 · v0.41.5"
)
ARCHIVE_SHA256 = "7f44e0f6ac43ca62726d8547fc1cc7a46353f9b2c8e3e498b0f4027d30794628"
ARCHIVE_LEVEL_2_COUNT = 105
ARCHIVE_LEVEL_3_COUNT = 413


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    ledger = LEDGER.read_text(encoding="utf-8")
    require(ledger.count(ARCHIVE_MARKER) == 2, "archive marker contract changed")
    # One occurrence is the read-stop instruction; the second is the heading.
    marker_index = ledger.index("\n" + ARCHIVE_MARKER + "\n")
    current = ledger[:marker_index]
    archive_start = ledger.index(ARCHIVE_START, marker_index)
    archive = ledger[archive_start:]

    require(
        hashlib.sha256(archive.encode("utf-8")).hexdigest() == ARCHIVE_SHA256,
        "preserved ledger archive was modified; add current records above the marker",
    )
    require(
        len(re.findall(r"^## ", archive, flags=re.MULTILINE))
        == ARCHIVE_LEVEL_2_COUNT,
        "preserved level-2 section count changed",
    )
    require(
        len(re.findall(r"^### ", archive, flags=re.MULTILINE))
        == ARCHIVE_LEVEL_3_COUNT,
        "preserved level-3 section count changed",
    )

    required_sections = (
        "### 1. 接班与减负读取协议",
        "### 2. 当前唯一有效基线",
        "### 3. 当前模块状态总表",
        "### 4. 当前任务总表",
        "### 5. 永久不可变边界与高频踩坑",
        "### 6. 低优先级已知问题",
        "### 7. 按模块回读历史的导航表",
        "### 8. 历史档案覆盖说明",
        "### 9. 2026-08-31 · 总账减负交接层",
        "### 16. 2026-09-01 · v0.41.10 人格学习证据归因热修",
        "### 18. 2026-09-01 · v0.41.13 Phase 0+1 审查与时间加固",
        "### 19. 2026-09-01 · v0.41.14 Agent 操作事实真实性与用户单次屏幕观察",
        "### 20. 2026-09-02 · Self-Drive、欲望数值与自主联网成长审计",
    )
    for section in required_sections:
        require(section in current, f"missing current handoff section: {section}")

    required_facts = (
        "agent/v0416-agent-self-facts",
        "agent/v0417-forthright-fiery-personality",
        "agent/v0418-personality-trial-strength-hotfix",
        "agent/v0415-ledger-handoff-index",
        "agent/v0415-personality-state-diversity",
        "494796ef02e369f98e6896bc5acea7185e3c35dd",
        "bc72196a33660a63cc9953b577486e70449856fc",
        "574e87efecfd9e581ec5ee4b9378267cf0dc5d0b",
        "0.41.5+144",
        "schema 40",
        "33386230422",
        "e127d713dfc9044c2c25f2752836e7b65917863e3d0c192fb62896c5ed9943c6",
        "NOT_IMPLEMENTED",
        "SUPERSEDED",
        "System Facts / Recent Outcomes",
        "mcp.invoke executable=false",
        "偶尔多出一个 `「`",
    )
    for fact in required_facts:
        require(fact in current, f"missing current handoff fact: {fact}")

    for history_range in (
        "v0.41.5～v0.41.0",
        "v0.40.9～v0.40.0",
        "v0.39.9～v0.39.0",
        "v0.38.18～v0.38.5",
        "v0.38.4～v0.37.0",
        "v0.36.x～v0.35.7",
        "旧编号 0～10.19",
    ):
        require(history_range in current, f"missing history coverage range: {history_range}")

    pubspec = PUBSPEC.read_text(encoding="utf-8")
    database = DATABASE.read_text(encoding="utf-8")
    require(
        re.search(r"^version:\s*0\.41\.15\+154\s*$", pubspec, re.MULTILINE)
        is not None,
        "pubspec version no longer matches the current development baseline",
    )
    require(
        "static const int schemaVersion = 43;" in database,
        "database schema no longer matches the current development baseline",
    )

    print("current ledger handoff index: OK")
    print(f"preserved archive sha256: {ARCHIVE_SHA256}")
    print(
        "preserved headings: "
        f"h2={ARCHIVE_LEVEL_2_COUNT}, h3={ARCHIVE_LEVEL_3_COUNT}"
    )


if __name__ == "__main__":
    main()
