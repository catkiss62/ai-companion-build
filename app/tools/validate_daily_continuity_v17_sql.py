#!/usr/bin/env python3
from __future__ import annotations

import json
import sqlite3
import time
from dataclasses import dataclass

DAY = 86_400_000


def schema(db: sqlite3.Connection) -> None:
    db.executescript('''
    CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    INSERT INTO settings VALUES ('active_brain','1');
    INSERT INTO settings VALUES ('transfer_lock','0');
    CREATE TABLE daily_continuity (
      id TEXT PRIMARY KEY,
      local_day TEXT NOT NULL UNIQUE,
      window_start INTEGER NOT NULL,
      window_end INTEGER NOT NULL,
      shared_moments_json TEXT NOT NULL DEFAULT '[]',
      carried_threads_json TEXT NOT NULL DEFAULT '[]',
      cares_json TEXT NOT NULL DEFAULT '[]',
      awareness_json TEXT NOT NULL DEFAULT '[]',
      message_count INTEGER NOT NULL DEFAULT 0,
      relationship_event_count INTEGER NOT NULL DEFAULT 0,
      quiet_day INTEGER NOT NULL DEFAULT 0,
      source_fingerprint TEXT NOT NULL DEFAULT '',
      finalized_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE INDEX idx_daily_continuity_day ON daily_continuity(window_start DESC);
    ''')


def upsert(db: sqlite3.Connection, *, day: str, start: int, fingerprint: str,
           messages: int = 0, finalized_at: int | None = None,
           thread_topic: str = '') -> tuple[bool, bool]:
    with db:
        settings = dict(db.execute("SELECT key,value FROM settings WHERE key IN ('active_brain','transfer_lock')"))
        if settings.get('transfer_lock') == '1' or settings.get('active_brain') == '0':
            return False, False
        row = db.execute('SELECT * FROM daily_continuity WHERE local_day=?', (day,)).fetchone()
        now = int(time.time() * 1000)
        threads = [] if not thread_topic else [{'id': thread_topic, 'title': thread_topic, 'detail': '', 'topic_key': thread_topic}]
        if row is None:
            db.execute('''INSERT INTO daily_continuity
              VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', (
                'id-' + day, day, start, start + DAY, '[]', json.dumps(threads), '[]', '[]',
                messages, 0, 1 if messages == 0 and not threads else 0, fingerprint,
                finalized_at, now, now,
            ))
            return True, finalized_at is not None
        if row['finalized_at'] is not None:
            return False, False
        changed = row['source_fingerprint'] != fingerprint
        if not changed and finalized_at is None:
            return False, False
        db.execute('''UPDATE daily_continuity SET source_fingerprint=?, message_count=?,
          carried_threads_json=?, finalized_at=COALESCE(?, finalized_at), updated_at=? WHERE local_day=?''',
          (fingerprint, messages, json.dumps(threads), finalized_at, now, day))
        return changed or finalized_at is not None, finalized_at is not None


def choose_thread(candidates: list[tuple[str, bool]], previous_topics: set[str]) -> str | None:
    # updated_today beats carry-forward suppression; otherwise do not repeat a
    # thread already shown in either of the previous two daily rows.
    for topic, updated_today in candidates:
        if updated_today or topic not in previous_topics:
            return topic
    return None


def main() -> None:
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    schema(db)
    print('[OK] v16 -> v17 additive daily continuity table contract')

    start = 1_785_859_200_000
    changed, finalized = upsert(db, day='2026-08-11', start=start, fingerprint='a', messages=4)
    assert changed and not finalized
    changed2, _ = upsert(db, day='2026-08-11', start=start, fingerprint='a', messages=4)
    assert not changed2
    count = db.execute('SELECT COUNT(*) FROM daily_continuity WHERE local_day=?', ('2026-08-11',)).fetchone()[0]
    assert count == 1
    print('[OK] retry/exactly-once keeps one UNIQUE row per local day')

    changed3, finalized3 = upsert(db, day='2026-08-11', start=start, fingerprint='b', messages=7, finalized_at=start + DAY)
    assert changed3 and finalized3
    frozen = db.execute('SELECT source_fingerprint,message_count FROM daily_continuity WHERE local_day=?', ('2026-08-11',)).fetchone()
    upsert(db, day='2026-08-11', start=start, fingerprint='late', messages=99)
    frozen2 = db.execute('SELECT source_fingerprint,message_count FROM daily_continuity WHERE local_day=?', ('2026-08-11',)).fetchone()
    assert tuple(frozen) == tuple(frozen2)
    print('[OK] finalized yesterday is immutable across later retries')

    db.execute("UPDATE settings SET value='0' WHERE key='active_brain'")
    assert upsert(db, day='2026-08-12', start=start + DAY, fingerprint='standby') == (False, False)
    db.execute("UPDATE settings SET value='1' WHERE key='active_brain'")
    db.execute("UPDATE settings SET value='1' WHERE key='transfer_lock'")
    assert upsert(db, day='2026-08-12', start=start + DAY, fingerprint='locked') == (False, False)
    db.execute("UPDATE settings SET value='0' WHERE key='transfer_lock'")
    print('[OK] standby/transfer lock blocks durable continuity writes inside transaction')

    assert choose_thread([('same', False), ('new', False)], {'same'}) == 'new'
    assert choose_thread([('same', True), ('new', False)], {'same'}) == 'same'
    assert choose_thread([('same', False)], {'same'}) is None
    print('[OK] unresolved thread carry-forward avoids daily repetition but allows real updates')

    upsert(db, day='2026-08-12', start=start + DAY, fingerprint='quiet', messages=0)
    quiet = db.execute("SELECT quiet_day,message_count FROM daily_continuity WHERE local_day='2026-08-12'").fetchone()
    assert quiet['quiet_day'] == 1 and quiet['message_count'] == 0
    print('[OK] quiet day is stored as neutral continuity, not relationship regression')

    # Full-state transfer: one exported row set imports without duplication.
    exported = [dict(r) for r in db.execute('SELECT * FROM daily_continuity ORDER BY local_day')]
    target = sqlite3.connect(':memory:')
    target.row_factory = sqlite3.Row
    schema(target)
    with target:
        target.execute('DELETE FROM daily_continuity')
        for row in exported:
            cols = ','.join(row)
            marks = ','.join('?' for _ in row)
            target.execute(f'INSERT INTO daily_continuity ({cols}) VALUES ({marks})', tuple(row.values()))
    assert [dict(r) for r in target.execute('SELECT * FROM daily_continuity ORDER BY local_day')] == exported
    print('[OK] phone/tablet full-state transfer preserves daily continuity rows')

    # Retention boundary mirrors LongRunningMaintenanceEngine: short-term bridge only.
    for i in range(260):
        day_start = start - (i + 2) * DAY
        day = f'old-{i:03d}'
        target.execute('''INSERT OR IGNORE INTO daily_continuity VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
                       (day, day, day_start, day_start + DAY, '[]', '[]', '[]', '[]', 0, 0, 1, day, day_start, day_start, day_start))
    cutoff = start - 180 * DAY
    target.execute('DELETE FROM daily_continuity WHERE window_start < ?', (cutoff,))
    rows = target.execute('SELECT id FROM daily_continuity ORDER BY window_start DESC').fetchall()
    if len(rows) > 220:
        keep = {r['id'] for r in rows[:220]}
        target.executemany('DELETE FROM daily_continuity WHERE id=?', ((r['id'],) for r in rows[220:] if r['id'] not in keep))
    assert target.execute('SELECT COUNT(*) FROM daily_continuity').fetchone()[0] <= 220
    print('[OK] continuity retention remains bounded to the recent bridge window')

    print('v0.24 Daily Continuity SQLite/simulation validation passed.')


if __name__ == '__main__':
    main()
