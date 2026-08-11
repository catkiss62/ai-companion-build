#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import time
import uuid


def assert_eq(actual, expected, msg):
    if actual != expected:
        raise AssertionError(f'{msg}: actual={actual!r} expected={expected!r}')


def scalar(db, sql, args=()):
    return db.execute(sql, args).fetchone()[0]


def main():
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    now = int(time.time() * 1000)

    db.executescript('''
    CREATE TABLE post_turn_jobs (
      id TEXT PRIMARY KEY, user_message_id TEXT NOT NULL,
      assistant_message_id TEXT NOT NULL UNIQUE,
      status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT NOT NULL DEFAULT '', run_token TEXT NOT NULL DEFAULT '',
      result_json TEXT NOT NULL DEFAULT '', started_at INTEGER, heartbeat_at INTEGER,
      next_retry_at INTEGER, model_completed_at INTEGER, desire_applied_at INTEGER,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
    );
    CREATE TABLE desire_state (id INTEGER PRIMARY KEY, json TEXT NOT NULL, updated_at INTEGER NOT NULL);
    CREATE TABLE relationship_events (
      id TEXT PRIMARY KEY, kind TEXT NOT NULL, summary TEXT NOT NULL,
      intensity REAL NOT NULL, valence REAL NOT NULL, metadata_json TEXT NOT NULL DEFAULT '{}',
      source_message_id TEXT, created_at INTEGER NOT NULL, internalized_at INTEGER
    );
    CREATE TABLE unfinished_threads (
      id TEXT PRIMARY KEY, title TEXT NOT NULL, detail TEXT NOT NULL,
      importance REAL NOT NULL DEFAULT .5, status TEXT NOT NULL DEFAULT 'active',
      source_message_id TEXT, topic_key TEXT NOT NULL DEFAULT '',
      followup_due_at INTEGER, followup_seeded_at INTEGER,
      followup_run_token TEXT NOT NULL DEFAULT '', followup_claimed_at INTEGER,
      proactive_outcome_message_id TEXT,
      followup_count INTEGER NOT NULL DEFAULT 0, last_followup_at INTEGER,
      retired_at INTEGER, retire_reason TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
    );
    CREATE TABLE conversation_summaries (
      id TEXT PRIMARY KEY, from_at INTEGER NOT NULL, to_at INTEGER NOT NULL,
      summary TEXT NOT NULL, key_points TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX idx_summary_range_unique ON conversation_summaries(from_at, to_at);
    ''')

    # 1. Post-turn stale run token fencing.
    job = 'job'
    old_token = 'old'
    new_token = 'new'
    db.execute('''INSERT INTO post_turn_jobs
      (id,user_message_id,assistant_message_id,status,attempts,run_token,result_json,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?,?,?)''',
      (job,'u','a','running',1,old_token,'{"memories":[]}',now,now))
    db.execute("UPDATE post_turn_jobs SET status='retry_wait',run_token='',next_retry_at=? WHERE id=?", (now,job))
    db.execute("UPDATE post_turn_jobs SET status='running',attempts=2,run_token=?,next_retry_at=NULL WHERE id=?", (new_token,job))
    changed = db.execute("UPDATE post_turn_jobs SET heartbeat_at=? WHERE id=? AND status='running' AND run_token=?", (now+1,job,old_token)).rowcount
    assert_eq(changed, 0, 'stale post-turn run must not heartbeat')
    changed = db.execute("UPDATE post_turn_jobs SET heartbeat_at=? WHERE id=? AND status='running' AND run_token=?", (now+2,job,new_token)).rowcount
    assert_eq(changed, 1, 'current post-turn run owns heartbeat')

    # Cached model proposal survives retry/reclaim.
    cached = scalar(db, 'SELECT result_json FROM post_turn_jobs WHERE id=?', (job,))
    assert_eq(cached, '{"memories":[]}', 'cached post-turn proposal must survive retry')

    # 2. Desire application marker is exactly-once per post-turn job.
    changed = db.execute("UPDATE post_turn_jobs SET desire_applied_at=? WHERE id=? AND status='running' AND run_token=? AND desire_applied_at IS NULL", (now+3,job,new_token)).rowcount
    assert_eq(changed, 1, 'first desire apply marker')
    changed = db.execute("UPDATE post_turn_jobs SET desire_applied_at=? WHERE id=? AND status='running' AND run_token=? AND desire_applied_at IS NULL", (now+4,job,new_token)).rowcount
    assert_eq(changed, 0, 'second desire apply must be rejected')

    # 3. Relationship event internalization is one-way.
    db.execute('INSERT INTO relationship_events VALUES (?,?,?,?,?,?,?,?,?)', ('r','trust','x',.5,.2,'{}','m',now,None))
    changed = db.execute('UPDATE relationship_events SET internalized_at=? WHERE id=? AND internalized_at IS NULL', (now+5,'r')).rowcount
    assert_eq(changed, 1, 'first relationship internalization')
    changed = db.execute('UPDATE relationship_events SET internalized_at=? WHERE id=? AND internalized_at IS NULL', (now+6,'r')).rowcount
    assert_eq(changed, 0, 'relationship must not internalize twice')

    # 4. Deferred follow-up claim token. Old worker cannot complete after reclaim.
    db.execute('''INSERT INTO unfinished_threads
      (id,title,detail,status,topic_key,followup_due_at,followup_run_token,followup_claimed_at,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?,?,?,?)''', ('t','title','detail','active','topic',now,old_token,now,now,now))
    db.execute('UPDATE unfinished_threads SET followup_run_token=?,followup_claimed_at=? WHERE id=?', (new_token,now+10,'t'))
    changed = db.execute("UPDATE unfinished_threads SET followup_seeded_at=?,followup_run_token='' WHERE id=? AND status='active' AND followup_seeded_at IS NULL AND followup_run_token=?", (now+11,'t',old_token)).rowcount
    assert_eq(changed, 0, 'stale follow-up token must not complete')
    changed = db.execute("UPDATE unfinished_threads SET followup_seeded_at=?,followup_run_token='' WHERE id=? AND status='active' AND followup_seeded_at IS NULL AND followup_run_token=?", (now+12,'t',new_token)).rowcount
    assert_eq(changed, 1, 'current follow-up token completes')

    # 5. Optimistic retirement rejects stale maintenance snapshot.
    db.execute('UPDATE unfinished_threads SET status="active",retired_at=NULL,updated_at=? WHERE id=?', (now+20,'t'))
    stale_updated_at = now+20
    # Conversation updates it after maintenance read.
    db.execute('UPDATE unfinished_threads SET detail=?,updated_at=? WHERE id=?', ('new detail',now+21,'t'))
    changed = db.execute("UPDATE unfinished_threads SET status='retired',retired_at=? WHERE id=? AND status='active' AND updated_at=?", (now+22,'t',stale_updated_at)).rowcount
    assert_eq(changed, 0, 'stale maintenance must not retire refreshed thread')

    # 6. Proactive thread outcome is keyed by durable response message.
    db.execute('UPDATE unfinished_threads SET status="active", proactive_outcome_message_id=NULL, followup_due_at=NULL WHERE id=?', ('t',))
    response_id = 'response-1'
    changed = db.execute("UPDATE unfinished_threads SET followup_due_at=?,proactive_outcome_message_id=? WHERE id=? AND proactive_outcome_message_id IS NOT ?", (now+999,response_id,'t',response_id)).rowcount
    assert_eq(changed, 1, 'first proactive thread outcome')
    changed = db.execute("UPDATE unfinished_threads SET followup_due_at=?,proactive_outcome_message_id=? WHERE id=? AND proactive_outcome_message_id IS NOT ?", (now+1999,response_id,'t',response_id)).rowcount
    assert_eq(changed, 0, 'same response must not reschedule proactive thread outcome')
    assert_eq(scalar(db, 'SELECT followup_due_at FROM unfinished_threads WHERE id=?', ('t',)), now+999, 'replay must not drift follow-up due time')

    # 7. Summary range is globally idempotent even if two model workers finish.
    db.execute('INSERT INTO conversation_summaries VALUES (?,?,?,?,?,?)', ('s1',100,200,'first','',now))
    try:
        db.execute('INSERT INTO conversation_summaries VALUES (?,?,?,?,?,?)', ('s2',100,200,'second','',now+1))
    except sqlite3.IntegrityError:
        pass
    assert_eq(scalar(db, 'SELECT COUNT(*) FROM conversation_summaries WHERE from_at=100 AND to_at=200'), 1, 'summary range must be unique')

    print('[OK] stale post-turn run token fenced')
    print('[OK] cached post-turn proposal survives reclaim')
    print('[OK] post-turn desire marker exactly once')
    print('[OK] relationship internalization exactly once')
    print('[OK] deferred follow-up stale token fenced')
    print('[OK] optimistic thread retirement fence')
    print('[OK] proactive thread outcome idempotent by response')
    print('[OK] conversation summary range idempotent')
    print('v0.15 async-worker SQLite simulation passed.')


if __name__ == '__main__':
    main()
