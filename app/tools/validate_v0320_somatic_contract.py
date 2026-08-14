#!/usr/bin/env python3
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
assert re.search(r"^version:\s*0\.32\.(?:0\+52|1\+53)\s*$", pubspec, re.M)

database = read("lib/core/database/app_database.dart")
for token in [
    "static const int schemaVersion = 21;",
    "CREATE TABLE IF NOT EXISTS somatic_events",
    "CREATE TABLE IF NOT EXISTS somatic_aggregates",
    "UNIQUE(turn_id, direction, scene_key)",
    "FOREIGN KEY(turn_id) REFERENCES messages(id) ON DELETE CASCADE",
    "Future<int> recordSomaticEvents",
    "settings['active_brain'] == '0'",
    "settings['transfer_lock'] == '1'",
    "await _rebuildSomaticAggregates(",
    "'somatic_events'",
    "'somatic_aggregates'",
    "'model', 'value': 'deepseek-v4-flash'",
]:
    assert token in database, token

policy = read("lib/core/somatic/somatic_policy.dart")
for token in [
    "class SomaticPolicy",
    "detectDailyTouch",
    "SomaticDirection.userToAi",
    "touch__${action}",
    "promptThreshold = 0.18",
    "不要复述数值",
    "不能据此越过当前 Session 的亲密边界",
]:
    assert token in policy, token

runner = read("lib/core/ai/durable_generation_runner.dart")
assert "SomaticEngine(db)" in runner
assert "await somaticEngine.captureUserTurn(" in runner
assert runner.index("await somaticEngine.captureUserTurn(") < runner.index(
    "PromptBuilder(db).buildChatMessages("
)

prompt = read("lib/core/ai/prompt_builder.dart")
assert "SomaticEngine(db)" in prompt
assert "await somaticEngine.buildPromptSection(now: instant)" in prompt
assert "writeln(somaticSection)" in prompt

model = read("lib/core/ai/model_profile.dart")
controller = read("lib/features/chat/chat_controller.dart")
assert "orElse: () => DeepSeekModelProfile.flash" in model
assert "DeepSeekModelProfile model = DeepSeekModelProfile.flash" in controller

tests = read("test/somatic_policy_test.dart")
for title in [
    "daily touch maps a user-to-AI kiss",
    "non-contact wording and reverse direction",
    "event identity is deterministic",
    "aggregate decays and prompt hides values",
    "pulses saturate",
]:
    assert title in tests, title

# SQLite mirror: the real v21 constraints must reject duplicate recovery
# events and withdraw the child row when its durable user turn is cancelled.
db = sqlite3.connect(":memory:")
db.execute("PRAGMA foreign_keys = ON")
db.execute("CREATE TABLE messages (id TEXT PRIMARY KEY, role TEXT NOT NULL)")
db.execute("""
CREATE TABLE somatic_events (
  id TEXT PRIMARY KEY, turn_id TEXT NOT NULL, channel TEXT NOT NULL,
  action TEXT NOT NULL DEFAULT '', part TEXT NOT NULL DEFAULT '',
  scene_key TEXT NOT NULL, direction TEXT NOT NULL, source TEXT NOT NULL,
  narrative TEXT NOT NULL, intensity REAL NOT NULL,
  created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
  FOREIGN KEY(turn_id) REFERENCES messages(id) ON DELETE CASCADE,
  UNIQUE(turn_id, direction, scene_key)
)
""")
db.execute("INSERT INTO messages VALUES ('turn-1', 'user')")
event = (
    "event-1", "turn-1", "touch", "kiss", "lips",
    "touch__kiss__lips", "user_to_ai", "user_text", "短暂触感",
    0.72, 100, 200,
)
db.execute("INSERT INTO somatic_events VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", event)
try:
    db.execute(
        "INSERT INTO somatic_events VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
        ("event-2",) + event[1:],
    )
    raise AssertionError("duplicate recovered event was accepted")
except sqlite3.IntegrityError:
    pass
db.execute("DELETE FROM messages WHERE id='turn-1'")
assert db.execute("SELECT COUNT(*) FROM somatic_events").fetchone()[0] == 0

print("v0.32.0 somatic contract and daily-touch MVP validation passed")
