#!/usr/bin/env python3
import sqlite3


def make_db():
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    db.executescript('''
      CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
      INSERT INTO settings VALUES ('active_brain','1'),('transfer_lock','0');
      CREATE TABLE messages(
        id TEXT PRIMARY KEY, role TEXT NOT NULL, content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE generation_jobs(
        id TEXT PRIMARY KEY, user_message_id TEXT NOT NULL,
        assistant_message_id TEXT NOT NULL, status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0, model TEXT NOT NULL DEFAULT 'm',
        reasoning_effort TEXT NOT NULL DEFAULT 'high', thinking INTEGER NOT NULL DEFAULT 1,
        partial_reasoning TEXT NOT NULL DEFAULT '', partial_content TEXT NOT NULL DEFAULT '',
        run_token TEXT NOT NULL DEFAULT '', device_id TEXT, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, started_at INTEGER, completed_at INTEGER,
        last_checkpoint_at INTEGER, next_retry_at INTEGER, last_error TEXT NOT NULL DEFAULT '',
        resume_reason TEXT NOT NULL DEFAULT ''
      );
      CREATE TABLE post_turn_jobs(
        id TEXT PRIMARY KEY, status TEXT NOT NULL, run_token TEXT NOT NULL DEFAULT '',
        next_retry_at INTEGER, last_error TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL,
        heartbeat_at INTEGER, created_at INTEGER NOT NULL
      );
    ''')
    return db


def failed_attention(db):
    return db.execute('''
      SELECT g.*
      FROM generation_jobs g
      JOIN messages u ON u.id = g.user_message_id AND u.role = 'user'
      WHERE g.status = 'failed'
        AND NOT EXISTS (
          SELECT 1 FROM messages newer
          WHERE newer.role = 'user' AND newer.created_at > u.created_at
        )
        AND NOT EXISTS (
          SELECT 1 FROM messages a WHERE a.id = g.assistant_message_id
        )
      ORDER BY g.created_at DESC LIMIT 1
    ''').fetchone()


def guard_ok(db):
    values = dict(db.execute("SELECT key,value FROM settings WHERE key IN ('active_brain','transfer_lock')"))
    return values.get('transfer_lock') != '1' and values.get('active_brain') != '0'


def retry_failed_generation(db, job_id):
    with db:
        if not guard_ok(db): return False
        competing = db.execute("SELECT 1 FROM generation_jobs WHERE id<>? AND status IN ('pending','running','retry_wait') LIMIT 1", (job_id,)).fetchone()
        if competing: return False
        row = db.execute('SELECT assistant_message_id FROM generation_jobs WHERE id=?', (job_id,)).fetchone()
        if not row: return False
        if db.execute('SELECT 1 FROM messages WHERE id=?', (row[0],)).fetchone(): return False
        cur = db.execute("UPDATE generation_jobs SET status='pending',run_token='',next_retry_at=NULL,last_error='',resume_reason='manual_retry' WHERE id=? AND status='failed'", (job_id,))
        return cur.rowcount == 1


def retry_failed_post_turn(db):
    with db:
        if not guard_ok(db): return 0
        return db.execute("UPDATE post_turn_jobs SET status='retry_wait',run_token='',next_retry_at=0,last_error='' WHERE status='failed'").rowcount


def test_failed_attention_latest_only():
    db=make_db()
    db.execute("INSERT INTO messages VALUES ('u1','user','one',100)")
    db.execute("INSERT INTO generation_jobs(id,user_message_id,assistant_message_id,status,created_at,updated_at) VALUES ('g1','u1','a1','failed',100,100)")
    assert failed_attention(db)['id']=='g1'
    db.execute("INSERT INTO messages VALUES ('u2','user','two',200)")
    assert failed_attention(db) is None
    db.execute("INSERT INTO generation_jobs(id,user_message_id,assistant_message_id,status,created_at,updated_at) VALUES ('g2','u2','a2','failed',200,200)")
    assert failed_attention(db)['id']=='g2'
    db.execute("INSERT INTO messages VALUES ('a2','assistant','done',201)")
    assert failed_attention(db) is None
    print('[OK] failed generation attention only targets latest unanswered user turn')


def test_manual_generation_guard():
    for active, lock, expected in [('0','0',False),('1','1',False),('1','0',True)]:
        db=make_db()
        db.execute("UPDATE settings SET value=? WHERE key='active_brain'",(active,))
        db.execute("UPDATE settings SET value=? WHERE key='transfer_lock'",(lock,))
        db.execute("INSERT INTO messages VALUES ('u','user','x',100)")
        db.execute("INSERT INTO generation_jobs(id,user_message_id,assistant_message_id,status,created_at,updated_at) VALUES ('g','u','a','failed',100,100)")
        assert retry_failed_generation(db,'g') is expected
    print('[OK] manual generation retry respects Active Brain and transfer freeze')


def test_competing_generation_blocks_manual_retry():
    db=make_db()
    db.execute("INSERT INTO messages VALUES ('u','user','x',100)")
    db.execute("INSERT INTO generation_jobs(id,user_message_id,assistant_message_id,status,created_at,updated_at) VALUES ('g','u','a','failed',100,100)")
    db.execute("INSERT INTO generation_jobs(id,user_message_id,assistant_message_id,status,created_at,updated_at) VALUES ('other','u','othera','pending',101,101)")
    assert retry_failed_generation(db,'g') is False
    print('[OK] manual generation retry cannot create a second blocking generation')


def test_post_turn_manual_guard():
    db=make_db(); db.execute("INSERT INTO post_turn_jobs VALUES ('p','failed','',NULL,'boom',1,NULL,1)")
    db.execute("UPDATE settings SET value='0' WHERE key='active_brain'")
    assert retry_failed_post_turn(db)==0
    assert db.execute("SELECT status FROM post_turn_jobs WHERE id='p'").fetchone()[0]=='failed'
    db.execute("UPDATE settings SET value='1' WHERE key='active_brain'")
    assert retry_failed_post_turn(db)==1
    assert db.execute("SELECT status FROM post_turn_jobs WHERE id='p'").fetchone()[0]=='retry_wait'
    print('[OK] manual post-turn retry respects device ownership')


def test_earliest_due_semantics():
    # Mirrors the Dart effective-due calculation: a newer pending job must win
    # over an older running job whose stale deadline is far away.
    now=1_000_000
    running_stale=15*60*1000
    rows=[
      dict(status='running', next_retry_at=None, heartbeat_at=now, updated_at=now),
      dict(status='pending', next_retry_at=None, heartbeat_at=None, updated_at=now+1),
      dict(status='retry_wait', next_retry_at=now+120_000, heartbeat_at=None, updated_at=now+2),
    ]
    waits=[]
    for row in rows:
        if row['status']=='pending': waits.append(0)
        elif row['status']=='retry_wait': waits.append(max(0,row['next_retry_at']-now))
        else: waits.append(max(0,(row['heartbeat_at'] or row['updated_at'])+running_stale-now))
    assert min(waits)==0
    print('[OK] effective post-turn next-due selection is not tied to oldest created job')


if __name__=='__main__':
    test_failed_attention_latest_only()
    test_manual_generation_guard()
    test_competing_generation_blocks_manual_retry()
    test_post_turn_manual_guard()
    test_earliest_due_semantics()
    print('v0.16 recovery orchestration SQLite simulation passed.')
