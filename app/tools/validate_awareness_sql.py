#!/usr/bin/env python3
import sqlite3
import time
import uuid


def create_v13(conn: sqlite3.Connection) -> None:
    conn.executescript('''
    CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    INSERT INTO settings VALUES('device_id','phone-a');
    INSERT INTO settings VALUES('active_brain','1');
    INSERT INTO settings VALUES('transfer_lock','0');
    ''')


def migrate_v14(conn: sqlite3.Connection) -> None:
    conn.executescript('''
    CREATE TABLE IF NOT EXISTS awareness_observations (
      id TEXT PRIMARY KEY,
      device_id TEXT,
      kind TEXT NOT NULL,
      summary TEXT NOT NULL,
      confidence REAL NOT NULL DEFAULT 0.5,
      window_start INTEGER NOT NULL,
      window_end INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      dedupe_key TEXT NOT NULL UNIQUE,
      source_fingerprint TEXT NOT NULL DEFAULT '',
      metadata_json TEXT NOT NULL DEFAULT '{}',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_awareness_active
      ON awareness_observations(expires_at DESC, confidence DESC, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_awareness_kind
      ON awareness_observations(kind, updated_at DESC);
    ''')


def allowed(conn: sqlite3.Connection) -> bool:
    settings = dict(conn.execute("SELECT key,value FROM settings WHERE key IN ('active_brain','transfer_lock')"))
    return settings.get('active_brain') != '0' and settings.get('transfer_lock') != '1'


def sync(conn: sqlite3.Connection, drafts: list[dict], managed: set[str], now_ms: int) -> int:
    with conn:
        if not allowed(conn):
            return 0
        device_id = conn.execute("SELECT value FROM settings WHERE key='device_id'").fetchone()[0]
        incoming = {d['dedupe_key'] for d in drafts}
        for key in managed - incoming:
            conn.execute('''
              UPDATE awareness_observations
              SET expires_at=MIN(expires_at, ?), updated_at=?
              WHERE dedupe_key=? AND expires_at>?
            ''', (now_ms, now_ms, key, now_ms))
        for d in drafts:
            row = conn.execute(
                'SELECT id,created_at FROM awareness_observations WHERE dedupe_key=?',
                (d['dedupe_key'],),
            ).fetchone()
            values = (
                device_id, d['kind'], d['summary'], d['confidence'], d['window_start'],
                d['window_end'], d['expires_at'], d['fingerprint'], '{}', now_ms,
            )
            if row:
                conn.execute('''
                  UPDATE awareness_observations SET
                    device_id=?,kind=?,summary=?,confidence=?,window_start=?,window_end=?,
                    expires_at=?,source_fingerprint=?,metadata_json=?,updated_at=?
                  WHERE id=?
                ''', values + (row[0],))
            else:
                conn.execute('''
                  INSERT INTO awareness_observations(
                    id,device_id,kind,summary,confidence,window_start,window_end,expires_at,
                    dedupe_key,source_fingerprint,metadata_json,created_at,updated_at
                  ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
                ''', (
                    str(uuid.uuid4()), device_id, d['kind'], d['summary'], d['confidence'],
                    d['window_start'], d['window_end'], d['expires_at'], d['dedupe_key'],
                    d['fingerprint'], '{}', now_ms, now_ms,
                ))
    return len(drafts)


def draft(key: str, summary: str, now_ms: int, confidence: float = 0.75, ttl_min: int = 20) -> dict:
    return {
        'dedupe_key': key,
        'kind': key,
        'summary': summary,
        'confidence': confidence,
        'window_start': now_ms - 30 * 60_000,
        'window_end': now_ms,
        'expires_at': now_ms + ttl_min * 60_000,
        'fingerprint': f'{key}:{summary}',
    }


def main() -> None:
    conn = sqlite3.connect(':memory:')
    create_v13(conn)
    migrate_v14(conn)
    cols = {r[1] for r in conn.execute('PRAGMA table_info(awareness_observations)')}
    required = {'confidence','window_start','window_end','expires_at','dedupe_key','source_fingerprint','device_id'}
    assert required <= cols

    now = int(time.time() * 1000)
    # Duplicate suppression: same semantic key updates one row, preserving identity.
    sync(conn, [draft('recent_activity', '最近一段时间主要在玩游戏。', now)], {'recent_activity'}, now)
    first = conn.execute("SELECT id,created_at FROM awareness_observations WHERE dedupe_key='recent_activity'").fetchone()
    sync(conn, [draft('recent_activity', '最近一段时间主要在看视频。', now + 240_000)], {'recent_activity'}, now + 240_000)
    rows = conn.execute("SELECT id,created_at,summary FROM awareness_observations WHERE dedupe_key='recent_activity'").fetchall()
    assert len(rows) == 1 and rows[0][0] == first[0] and rows[0][1] == first[1]
    assert '看视频' in rows[0][2]

    # Managed-key expiry: stale current state disappears immediately when source says it is absent.
    sync(conn, [draft('screen_state', '屏幕现在是熄灭的。', now + 300_000)], {'screen_state'}, now + 300_000)
    sync(conn, [], {'screen_state'}, now + 360_000)
    expires = conn.execute("SELECT expires_at FROM awareness_observations WHERE dedupe_key='screen_state'").fetchone()[0]
    assert expires == now + 360_000

    # Active Brain/transfer lock are checked at write time.
    conn.execute("UPDATE settings SET value='0' WHERE key='active_brain'")
    before = conn.execute('SELECT COUNT(*) FROM awareness_observations').fetchone()[0]
    assert sync(conn, [draft('availability', '现在可能有点忙。', now + 420_000)], {'availability'}, now + 420_000) == 0
    assert conn.execute('SELECT COUNT(*) FROM awareness_observations').fetchone()[0] == before
    conn.execute("UPDATE settings SET value='1' WHERE key='active_brain'")
    conn.execute("UPDATE settings SET value='1' WHERE key='transfer_lock'")
    assert sync(conn, [draft('availability', '现在可能有点忙。', now + 480_000)], {'availability'}, now + 480_000) == 0
    conn.execute("UPDATE settings SET value='0' WHERE key='transfer_lock'")

    # Prompt eligibility: expired and low-confidence rows are bounded out.
    sync(conn, [
        draft('availability', '现在可能有点忙。', now + 540_000, 0.72),
        draft('notification_pressure', '近期通知比较密集。', now + 540_000, 0.30),
    ], {'availability','notification_pressure'}, now + 540_000)
    active = conn.execute('''
      SELECT dedupe_key FROM awareness_observations
      WHERE expires_at > ? AND confidence >= 0.45
    ''', (now + 541_000,)).fetchall()
    keys = {r[0] for r in active}
    assert 'availability' in keys and 'notification_pressure' not in keys and 'screen_state' not in keys

    # Takeover grace: source-device live awareness cannot linger indefinitely on target.
    far_future = now + 8 * 60 * 60_000
    conn.execute("UPDATE awareness_observations SET device_id='phone-a', expires_at=?", (far_future,))
    target = 'tablet-b'
    grace = now + 12 * 60_000
    conn.execute('''
      UPDATE awareness_observations
      SET expires_at = CASE WHEN expires_at > ? THEN ? ELSE expires_at END
      WHERE device_id IS NOT NULL AND device_id <> ?
    ''', (grace, grace, target))
    assert max(r[0] for r in conn.execute('SELECT expires_at FROM awareness_observations')) <= grace

    print('v0.20 awareness SQLite migration/dedupe/expiry/Active-Brain checks passed.')


if __name__ == '__main__':
    main()
