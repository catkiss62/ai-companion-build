#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import time


def main() -> int:
    db = sqlite3.connect(':memory:')
    now = int(time.time() * 1000)
    db.executescript(
        '''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY,
          role TEXT NOT NULL,
          content TEXT,
          created_at INTEGER NOT NULL,
          is_proactive INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX idx_messages_created_at ON messages(created_at);

        CREATE TABLE thoughts (
          id TEXT PRIMARY KEY,
          text TEXT NOT NULL,
          drive_key TEXT NOT NULL,
          kind TEXT NOT NULL,
          strength REAL NOT NULL,
          born_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          lifecycle_state TEXT NOT NULL,
          snoozed_until INTEGER
        );
        '''
    )

    db.executemany(
        'INSERT INTO messages(id,role,content,created_at,is_proactive) VALUES(?,?,?,?,?)',
        [
            ('p-old', 'assistant', 'old proactive', now - 5000, 1),
            ('user-new', 'user', 'ordinary newest message', now - 1000, 0),
            ('p-new', 'assistant', 'new proactive', now - 2000, 1),
        ],
    )
    row = db.execute(
        '''SELECT id FROM messages
           WHERE is_proactive = ?
           ORDER BY created_at DESC
           LIMIT 1''',
        (1,),
    ).fetchone()
    assert row and row[0] == 'p-new', row
    print('[OK] latest proactive message ignores newer ordinary turns')

    db.executemany(
        '''INSERT INTO thoughts(
             id,text,drive_key,kind,strength,born_at,updated_at,lifecycle_state,snoozed_until
           ) VALUES(?,?,?,?,?,?,?,?,?)''',
        [
            ('active-old', 'active old', 'social', 'flit', 0.99, now - 9000, now - 8000, 'active', None),
            ('residual-new', 'residual new', 'social', 'flit', 0.9, now - 3000, now - 1000, 'residual', None),
            ('snoozed-new', 'snoozed new', 'social', 'flit', 0.7, now - 2500, now - 500, 'active', now + 60000),
            ('fixation-recent', 'fixation recent', 'attachment', 'fixation', 0.4, now - 4000, now - 2000, 'fixation', None),
        ],
    )
    row = db.execute(
        '''SELECT id FROM thoughts
           WHERE lifecycle_state IN ('active','fixation')
             AND (snoozed_until IS NULL OR snoozed_until <= ?)
           ORDER BY updated_at DESC
           LIMIT 1''',
        (now,),
    ).fetchone()
    assert row and row[0] == 'fixation-recent', row
    print('[OK] home Thought uses recency and excludes residual/snoozed state')

    db.close()
    print('v0.18 Companion Home SQLite read-model checks passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
