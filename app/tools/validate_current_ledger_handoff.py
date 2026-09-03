#!/usr/bin/env python3
"""Validate the compact active-task handoff without rewriting preserved history."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "AI_Companion_当前总账.md"
PUBSPEC = ROOT / "app" / "pubspec.yaml"
DATABASE = ROOT / "app" / "lib" / "core" / "database" / "app_database.dart"
DOCUMENTATION_MAP = ROOT / "app" / "docs" / "DOCUMENTATION_MAP.md"

HANDOFF_STOP_MARKER = "## 近期详细记录与全局索引（按需检索）"
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
    require(
        len(re.findall(rf"^{re.escape(HANDOFF_STOP_MARKER)}$", ledger, re.MULTILINE))
        == 1,
        "compact handoff stop heading contract changed",
    )
    require(
        len(re.findall(rf"^{re.escape(ARCHIVE_MARKER)}$", ledger, re.MULTILINE)) == 1,
        "archive heading contract changed",
    )
    handoff_end = ledger.index("\n" + HANDOFF_STOP_MARKER + "\n")
    archive_marker_index = ledger.index("\n" + ARCHIVE_MARKER + "\n", handoff_end)
    current = ledger[:handoff_end]
    archive_start = ledger.index(ARCHIVE_START, archive_marker_index)
    archive = ledger[archive_start:]

    require(
        len(current.encode("utf-8")) <= 20_000,
        "compact handoff exceeded 20 KB; move detailed process below the stop marker",
    )

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
        "### 3. 当前下一步任务包（新窗口必须完整接住）",
        "### 4. 当前任务完成后的后续导航（只导航，不提前展开）",
    )
    for section in required_sections:
        require(section in current, f"missing compact handoff section: {section}")

    required_detailed_sections = (
        "### 3. 当前模块状态总表",
        "### 4. 当前任务总表",
        "### 5. 永久不可变边界与高频踩坑",
        "### 7. 按模块回读历史的导航表",
        "### 8. 历史档案覆盖说明",
        "### 9. 2026-08-31 · 总账减负交接层",
        "### 16. 2026-09-01 · v0.41.10 人格学习证据归因热修",
        "### 18. 2026-09-01 · v0.41.13 Phase 0+1 审查与时间加固",
        "### 19. 2026-09-01 · v0.41.14 Agent 操作事实真实性与用户单次屏幕观察",
        "### 20. 2026-09-02 · Self-Drive、欲望数值与自主联网成长审计",
        "### 23. 2026-09-02 · v0.41.17 聊天文字与心情图真机热修",
        "### 24. 2026-09-02 · v0.41.18 总设置信息架构与保存语义",
        "### 25. 2026-09-02 · 当前任务包与后续导航二次减负",
        "### 26. 2026-09-02 · 约 10 小时自然数据的 Phase 2A 审查",
        "### 27. 2026-09-02 · v0.41.19 Phase 2A 运行稳定化",
        "### 28. 2026-09-02 · Phase 2A.5 对话主动权与自我驱动表达",
        "### 29. 2026-09-02 · Phase 2A.5 决策权消融与终态真值稳定化",
        "### 30. 2026-09-03 · 激进核心底色、纯对白与造梗表达重构",
        "### 31. 2026-09-03 · 活人感消融、直接反馈与清晨 Gate 窄修",
        "### 32. 2026-09-03 · 可见思考即时内心化",
    )
    for section in required_detailed_sections:
        require(section in ledger[handoff_end:], f"missing detailed ledger section: {section}")

    required_current_facts = (
        "总账双层同步强制规则（每次正式修改前后都必须执行）",
        "只更新其中一层视为总账未完成",
        "agent/v04124-visible-inner-monologue",
        "0.41.24+163",
        "0.41.23+162",
        "schema 44",
        "33719594761",
        "e42c21715c5871d07f67755e173285bbae394d6aed9cd0f4431d33a4cbb0dfef",
        "2f25733c0bcfa4b956bbe276ec0f278eb94f5a00",
        "现有 schema 44 存档须可直接覆盖升级",
        "Phase 2A",
        "Phase 2B",
        "终态真值",
        "可单独清空的动作神态 A/B 规则",
        "可见思考",
        "即时内心想法",
        "联网图片同一不可变字节事务",
    )
    for fact in required_current_facts:
        require(fact in current, f"missing active-task handoff fact: {fact}")
    current_statuses = (
        "DESIGNED / IMPLEMENTATION IN PROGRESS / CI PENDING / TRUE DEVICE PENDING",
        "DESIGNED / IMPLEMENTATION PENDING",
        "IMPLEMENTED / LOCAL VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
        "IMPLEMENTED / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
        "LOCAL VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
        "CI TEST CONTRACT FIX IN PROGRESS / TRUE DEVICE PENDING",
        "CI FIX IN PROGRESS / TRUE DEVICE PENDING",
        "CI PASSED / APK READY / TRUE DEVICE PENDING",
    )
    require(
        any(status in current for status in current_statuses),
        "missing recognized current handoff status",
    )

    required_ledger_facts = (
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
    for fact in required_ledger_facts:
        require(fact in ledger, f"missing detailed ledger fact: {fact}")

    for history_range in (
        "v0.41.5～v0.41.0",
        "v0.40.9～v0.40.0",
        "v0.39.9～v0.39.0",
        "v0.38.18～v0.38.5",
        "v0.38.4～v0.37.0",
        "v0.36.x～v0.35.7",
        "旧编号 0～10.19",
    ):
        require(history_range in ledger, f"missing history coverage range: {history_range}")

    documentation_map = DOCUMENTATION_MAP.read_text(encoding="utf-8")
    require(
        "读到“近期详细记录与全局索引”标记即停" in documentation_map,
        "documentation map still points at the old full-history stop marker",
    )

    pubspec = PUBSPEC.read_text(encoding="utf-8")
    database = DATABASE.read_text(encoding="utf-8")
    require(
        re.search(r"^version:\s*0\.41\.(?:20\+159|21\+160|22\+161|23\+162|24\+163)\s*$", pubspec, re.MULTILINE)
        is not None,
        "pubspec version no longer matches the current development baseline or target",
    )
    require(
        "static const int schemaVersion = 44;" in database,
        "database schema no longer matches the current development baseline",
    )

    print("current ledger active-task handoff: OK")
    print(f"compact handoff bytes: {len(current.encode('utf-8'))}")
    print(f"preserved archive sha256: {ARCHIVE_SHA256}")
    print(
        "preserved headings: "
        f"h2={ARCHIVE_LEVEL_2_COUNT}, h3={ARCHIVE_LEVEL_3_COUNT}"
    )


if __name__ == "__main__":
    main()
