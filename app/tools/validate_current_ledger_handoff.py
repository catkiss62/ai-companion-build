#!/usr/bin/env python3
"""Validate the canonical ledger index and immutable historical archives."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "AI_Companion_当前总账.md"
ARCHIVE = (
    ROOT
    / "app"
    / "docs"
    / "ledger"
    / "archive"
    / "AI_Companion_总账归档_截至_v0.41.74+218.md"
)
RECENT_ARCHIVE = (
    ROOT
    / "app"
    / "docs"
    / "ledger"
    / "archive"
    / "AI_Companion_总账归档_截至_v0.41.84+228.md"
)
PUBSPEC = ROOT / "app" / "pubspec.yaml"
DATABASE = ROOT / "app" / "lib" / "core" / "database" / "app_database.dart"
DOCUMENTATION_MAP = ROOT / "app" / "docs" / "DOCUMENTATION_MAP.md"
INDEX_END_MARKER = "<!-- END QUICK HANDOFF INDEX -->"

ARCHIVE_SHA256 = "602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70"
ARCHIVE_BYTES = 1_587_679
RECENT_ARCHIVE_SHA256 = "47d053d842a73e3ff8107dabe867bd503e8a7e77daaecc2afb1867068faa952c"
RECENT_ARCHIVE_BYTES = 98_372


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    ledger_bytes = LEDGER.read_bytes()
    archive_bytes = ARCHIVE.read_bytes()
    recent_archive_bytes = RECENT_ARCHIVE.read_bytes()
    ledger = ledger_bytes.decode("utf-8")
    archive = archive_bytes.decode("utf-8")
    recent_archive = recent_archive_bytes.decode("utf-8")

    require(
        ledger.startswith("# AI Companion · 当前总账\n"),
        "current ledger is not the canonical UTF-8 Markdown document",
    )
    require(
        "\x00" not in ledger and "\ufffd" not in ledger,
        "current ledger contains binary or replacement characters",
    )
    require(INDEX_END_MARKER in ledger, "current ledger lost its quick-index boundary")
    quick_index = ledger.split(INDEX_END_MARKER, 1)[0].encode("utf-8")
    require(len(quick_index) <= 100_000, "current ledger quick index exceeded 100 KB")
    require(
        len(archive_bytes) == ARCHIVE_BYTES,
        "frozen ledger archive byte count changed",
    )
    require(
        hashlib.sha256(archive_bytes).hexdigest() == ARCHIVE_SHA256,
        "frozen ledger archive was modified",
    )
    require(
        archive.startswith("# AI Companion · 当前总账\n"),
        "frozen archive is not the expected historical ledger",
    )
    require(
        len(recent_archive_bytes) == RECENT_ARCHIVE_BYTES,
        "recent frozen ledger archive byte count changed",
    )
    require(
        hashlib.sha256(recent_archive_bytes).hexdigest() == RECENT_ARCHIVE_SHA256,
        "recent frozen ledger archive was modified",
    )
    require(
        recent_archive.startswith("# AI Companion · 当前总账\n"),
        "recent frozen archive is not the expected historical ledger",
    )

    required_current = (
        "总账 v2",
        "唯一的当前接班入口",
        "v0.41.82+226",
        "agent/v04182-cedar-state-machine-e2e",
        "schema 61",
        "Snapshot protocol 6",
        "模型/API 双通道",
        "Cedar 信任优先",
        "Cedar 盲玩隔离",
        "模型自主发现",
        "陪我下五子棋",
        "playerSafeGuide",
        "public_web.search",
        "allow_self_reset",
        "TRUE DEVICE PENDING",
        "全工具调用动作展示",
        str(ARCHIVE.relative_to(ROOT)),
        ARCHIVE_SHA256,
        str(RECENT_ARCHIVE.relative_to(ROOT)),
        RECENT_ARCHIVE_SHA256,
    )
    for fact in required_current:
        require(fact in ledger, f"missing current ledger fact: {fact}")

    require(
        (
            "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PENDING / CI PENDING / TRUE DEVICE PENDING"
            in ledger
        )
        or (
            "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING"
            in ledger
        )
        or (
            "TRUE DEVICE EVIDENCE CONFIRMED / IMPLEMENTATION IN PROGRESS / CI PENDING / TRUE DEVICE PENDING"
            in ledger
        )
        or "IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING" in ledger
        or "CI PASSED / APK READY / TRUE DEVICE PENDING" in ledger,
        "current ledger has neither a valid pre-CI nor post-CI status",
    )

    required_archive = (
        "总账双层同步强制规则（每次正式修改前后都必须执行）",
        "v0.41.74+218 Cedar 游戏厅全量协议审计与一次性适配",
        "v0.41.73+217 双弈确定性入口与回复完整性热修",
        "模型/API 调用双通道永久合同",
        "Desire / Thought / Intent / Gate",
        "0.41.5+144",
        "schema 40",
        "NOT_IMPLEMENTED",
        "SUPERSEDED",
    )
    for fact in required_archive:
        require(fact in archive, f"missing frozen history fact: {fact}")

    require(
        re.search(
            r"^version:\s*0\.41\.89\+233\s*$",
            PUBSPEC.read_text(encoding="utf-8"),
            re.MULTILINE,
        )
        is not None,
        "pubspec does not match current ledger target",
    )
    require(
        re.search(
            r"static const int schemaVersion = 61;",
            DATABASE.read_text(encoding="utf-8"),
        )
        is not None,
        "database schema no longer matches current baseline",
    )
    documentation_map = DOCUMENTATION_MAP.read_text(encoding="utf-8")
    require(
        "AI_Companion_当前总账.md" in documentation_map,
        "documentation map lost the canonical ledger entry",
    )
    require(
        "AI_Companion_总账归档_截至_v0.41.74+218.md" in documentation_map,
        "documentation map lost the frozen archive entry",
    )
    require(
        "AI_Companion_总账归档_截至_v0.41.84+228.md" in documentation_map,
        "documentation map lost the recent frozen archive entry",
    )

    print("current ledger v2 handoff: OK")
    print(f"current bytes: {len(ledger_bytes)}")
    print(f"quick index bytes: {len(quick_index)}")
    print(f"frozen archive bytes: {len(archive_bytes)}")
    print(f"frozen archive sha256: {ARCHIVE_SHA256}")
    print(f"recent frozen archive bytes: {len(recent_archive_bytes)}")
    print(f"recent frozen archive sha256: {RECENT_ARCHIVE_SHA256}")


if __name__ == "__main__":
    main()
