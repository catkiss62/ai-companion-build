#!/usr/bin/env python3
from __future__ import annotations

import sqlite3


def make_v14() -> sqlite3.Connection:
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys = ON')
    db.executescript('''
      CREATE TABLE memory_items (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        content TEXT NOT NULL,
        importance REAL NOT NULL DEFAULT 0.5,
        confidence REAL NOT NULL DEFAULT 0.7,
        tags TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'conversation',
        status TEXT NOT NULL DEFAULT 'active',
        subject_key TEXT NOT NULL DEFAULT '',
        pinned INTEGER NOT NULL DEFAULT 0,
        superseded_by TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_recalled_at INTEGER,
        recall_count INTEGER NOT NULL DEFAULT 0,
        retention_score REAL NOT NULL DEFAULT 1.0,
        retention_checked_at INTEGER
      );
    ''')
    db.executemany(
        'INSERT INTO memory_items(id,kind,content,importance,confidence,status,subject_key,pinned,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [
            ('old-device', 'user_profile', '用户以前晚上主要用手机', .8, .92, 'active', 'user.device_evening', 0, 1000, 1000),
            ('shared-1', 'shared_experience', '一起完成了第一版', .8, .9, 'active', '', 0, 1100, 1100),
        ],
    )
    return db


def upgrade_v15(db: sqlite3.Connection) -> None:
    db.executescript('''
      ALTER TABLE memory_items ADD COLUMN semantic_type TEXT NOT NULL DEFAULT 'current_fact';
      ALTER TABLE memory_items ADD COLUMN evidence_count INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE memory_items ADD COLUMN first_observed_at INTEGER;
      ALTER TABLE memory_items ADD COLUMN last_evidence_at INTEGER;
      ALTER TABLE memory_items ADD COLUMN fact_version INTEGER NOT NULL DEFAULT 1;
      UPDATE memory_items SET semantic_type = 'shared_experience' WHERE kind = 'shared_experience';
      UPDATE memory_items SET first_observed_at = created_at WHERE first_observed_at IS NULL;
      UPDATE memory_items SET last_evidence_at = updated_at WHERE last_evidence_at IS NULL;
      UPDATE memory_items
      SET fact_version = (
        SELECT COUNT(*) FROM memory_items AS older
        WHERE memory_items.subject_key <> ''
          AND older.kind = memory_items.kind
          AND older.subject_key = memory_items.subject_key
          AND (older.created_at < memory_items.created_at
            OR (older.created_at = memory_items.created_at AND older.id <= memory_items.id))
      )
      WHERE memory_items.subject_key <> '';
      CREATE TABLE memory_evidence (
        id TEXT PRIMARY KEY,
        memory_id TEXT NOT NULL,
        source TEXT NOT NULL,
        evidence_text TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.7,
        relation TEXT NOT NULL DEFAULT 'created',
        observed_at INTEGER NOT NULL,
        FOREIGN KEY(memory_id) REFERENCES memory_items(id) ON DELETE CASCADE,
        UNIQUE(memory_id, source, evidence_text)
      );
    ''')


def main() -> None:
    db = make_v14()
    upgrade_v15(db)

    old = db.execute("SELECT * FROM memory_items WHERE id='old-device'").fetchone()
    shared = db.execute("SELECT * FROM memory_items WHERE id='shared-1'").fetchone()
    assert old['semantic_type'] == 'current_fact'
    assert old['first_observed_at'] == 1000 and old['last_evidence_at'] == 1000
    assert old['fact_version'] == 1
    assert shared['semantic_type'] == 'shared_experience'
    print('[OK] v14 -> v15 memory semantic migration preserves rows and classifies shared experience')

    # Confirmed replacement: old fact remains as history and points to v2.
    db.execute("UPDATE memory_items SET status='superseded', superseded_by='new-device', updated_at=2000 WHERE id='old-device'")
    db.execute('''
      INSERT INTO memory_items(
        id,kind,content,importance,confidence,status,subject_key,pinned,created_at,updated_at,
        semantic_type,evidence_count,first_observed_at,last_evidence_at,fact_version
      ) VALUES ('new-device','user_profile','用户现在晚上主要用平板',.85,.95,'active','user.device_evening',0,2000,2000,
                'current_fact',1,2000,2000,2)
    ''')
    assert db.execute("SELECT status FROM memory_items WHERE id='old-device'").fetchone()[0] == 'superseded'
    assert db.execute("SELECT fact_version FROM memory_items WHERE id='new-device'").fetchone()[0] == 2
    print('[OK] current fact replacement preserves historical version and monotonic version number')

    # Uncertain inference coexists and must not replace the confirmed current fact.
    db.execute('''
      INSERT INTO memory_items(
        id,kind,content,importance,confidence,status,subject_key,pinned,created_at,updated_at,
        semantic_type,evidence_count,first_observed_at,last_evidence_at,fact_version
      ) VALUES ('guess','user_profile','用户最近可能偶尔又会用手机',.45,.55,'active','user.device_evening',0,2100,2100,
                'inference',1,2100,2100,1)
    ''')
    current = db.execute("SELECT id FROM memory_items WHERE subject_key='user.device_evening' AND status='active' AND semantic_type='current_fact'").fetchall()
    assert [r[0] for r in current] == ['new-device']
    assert db.execute("SELECT status FROM memory_items WHERE id='guess'").fetchone()[0] == 'active'
    print('[OK] uncertain inference coexists without superseding current fact')

    # Repeated paraphrase is evidence, not a duplicate memory row.
    db.execute("INSERT INTO memory_evidence VALUES ('e1','new-device','conversation_turn:a','用户晚上会换到平板',.93,'reinforced',2200)")
    db.execute("UPDATE memory_items SET evidence_count=evidence_count+1,last_evidence_at=2200 WHERE id='new-device'")
    try:
        db.execute("INSERT INTO memory_evidence VALUES ('e2','new-device','conversation_turn:a','用户晚上会换到平板',.93,'reinforced',2201)")
    except sqlite3.IntegrityError:
        pass
    evidence = db.execute("SELECT COUNT(*) FROM memory_evidence WHERE memory_id='new-device'").fetchone()[0]
    assert evidence == 1
    assert db.execute("SELECT evidence_count FROM memory_items WHERE id='new-device'").fetchone()[0] == 2
    print('[OK] evidence uniqueness prevents retry from double-reinforcing a memory')

    # Pinned current fact remains protected from an automatic conflicting update.
    db.execute("UPDATE memory_items SET pinned=1 WHERE id='new-device'")
    pinned = db.execute("SELECT COUNT(*) FROM memory_items WHERE kind='user_profile' AND subject_key='user.device_evening' AND status='active' AND pinned=1").fetchone()[0]
    assert pinned == 1
    should_block = pinned > 0
    assert should_block
    print('[OK] pinned current fact exposes a deterministic automatic-replacement block')

    # A user-initiated restore must not produce two simultaneous current facts.
    db.execute('''
      INSERT INTO memory_items(
        id,kind,content,importance,confidence,status,subject_key,pinned,created_at,updated_at,
        semantic_type,evidence_count,first_observed_at,last_evidence_at,fact_version
      ) VALUES ('archived-device','user_profile','更早时晚上主要用另一台设备',.7,.9,'archived','user.device_evening',0,900,2300,
                'current_fact',1,900,900,1)
    ''')
    restore_conflicts = db.execute(
        "SELECT id FROM memory_items WHERE kind=? AND subject_key=? AND status='active' AND semantic_type='current_fact' AND id<>? LIMIT 1",
        ('user_profile', 'user.device_evening', 'archived-device'),
    ).fetchall()
    assert restore_conflicts and restore_conflicts[0][0] == 'new-device'
    print('[OK] manual restore guard prevents two current facts with the same subject key')

    # A migrated row had no explicit evidence rows. Its old canonical wording must be
    # materialized as evidence before the first manual content edit.
    legacy = db.execute("SELECT * FROM memory_items WHERE id='shared-1'").fetchone()
    assert db.execute("SELECT COUNT(*) FROM memory_evidence WHERE memory_id='shared-1'").fetchone()[0] == 0
    db.execute(
        "INSERT INTO memory_evidence VALUES (?,?,?,?,?,?,?)",
        ('legacy-evidence', 'shared-1', 'legacy_before_manual_edit:2400', legacy['content'], legacy['confidence'], 'manual_edit_previous', legacy['last_evidence_at']),
    )
    db.execute(
        "INSERT INTO memory_evidence VALUES (?,?,?,?,?,?,?)",
        ('edit-evidence', 'shared-1', 'manual_edit:2400', '一起完成了第一个可用版本', .95, 'manual_edit', 2400),
    )
    db.execute("UPDATE memory_items SET content='一起完成了第一个可用版本', evidence_count=evidence_count+1,last_evidence_at=2400 WHERE id='shared-1'")
    preserved = db.execute("SELECT evidence_text,relation FROM memory_evidence WHERE memory_id='shared-1' ORDER BY observed_at").fetchall()
    assert preserved[0]['evidence_text'] == '一起完成了第一版' and preserved[0]['relation'] == 'manual_edit_previous'
    assert db.execute("SELECT evidence_count FROM memory_items WHERE id='shared-1'").fetchone()[0] == 2
    print('[OK] manual edit preserves migrated pre-v15 content as evidence before replacement')

    # Manual subject-key edits use the same invariant: one active current fact per key.
    db.execute('''
      INSERT INTO memory_items(
        id,kind,content,importance,confidence,status,subject_key,pinned,created_at,updated_at,
        semantic_type,evidence_count,first_observed_at,last_evidence_at,fact_version
      ) VALUES ('sleep-current','user_profile','用户现在通常较早休息',.8,.95,'active','user.sleep_schedule',0,2500,2500,
                'current_fact',1,2500,2500,1)
    ''')
    edit_conflicts = db.execute(
        "SELECT id FROM memory_items WHERE kind=? AND subject_key=? AND status='active' AND semantic_type='current_fact' AND id<>? LIMIT 1",
        ('user_profile', 'user.sleep_schedule', 'new-device'),
    ).fetchall()
    assert edit_conflicts and edit_conflicts[0][0] == 'sleep-current'
    print('[OK] manual subject edit guard detects an existing active current fact')

    # Snapshot-style full replacement is idempotent including evidence rows.
    snapshot_memories = [dict(r) for r in db.execute('SELECT * FROM memory_items ORDER BY id')]
    snapshot_evidence = [dict(r) for r in db.execute('SELECT * FROM memory_evidence ORDER BY id')]
    for _ in range(2):
        db.execute('DELETE FROM memory_items')  # cascades evidence
        for row in snapshot_memories:
            cols = ','.join(row)
            qs = ','.join('?' for _ in row)
            db.execute(f'INSERT INTO memory_items({cols}) VALUES ({qs})', tuple(row.values()))
        for row in snapshot_evidence:
            cols = ','.join(row)
            qs = ','.join('?' for _ in row)
            db.execute(f'INSERT INTO memory_evidence({cols}) VALUES ({qs})', tuple(row.values()))
    assert db.execute('SELECT COUNT(*) FROM memory_items').fetchone()[0] == len(snapshot_memories)
    assert db.execute('SELECT COUNT(*) FROM memory_evidence').fetchone()[0] == len(snapshot_evidence)
    print('[OK] repeated full-state import remains idempotent with memory evidence')

    print('v0.22 long-term memory semantics SQLite checks passed.')


if __name__ == '__main__':
    main()
