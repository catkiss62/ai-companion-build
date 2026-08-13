#!/usr/bin/env python3
"""SQLite mirror for the destructive-but-preserving v19 -> v20 cleanup."""

import sqlite3


def columns(db: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in db.execute(f"PRAGMA table_info({table})")}


def main() -> int:
    db = sqlite3.connect(":memory:")
    db.execute("""
        CREATE TABLE messages (
          id TEXT PRIMARY KEY, role TEXT NOT NULL, content TEXT NOT NULL,
          reasoning_content TEXT NOT NULL DEFAULT '',
          provider_reasoning TEXT NOT NULL DEFAULT '',
          companion_voice INTEGER NOT NULL DEFAULT 0,
          model TEXT, created_at INTEGER NOT NULL,
          is_proactive INTEGER NOT NULL DEFAULT 0,
          proactive_intent TEXT NOT NULL DEFAULT '',
          proactive_delivery TEXT NOT NULL DEFAULT '', device_id TEXT
        )
    """)
    db.execute("CREATE INDEX idx_messages_created_at ON messages(created_at)")
    db.execute("CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    db.execute(
        "INSERT INTO messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "m1", "assistant", "正文", "用户当时看到的内心", "provider raw",
            1, "deepseek-v4-pro", 123, 1, "miss_you", "warm", "d1",
        ),
    )
    db.executemany(
        "INSERT INTO settings VALUES (?,?)",
        [
            ("companion_voice_enabled", "1"),
            ("companion_voice_retry_count", "7"),
            ("model", "deepseek-v4-pro"),
        ],
    )

    with db:
        db.execute("""
            CREATE TABLE messages_v20 (
              id TEXT PRIMARY KEY, role TEXT NOT NULL, content TEXT NOT NULL,
              reasoning_content TEXT NOT NULL DEFAULT '', model TEXT,
              created_at INTEGER NOT NULL,
              is_proactive INTEGER NOT NULL DEFAULT 0,
              proactive_intent TEXT NOT NULL DEFAULT '',
              proactive_delivery TEXT NOT NULL DEFAULT '', device_id TEXT
            )
        """)
        db.execute("""
            INSERT INTO messages_v20 (
              id, role, content, reasoning_content, model, created_at,
              is_proactive, proactive_intent, proactive_delivery, device_id
            )
            SELECT id, role, content, reasoning_content, model, created_at,
              is_proactive, proactive_intent, proactive_delivery, device_id
            FROM messages
        """)
        db.execute("DROP TABLE messages")
        db.execute("ALTER TABLE messages_v20 RENAME TO messages")
        db.execute("CREATE INDEX idx_messages_created_at ON messages(created_at)")
        db.execute("DELETE FROM settings WHERE key LIKE 'companion_voice%'")

    expected = {
        "id", "role", "content", "reasoning_content", "model", "created_at",
        "is_proactive", "proactive_intent", "proactive_delivery", "device_id",
    }
    assert columns(db, "messages") == expected
    assert db.execute(
        "SELECT content,reasoning_content,is_proactive,proactive_intent,proactive_delivery,device_id FROM messages"
    ).fetchone() == ("正文", "用户当时看到的内心", 1, "miss_you", "warm", "d1")
    assert db.execute(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_messages_created_at'"
    ).fetchone() is not None
    assert db.execute(
        "SELECT COUNT(*) FROM settings WHERE key LIKE 'companion_voice%'"
    ).fetchone()[0] == 0
    assert db.execute("SELECT value FROM settings WHERE key='model'").fetchone()[0] == "deepseek-v4-pro"
    print("schema v20 message cleanup preserves visible history and removes retired state")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
