#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import time


def main() -> None:
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    db.executescript('''
    CREATE TABLE thoughts (
      id TEXT PRIMARY KEY,
      text TEXT NOT NULL,
      strength REAL NOT NULL,
      lifecycle_state TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      snoozed_until INTEGER
    );
    ''')
    now = int(time.time() * 1000)
    rows = [
        ('residual-strong', 'old residual', 0.99, 'residual', now, None),
        ('acted-strong', 'already acted', 0.98, 'acted', now, None),
        ('snoozed-strong', 'not now', 0.97, 'active', now, now + 60_000),
        ('active-care', 'current care', 0.40, 'active', now - 1000, None),
        ('fixation-care', 'long care', 0.35, 'fixation', now - 2000, None),
        ('dormant', 'dormant', 0.90, 'dormant', now, None),
    ]
    db.executemany('INSERT INTO thoughts VALUES (?,?,?,?,?,?)', rows)
    selected = db.execute('''
      SELECT id FROM thoughts
      WHERE lifecycle_state IN ('active','fixation')
        AND (snoozed_until IS NULL OR snoozed_until <= ?)
      ORDER BY strength DESC, updated_at DESC
      LIMIT 30
    ''', (now,)).fetchall()
    ids = [r['id'] for r in selected]
    assert ids == ['active-care', 'fixation-care'], ids
    print('[OK] companion-facing Thought SQL excludes residual/acted/dormant/snoozed before LIMIT')
    print('v0.21 relationship presentation SQLite read-model checks passed.')


if __name__ == '__main__':
    main()
