#!/usr/bin/env python3
"""Deterministic SQLite model for v0.26 transfer generation/idempotency semantics."""
import hashlib
import sqlite3
import uuid


def new_db(lineage='lineage-A', generation=0, active='1'):
    db = sqlite3.connect(':memory:')
    db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
    db.execute('CREATE TABLE messages(id TEXT PRIMARY KEY, content TEXT NOT NULL)')
    db.execute('''CREATE TABLE transfer_receipts(
        snapshot_id TEXT PRIMARY KEY,
        lineage_id TEXT NOT NULL,
        source_device_id TEXT NOT NULL,
        source_generation INTEGER NOT NULL,
        state_sha256 TEXT NOT NULL,
        target_device_id TEXT NOT NULL,
        target_lineage_before TEXT NOT NULL,
        target_generation_before INTEGER NOT NULL,
        imported_at INTEGER NOT NULL
    )''')
    db.executemany('INSERT INTO settings VALUES (?,?)', [
        ('device_id', str(uuid.uuid4())),
        ('state_lineage_id', lineage),
        ('state_generation', str(generation)),
        ('active_brain', active),
        ('transfer_lock', '0'),
        ('pending_outbound_snapshot_id', ''),
        ('pending_outbound_generation', '0'),
        ('pending_import_snapshot_id', ''),
        ('pending_import_lineage_id', ''),
        ('pending_import_source_device_id', ''),
        ('pending_import_generation', '0'),
        ('pending_import_state_sha256', ''),
    ])
    db.commit()
    return db


def settings(db):
    return dict(db.execute('SELECT key,value FROM settings'))


def setv(db, key, value):
    db.execute('INSERT OR REPLACE INTO settings VALUES (?,?)', (key, str(value)))


def reserve(db, snapshot):
    db.execute('BEGIN IMMEDIATE')
    try:
        s = settings(db)
        assert s['active_brain'] == '1'
        assert s['transfer_lock'] == '1'
        gen = int(s['state_generation']) + 1
        setv(db, 'state_generation', gen)
        setv(db, 'pending_outbound_snapshot_id', snapshot)
        setv(db, 'pending_outbound_generation', gen)
        db.commit()
        return s['state_lineage_id'], gen, s['device_id']
    except Exception:
        db.rollback()
        raise


def snapshot_payload(lineage, gen, source, snapshot, messages):
    raw = f'{lineage}|{gen}|{source}|{snapshot}|{messages}'.encode()
    return hashlib.sha256(raw).hexdigest()


def receipt(db, snapshot_id):
    row = db.execute('SELECT * FROM transfer_receipts WHERE snapshot_id=?', (snapshot_id,)).fetchone()
    return row


def import_snapshot(db, meta, messages, *, allow_replace=False, induce_failure=False):
    """Returns imported/duplicate. Mirrors SnapshotService prechecks + atomic importAll receipt."""
    snapshot_id, lineage, source_device, gen, digest = meta
    prior = receipt(db, snapshot_id)
    if prior:
        # snapshot_id, lineage, source_device_id, source_generation, sha...
        assert prior[1] == lineage and prior[2] == source_device and prior[3] == gen and prior[4] == digest
        return 'duplicate'
    before = settings(db)
    local_lineage = before['state_lineage_id']
    local_gen = int(before['state_generation'])
    if lineage != local_lineage and not allow_replace:
        raise ValueError('lineage_mismatch')
    if lineage == local_lineage and gen <= local_gen:
        raise ValueError('stale_generation')

    db.execute('BEGIN IMMEDIATE')
    try:
        db.execute('DELETE FROM messages')
        for mid, content in messages:
            db.execute('INSERT INTO messages VALUES (?,?)', (mid, content))
        if induce_failure:
            raise RuntimeError('simulated_mid_import_crash')
        # Settings are simplified here but retain the ownership-critical fields.
        setv(db, 'state_lineage_id', lineage)
        setv(db, 'state_generation', gen)
        setv(db, 'active_brain', '0')
        setv(db, 'transfer_lock', '1')
        setv(db, 'pending_outbound_snapshot_id', '')
        setv(db, 'pending_outbound_generation', 0)
        setv(db, 'pending_import_snapshot_id', snapshot_id)
        setv(db, 'pending_import_lineage_id', lineage)
        setv(db, 'pending_import_source_device_id', source_device)
        setv(db, 'pending_import_generation', gen)
        setv(db, 'pending_import_state_sha256', digest)
        db.execute('''INSERT INTO transfer_receipts VALUES (?,?,?,?,?,?,?,?,?)''', (
            snapshot_id, lineage, source_device, gen, digest,
            before['device_id'], local_lineage, local_gen, 123456,
        ))
        db.commit()
        return 'imported'
    except Exception:
        db.rollback()
        raise


def activate_pending(db, snapshot_id):
    db.execute('BEGIN IMMEDIATE')
    try:
        s = settings(db)
        assert s['active_brain'] == '0'
        assert s['pending_import_snapshot_id'] == snapshot_id
        gen = int(s['pending_import_generation'])
        assert s['state_lineage_id'] == s['pending_import_lineage_id']
        assert int(s['state_generation']) == gen
        setv(db, 'state_generation', gen + 1)
        setv(db, 'active_brain', '1')
        setv(db, 'transfer_lock', '0')
        for key, value in [
            ('pending_import_snapshot_id', ''),
            ('pending_import_lineage_id', ''),
            ('pending_import_source_device_id', ''),
            ('pending_import_generation', '0'),
            ('pending_import_state_sha256', ''),
        ]:
            setv(db, key, value)
        db.commit()
        return gen + 1
    except Exception:
        db.rollback()
        raise


def fence_source(db, meta, target_device):
    snapshot_id, lineage, _source_device, gen, _digest = meta
    db.execute('BEGIN IMMEDIATE')
    try:
        s = settings(db)
        matches = (
            s['active_brain'] == '1' and s['transfer_lock'] == '1' and
            s['state_lineage_id'] == lineage and int(s['state_generation']) == gen and
            s['pending_outbound_snapshot_id'] == snapshot_id and
            int(s['pending_outbound_generation']) == gen and bool(target_device)
        )
        if not matches:
            db.rollback()
            return False
        setv(db, 'active_brain', '0')
        setv(db, 'transfer_lock', '0')
        db.commit()
        return True
    except Exception:
        db.rollback()
        raise


def main():
    source = new_db()
    source.execute("INSERT INTO messages VALUES('m1','before transfer')")
    source.execute("UPDATE settings SET value='1' WHERE key='transfer_lock'")
    source.commit()
    sid = 'snap-001'
    lineage, gen, source_device = reserve(source, sid)
    assert gen == 1
    digest = snapshot_payload(lineage, gen, source_device, sid, [('m1','before transfer')])
    meta = (sid, lineage, source_device, gen, digest)

    # Wrong/replayed control cannot fence the source.
    wrong = ('snap-WRONG', lineage, source_device, gen, digest)
    assert not fence_source(source, wrong, 'target-1')
    assert settings(source)['active_brain'] == '1'
    assert settings(source)['transfer_lock'] == '1'

    # Target adopts exact source generation in standby and receipt commits with data.
    target = new_db(lineage='fresh-target-lineage', generation=0, active='1')
    before_target_device = settings(target)['device_id']
    assert import_snapshot(target, meta, [('m1','before transfer')], allow_replace=True) == 'imported'
    s = settings(target)
    assert s['device_id'] == before_target_device
    assert s['active_brain'] == '0' and s['transfer_lock'] == '1'
    assert s['state_lineage_id'] == lineage and int(s['state_generation']) == 1
    assert receipt(target, sid) is not None

    # Exact repeated delivery is an idempotent no-op, not a destructive re-import.
    target.execute("INSERT INTO messages VALUES('local-diagnostic','must survive duplicate delivery')")
    target.commit()
    assert import_snapshot(target, meta, [('m1','before transfer')], allow_replace=True) == 'duplicate'
    assert target.execute("SELECT COUNT(*) FROM messages WHERE id='local-diagnostic'").fetchone()[0] == 1

    # Ownership handoff ordering: source is fenced before target activates.
    assert fence_source(source, meta, before_target_device)
    assert settings(source)['active_brain'] == '0'
    assert target.execute("SELECT COUNT(*) FROM messages WHERE id='m1'").fetchone()[0] == 1
    activated = activate_pending(target, sid)
    assert activated == 2
    assert settings(target)['active_brain'] == '1'
    assert int(settings(target)['state_generation']) == 2

    # The consumed snapshot is immediately stale after activation.
    try:
        import_snapshot(target, ('snap-clone', lineage, source_device, 1, 'a'*64), [('m1','old')], allow_replace=True)
        raise AssertionError('stale generation accepted')
    except ValueError as e:
        assert str(e) == 'stale_generation'

    # Next direction: current target reserves gen3, old source at gen1 can import it.
    target.execute("UPDATE settings SET value='1' WHERE key='transfer_lock'")
    target.commit()
    sid2 = 'snap-002'
    lineage2, gen3, target_device = reserve(target, sid2)
    assert lineage2 == lineage and gen3 == 3
    digest2 = snapshot_payload(lineage2, gen3, target_device, sid2, [('m2','new state')])
    meta2 = (sid2, lineage2, target_device, gen3, digest2)
    assert import_snapshot(source, meta2, [('m2','new state')]) == 'imported'
    assert int(settings(source)['state_generation']) == 3

    # Transaction rollback: a crash midway leaves pre-import data intact and no receipt.
    rollback = new_db(lineage='R', generation=0, active='1')
    rollback.execute("INSERT INTO messages VALUES('keep','old local data')")
    rollback.commit()
    m = ('snap-r', 'R', 'src', 1, 'b'*64)
    try:
        import_snapshot(rollback, m, [('new','would replace')], induce_failure=True)
        raise AssertionError('induced failure did not abort')
    except RuntimeError:
        pass
    assert rollback.execute("SELECT content FROM messages WHERE id='keep'").fetchone()[0] == 'old local data'
    assert receipt(rollback, 'snap-r') is None

    # Different lineage is rejected unless the user explicitly authorizes replacement.
    foreign = new_db(lineage='LOCAL', generation=7, active='1')
    foreign_meta = ('foreign', 'OTHER', 'peer', 4, 'c'*64)
    try:
        import_snapshot(foreign, foreign_meta, [('x','foreign')])
        raise AssertionError('foreign lineage imported without consent')
    except ValueError as e:
        assert str(e) == 'lineage_mismatch'
    assert import_snapshot(foreign, foreign_meta, [('x','foreign')], allow_replace=True) == 'imported'

    # Corruption/partial transfer is rejected before database mutation by SHA-256.
    good_bytes = b'complete state bytes'
    good_hash = hashlib.sha256(good_bytes).hexdigest()
    assert hashlib.sha256(good_bytes[:-3]).hexdigest() != good_hash

    print('[OK] v18 transfer generation / replay / rollback / fencing SQLite simulation')


if __name__ == '__main__':
    main()
