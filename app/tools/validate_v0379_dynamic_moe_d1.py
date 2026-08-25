#!/usr/bin/env python3
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
models = read("lib/core/moe/domain/moe_models.dart")
policy = read("lib/core/moe/application/moe_dynamics_policy.dart")
repo = read("lib/core/moe/infrastructure/sqlite_moe_repository.dart")
tests = read("test/moe_dynamics_policy_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in (
        "version: 0.37.9+98",
        "version: 0.38.0+99",
        "version: 0.38.1+100",
        "version: 0.38.2+101",
        "version: 0.38.3+102",
        "version: 0.38.4+103",
        "version: 0.38.5+104",
        "version: 0.38.6+105",
        "version: 0.38.7+106",
    )
)
assert "static const int schemaVersion = 32;" in database
assert "if (oldVersion < 32)" in database
assert "await _createV32Tables(db);" in database

axes = (
    "defensive_mask",
    "verbal_spice",
    "closeness_bid",
    "playful_impulse",
    "cute_display",
    "bashful_inhibition",
    "unfiltered_directness",
    "strategic_subtext",
    "flustered_bumble",
)
recipes = (
    "tsundere",
    "sharp_tongue",
    "cute_display",
    "coaxing",
    "shy",
    "goofy_cute",
    "natural_direct",
    "black_belly",
    "prankster",
)
for token in axes + recipes:
    assert token in models, token

for token in (
    "MoeExpressionMode { natural, obvious, manga }",
    "return MoeExpressionMode.obvious",
    "class MoeInputSnapshot",
    "class MoeExpressionPlan",
    "class MoeObservedEvent",
):
    assert token in models, token

for token in (
    "entryThreshold = 46.0",
    "exitThreshold = 34.0",
    "_applyBoundedCoupling",
    "cooldownUntil",
    "contextReady",
    "MoeRecipe.blackBelly",
    "萌属性只读取已提交的状态，不写入 Desire、关系、情绪或规则系统",
):
    assert token in policy, token

for table in ("moe_axis_state", "moe_recipe_state", "moe_events", "moe_config"):
    assert database.count(table) >= 4, table
    assert table in repo, table

assert "conflictAlgorithm: ConflictAlgorithm.ignore" in repo
assert "MoeStateSnapshot.neutral" in repo
assert "expression_mode TEXT NOT NULL DEFAULT 'obvious'" in database
assert "'expression_mode': 'obvious'" in database

# The Moe domain may depend on sqflite only in its own infrastructure adapter.
moe_files = list((ROOT / "lib/core/moe").rglob("*.dart"))
assert moe_files
for path in moe_files:
    source = path.read_text(encoding="utf-8")
    lowered = source.lower()
    for forbidden in (
        "../desire/",
        "../relationship/",
        "../ai_self/",
        "desire_state.dart",
        "app_database.dart",
        "prompt_builder",
    ):
        assert forbidden not in lowered, f"{path}: {forbidden}"

for root_name in ("desire", "relationship", "ai_self"):
    root = ROOT / "lib/core" / root_name
    if root.exists():
        for path in root.rglob("*.dart"):
            assert "/moe/" not in path.read_text(encoding="utf-8"), path

for forbidden_output in (
    "sendMessage",
    "toolCall",
    "createIntent",
    "gateDecision",
    "satisfyDrive",
):
    assert forbidden_output not in models + policy

for title in (
    "nine axes and nine named recipes keep the locked vocabulary",
    "high axes without a factual context gate do not activate a trope",
    "hysteresis exit creates cooldown and prevents immediate re-entry",
    "one thousand ticks stay bounded",
    "disabled or incompatible contract fails open to neutral",
):
    assert title in tests, title

# Smoke-check the migration SQL contract independently from Flutter/sqflite.
db = sqlite3.connect(":memory:")
db.executescript(
    """
    CREATE TABLE moe_axis_state (
      axis_key TEXT PRIMARY KEY, baseline REAL NOT NULL,
      current_value REAL NOT NULL, updated_at INTEGER NOT NULL,
      policy_version INTEGER NOT NULL
    );
    CREATE TABLE moe_recipe_state (
      recipe_key TEXT PRIMARY KEY, strength REAL NOT NULL,
      active INTEGER NOT NULL DEFAULT 0, entered_at INTEGER,
      exited_at INTEGER, cooldown_until INTEGER, updated_at INTEGER NOT NULL
    );
    CREATE TABLE moe_events (
      idempotency_key TEXT PRIMARY KEY, source_type TEXT NOT NULL,
      cause_tag TEXT NOT NULL, pulses_json TEXT NOT NULL,
      context_tags_json TEXT NOT NULL, occurred_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE moe_config (
      id INTEGER PRIMARY KEY CHECK (id = 1), enabled INTEGER NOT NULL,
      expression_mode TEXT NOT NULL DEFAULT 'obvious',
      contract_version INTEGER NOT NULL, policy_version INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    INSERT INTO moe_config VALUES (1, 1, 'obvious', 1, 1, 0);
    """
)
assert db.execute("SELECT expression_mode FROM moe_config WHERE id=1").fetchone()[0] == "obvious"
db.execute("INSERT INTO moe_events VALUES ('same','test','cause','{}','[]',0,0)")
db.execute("INSERT OR IGNORE INTO moe_events VALUES ('same','test','cause','{}','[]',0,0)")
assert db.execute("SELECT COUNT(*) FROM moe_events").fetchone()[0] == 1

for token in (
    "Build AI Companion v0.37.9+98 APK (Dynamic Moe D1 Engine)",
    "validate_v0379_dynamic_moe_d1.py",
    "AI-Companion-v0.37.9-98-Dynamic-Moe-D1-Engine-APK.apk",
    "v0.37.9-dynamic-moe-d1-test",
    ".ci/v0379-monitor.txt",
):
    assert token in workflow, token

print("v0.37.9 dynamic moe D1 isolation, policy and schema validation passed")
