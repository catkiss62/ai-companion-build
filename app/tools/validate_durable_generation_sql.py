#!/usr/bin/env python3
"""SQLite invariants for v0.14 durable assistant generation.

This does not execute Dart. It exercises the transaction/ownership model with
real SQLite semantics so regressions in the durable-job design are caught even
in environments without Flutter/Android SDKs.
"""
from __future__ import annotations

import sqlite3
import time
import uuid


def schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA foreign_keys = ON;
        CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE messages(
          id TEXT PRIMARY KEY,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          reasoning_content TEXT NOT NULL DEFAULT '',
          model TEXT,
          created_at INTEGER NOT NULL,
          is_proactive INTEGER NOT NULL DEFAULT 0,
          device_id TEXT
        );
        CREATE TABLE post_turn_jobs(
          id TEXT PRIMARY KEY,
          user_message_id TEXT NOT NULL,
          assistant_message_id TEXT NOT NULL UNIQUE,
          status TEXT NOT NULL DEFAULT 'pending',
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE generation_jobs(
          id TEXT PRIMARY KEY,
          user_message_id TEXT NOT NULL UNIQUE,
          assistant_message_id TEXT NOT NULL UNIQUE,
          status TEXT NOT NULL DEFAULT 'pending',
          attempts INTEGER NOT NULL DEFAULT 0,
          model TEXT NOT NULL,
          reasoning_effort TEXT NOT NULL DEFAULT 'high',
          thinking INTEGER NOT NULL DEFAULT 1,
          partial_reasoning TEXT NOT NULL DEFAULT '',
          partial_content TEXT NOT NULL DEFAULT '',
          run_token TEXT NOT NULL DEFAULT '',
          device_id TEXT,
          created_at INTEGER NOT NULL,
          started_at INTEGER,
          updated_at INTEGER NOT NULL,
          completed_at INTEGER,
          last_checkpoint_at INTEGER,
          next_retry_at INTEGER,
          last_error TEXT NOT NULL DEFAULT '',
          resume_reason TEXT NOT NULL DEFAULT ''
        );
        """
    )
    conn.executemany(
        "INSERT INTO settings(key,value) VALUES(?,?)",
        [('active_brain', '1'), ('transfer_lock', '0')],
    )


def create_turn(conn: sqlite3.Connection, user: str, assistant: str, job: str) -> None:
    now = int(time.time() * 1000)
    with conn:
        conn.execute(
            "INSERT INTO messages(id,role,content,created_at,device_id) VALUES(?,?,?,?,?)",
            (user, 'user', 'hello', now, 'phone'),
        )
        conn.execute(
            """INSERT INTO generation_jobs(
                 id,user_message_id,assistant_message_id,status,attempts,model,
                 reasoning_effort,thinking,partial_reasoning,partial_content,
                 run_token,device_id,created_at,updated_at,last_error,resume_reason
               ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (job, user, assistant, 'pending', 0, 'deepseek-v4-pro', 'high', 1,
             '', '', '', 'phone', now, now, '', ''),
        )


def claim(conn: sqlite3.Connection, job: str, token: str) -> None:
    now = int(time.time() * 1000)
    with conn:
        row = conn.execute(
            "SELECT attempts,status FROM generation_jobs WHERE id=?", (job,)
        ).fetchone()
        assert row is not None
        conn.execute(
            """UPDATE generation_jobs SET status='running',attempts=?,run_token=?,
               started_at=?,updated_at=?,last_checkpoint_at=?,next_retry_at=NULL,
               partial_reasoning='',partial_content='' WHERE id=?""",
            (row[0] + 1, token, now, now, now, job),
        )


def main() -> None:
    conn = sqlite3.connect(':memory:')
    schema(conn)

    cols = {r[1] for r in conn.execute('PRAGMA table_info(generation_jobs)')}
    assert 'run_token' in cols, 'run_token column missing'

    # User message + durable job must be one atomic creation.
    create_turn(conn, 'u1', 'a1', 'j1')
    try:
        now = int(time.time() * 1000)
        with conn:
            conn.execute(
                "INSERT INTO messages(id,role,content,created_at) VALUES(?,?,?,?)",
                ('u2', 'user', 'should rollback', now),
            )
            # duplicate assistant id violates UNIQUE and must roll user insert back.
            conn.execute(
                """INSERT INTO generation_jobs(
                     id,user_message_id,assistant_message_id,status,model,created_at,updated_at
                   ) VALUES(?,?,?,?,?,?,?)""",
                ('j2', 'u2', 'a1', 'pending', 'deepseek-v4-pro', now, now),
            )
    except sqlite3.IntegrityError:
        pass
    else:
        raise AssertionError('duplicate assistant id unexpectedly accepted')
    assert conn.execute("SELECT 1 FROM messages WHERE id='u2'").fetchone() is None

    # Attempt ownership: a stale attempt that wakes after takeover cannot mutate
    # the newly claimed attempt.
    claim(conn, 'j1', 'token-old')
    conn.execute(
        "UPDATE generation_jobs SET updated_at=? WHERE id='j1'",
        (int(time.time() * 1000) - 300_000,),
    )
    claim(conn, 'j1', 'token-new')

    changed = conn.execute(
        """UPDATE generation_jobs SET partial_content='OLD',updated_at=?
           WHERE id='j1' AND status='running' AND run_token='token-old'""",
        (int(time.time() * 1000),),
    ).rowcount
    assert changed == 0, 'expired attempt overwrote checkpoint'

    changed = conn.execute(
        """UPDATE generation_jobs SET status='failed',run_token=''
           WHERE id='j1' AND status='running' AND run_token='token-old'"""
    ).rowcount
    assert changed == 0, 'expired attempt changed job status'

    changed = conn.execute(
        """UPDATE generation_jobs SET partial_content='NEW',updated_at=?
           WHERE id='j1' AND status='running' AND run_token='token-new'""",
        (int(time.time() * 1000),),
    ).rowcount
    assert changed == 1

    # Final assistant + post-turn queue + completed status commit together.
    now = int(time.time() * 1000)
    with conn:
        row = conn.execute(
            "SELECT run_token,status FROM generation_jobs WHERE id='j1'"
        ).fetchone()
        assert row == ('token-new', 'running')
        conn.execute(
            """INSERT INTO messages(id,role,content,reasoning_content,model,created_at,device_id)
               VALUES(?,?,?,?,?,?,?)""",
            ('a1', 'assistant', 'final', 'reasoning', 'deepseek-v4-pro', now, 'phone'),
        )
        conn.execute(
            """INSERT INTO post_turn_jobs(
                 id,user_message_id,assistant_message_id,status,created_at,updated_at
               ) VALUES(?,?,?,?,?,?)""",
            (str(uuid.uuid4()), 'u1', 'a1', 'pending', now, now),
        )
        changed = conn.execute(
            """UPDATE generation_jobs SET status='completed',partial_content='final',
               completed_at=?,updated_at=?
               WHERE id='j1' AND status='running' AND run_token='token-new'""",
            (now, now),
        ).rowcount
        assert changed == 1

    assert conn.execute("SELECT status FROM generation_jobs WHERE id='j1'").fetchone()[0] == 'completed'
    assert conn.execute("SELECT content FROM messages WHERE id='a1'").fetchone()[0] == 'final'
    assert conn.execute("SELECT COUNT(*) FROM post_turn_jobs WHERE assistant_message_id='a1'").fetchone()[0] == 1

    # Old attempt is permanently unable to alter a completed turn.
    changed = conn.execute(
        "UPDATE generation_jobs SET status='failed' WHERE id='j1' AND status='running' AND run_token='token-old'"
    ).rowcount
    assert changed == 0

    print('v0.14 durable generation SQLite ownership/atomicity checks passed.')


if __name__ == '__main__':
    main()
