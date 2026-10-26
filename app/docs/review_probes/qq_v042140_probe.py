"""Review evidence only: run the shipped QQ DDL/SQL on synthetic SQLite rows.

This is not a Dart/native integration test and does not mutate app source/data.
"""
from pathlib import Path
import hashlib
import json
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[3]

# Frozen review evidence, not a production regression gate.
EXPECTED_SOURCE_HASHES = {'app/lib/core/database/qq_archive_schema.dart': '42a1a00087cc789e65e93e33b27f12946efdf53c853f2bb4e273ca684e0eca26', 'app/lib/integrations/qq_private/qq_store.dart': 'b0ceb75304e387bcf3d9f4109b77346df8b017712f179eb1e86ad99f991b7f03', 'app/lib/integrations/qq_private/qq_runtime.dart': '34858218da31065e184e0c078cc4f9e38ed7c9599f3fbde14ede684bb1e91011', 'app/lib/integrations/qq_private/qq_options.dart': 'c316d0027b5f84ecd905e8799da3b112d3c655e7e1a62357fe7c44289c43729d', 'app/lib/integrations/qq_private/qq_group_binding.dart': 'd72983ad7ec8c7f12ee47a389c3d710cc3cbcbfdca6c3f4329d65de931b1561b', 'app/lib/integrations/qq_private/qq_reply_parts.dart': '85d3e11b94d5b64bc9e9657200f486ba1c8bf10f71c8fe14ae5a79305ce4826b', 'app/lib/integrations/qq_private/qq_reply_delivery.dart': 'de9e8ed30e4bad400eaac4d5727063dbad3a1650d9d41dceedfb49774045c344', 'app/packages/qq_private_bridge/lib/src/qq_session.dart': '74624f503b9ba08081d1704c8b264ce049380ec91b51f3895363c86a9db9a336', 'app/android/app/src/main/kotlin/com/aicompanion/localfirst/qq/QqPrivateService.kt': '18f2f6163306c9e00da176aaa95b0ecbdd4f552439032ae6e9e6394227ed072e'}
for source_path, source_digest in EXPECTED_SOURCE_HASHES.items():
    if hashlib.sha256((ROOT/source_path).read_bytes()).hexdigest() != source_digest:
        raise SystemExit("This evidence script applies only to the reviewed +384 source; use the new production regressions after repairs.")

SCHEMA = (ROOT/'app/lib/core/database/qq_archive_schema.dart').read_text()
STORE = (ROOT/'app/lib/integrations/qq_private/qq_store.dart').read_text()
RUNTIME = (ROOT/'app/lib/integrations/qq_private/qq_runtime.dart').read_text()
NATIVE = (ROOT/'app/android/app/src/main/kotlin/com/aicompanion/localfirst/qq/QqPrivateService.kt').read_text()
PARTS = (ROOT/'app/lib/integrations/qq_private/qq_reply_parts.dart').read_text()
DELIVERY = (ROOT/'app/lib/integrations/qq_private/qq_reply_delivery.dart').read_text()

def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))

keys = re.findall(r"'([^']+)'", re.search(r'identityKeys=\[([\s\S]*?)\];', STORE)[1])

def database():
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    create = SCHEMA[SCHEMA.index('static Future<void> create'):SCHEMA.index('/// Upgrade source ranges')]
    tables = re.findall(r"await sql.execute\('''([\s\S]*?)'''\)", create)
    tables += re.findall(r"await sql.execute\('(CREATE TABLE[^\n]+)'\)", create)
    assert len(tables) == 7
    for sql in tables:
        db.execute(sql)
    db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)')
    db.execute("INSERT INTO qq_conversations(id,scope,kind,target) VALUES('c','scope','group','g')")
    return db

def fence(db):
    snapshot = dict(db.execute('SELECT key,value FROM settings').fetchall())
    return {k: snapshot.get(k, '') for k in [*keys, 'qq_archive_epoch_v1:c']}

def advance_epoch(db):
    db.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('qq_archive_epoch_v1:c','1')")
    db.execute("UPDATE qq_conversations SET version=version+1 WHERE id='c'")

def append(db, platform, identity=None):
    identity = fence(db) if identity is None else identity
    row_id = hashlib.sha256(encoded(['scope','group','g',platform]).encode()).hexdigest()
    # Shipped duplicate gate, independent from the projection below.
    if db.execute('SELECT seq,mentioned FROM qq_archive WHERE id = ?', [row_id]).fetchone():
        return None
    return db.execute('INSERT INTO qq_archive(id,conversation_id,platform_id,sender,role,content,observed_at,received_at,accepted_identity,accepted_policy) VALUES(?,?,?,?,?,?,?,?,?,?)',
        [row_id,'c',platform,'peer','user',platform,1000,1000,encoded(identity),'policy']).lastrowid

def pending(db):
    return db.execute('SELECT a.* FROM qq_archive a JOIN qq_conversations c ON c.id=a.conversation_id '
        "WHERE c.id=? AND a.seq>c.checked_seq AND a.role='user' ORDER BY a.seq LIMIT 40", ['c']).fetchall()

def claim(db):
    waiting = pending(db)
    if not waiting:
        return []
    through = waiting[-1]['seq']
    admitted = [r for r in waiting if r['accepted_identity']==encoded(fence(db)) and r['accepted_policy']=='policy']
    # The empty-admission branch also advances this cursor in the app.
    db.execute('UPDATE qq_conversations SET checked_seq=? WHERE id=?', [through,'c'])
    return admitted

results = []

# A genuine new input remains stored, but an unrelated note edit changes the
# accepted-identity comparison and consumes it without a delivery/model call.
db = database()
old = append(db, 'source-for-existing-note')
db.execute('UPDATE qq_conversations SET checked_seq=? WHERE id=?', [old,'c'])
new = append(db, 'new-input-waiting-for-its-turn')
before = len(pending(db))
advance_epoch(db)  # qq_archive_admin._advance, called after edit/delete.
admitted = claim(db)
assert before == 1 and len(admitted) == 0 and len(pending(db)) == 0
assert db.execute('SELECT content FROM qq_archive WHERE seq=?', [new]).fetchone()
results.append({'id':'R1','pending_before_edit':before,'admitted_after_edit':len(admitted),'pending_after_claim':len(pending(db)),'raw_retained':True})
db.close()

# Removing a recently received raw message removes the only ingress ID gate.
# The platform replay is a conditional input; there is no claim here that QQ
# must display a duplicate (its msg_id/msg_seq gate can reject the outbound).
db = database()
first = append(db, 'same-platform-event')
assert len(claim(db)) == 1
db.execute('DELETE FROM qq_archive WHERE conversation_id=?', ['c'])
db.execute('UPDATE qq_conversations SET checked_seq=0,summary_seq=0,summary_checked_seq=0 WHERE id=?', ['c'])
advance_epoch(db)
second = append(db, 'same-platform-event')
assert second > first and len(claim(db)) == 1
results.append({'id':'R2','deleted_event_reinserted':True,'first_seq':first,'replay_seq':second,'admitted_again':True})
db.close()

# The normal summary cursor is durably advanced before key/network/commit.
db = database()
for i in range(3):
    append(db, f'old-source-{i}')
rows = db.execute('SELECT * FROM qq_archive WHERE conversation_id=? AND seq>? ORDER BY seq LIMIT 20', ['c',0]).fetchall()
db.execute('UPDATE qq_conversations SET summary_checked_seq=? WHERE id=?', [rows[-1]['seq'],'c'])
# Simulate failed generation: saveNote was never called.
cursor = db.execute('SELECT summary_checked_seq FROM qq_conversations WHERE id=?', ['c']).fetchone()[0]
assert not db.execute('SELECT * FROM qq_archive WHERE conversation_id=? AND seq>? ORDER BY seq LIMIT 20', ['c',cursor]).fetchall()
fresh = append(db, 'next-day-new-input')
next_rows = db.execute('SELECT seq FROM qq_archive WHERE conversation_id=? AND seq>? ORDER BY seq LIMIT 20', ['c',cursor]).fetchall()
assert [r[0] for r in next_rows] == [fresh]
assert db.execute('SELECT COUNT(*) FROM qq_archive').fetchone()[0] == 4
assert db.execute('SELECT summary_seq FROM qq_conversations').fetchone()[0] == 0
results.append({'id':'R3','failed_sources_skipped':cursor,'after_new_input_next_claim':[r[0] for r in next_rows],'raw_count':4,'summary_seq':0})
db.close()

# Record the scheduler condition independently of the failure case: a normal
# successful claim does not enqueue its remaining tail, and start only queues
# invalid-note repair rather than normal unsummarized sources.
assert 'if(saved && claim.repairId.isNotEmpty' in RUNTIME
assert "where:'conversation_id=? AND valid=0'" in RUNTIME
db = database()
for i in range(21):
    append(db, f'source-{i}')
db.execute('UPDATE qq_conversations SET summary_checked_seq=20,summary_seq=20 WHERE id=?', ['c'])
tail = db.execute('SELECT seq FROM qq_archive WHERE conversation_id=? AND seq>? ORDER BY seq LIMIT 20', ['c',20]).fetchall()
assert len(tail)==1
results.append({'id':'O1','unprocessed_tail_after_one_20_row_claim':1,'normal_tail_auto_requeued':False})
db.close()

# Cross-isolate whole-document read/modify/write can overwrite a newer consent.
# Both call sites are present in production; the interleaving is synthetic.
OPTIONS = (ROOT/'app/lib/integrations/qq_private/qq_options.dart').read_text()
BINDING = (ROOT/'app/lib/integrations/qq_private/qq_group_binding.dart').read_text()
assert "value:identity" in OPTIONS and 'await o.copy(owners:' in BINDING
initial = {'groups':['g'],'owners':{},'core':'public persona','public':'public facts','visionFallback':False,'ownerShare':True}
app_read = json.loads(encoded(initial))
binding_read = json.loads(encoded(initial))
app_update = {**app_read, 'ownerShare':False}
binding_update = {**binding_read, 'owners':{'g':'trusted-owner'}}
secure_store = app_update  # The user disables sharing first.
secure_store = binding_update  # Previously read owner confirmation completes later.
assert secure_store['ownerShare'] is True
# There is also an interleaving which leaves the two stores inconsistent:
# A policy, B policy, B secure write, A secure write.
def digest(v): return hashlib.sha256(encoded(v).encode()).hexdigest()
db_policy = digest(binding_update)
secure_store = app_update
assert db_policy != digest(secure_store)
results.append({'id':'R4','revoked_owner_share_overwritten_by_older_binding_snapshot':True,
    'other_interleaving_policy_secure_mismatch':True,'evidence':'source-confirmed two writers + controlled state interleaving, no secure-storage runtime execution'})

# Exact small parser/chunk algorithm: 3 intended messages satisfy the aggregate
# 5400-rune check yet become 5 outbound messages under splitQqText.
assert "split(RegExp(r'<qq_next_message\\s*/>'))" in PARTS
assert '...splitQqText(message)' in DELIVERY
raw = '<qq_next_message/>'.join(['甲'*1801,'乙'*1801,'丙'*1700])
semantic = [p.strip() for p in re.split(r'<qq_next_message\s*/>', raw) if p.strip()]
chunks = [part[i:i+1800] for part in semantic for i in range(0,len(part),1800)]
assert len(semantic)==3 and len('\n'.join(semantic))<=5400 and len(chunks)==5
results.append({'id':'R5','chosen_messages':3,'accepted_runes':len('\n'.join(semantic)),'actual_text_sends':len(chunks)})

# Old native callbacks do not test autoReconnect again. This is a source-level
# truth-table counterexample, not execution of Android/Handler/Robolectric.
assert 'if (alive && enabled(this)) launchRuntime()' in NATIVE
assert 'if (!answered && alive && engine === owned && !retryPending) failed' in NATIVE
alive, enabled, auto, answered, same_engine, retry_pending = True, True, False, False, True, False
results.append({'id':'R6','auto_reconnect_after_user_uncheck':auto,
    'old_retry_launch_condition':alive and enabled,
    'old_ping_timeout_failure_condition':not answered and alive and same_engine and not retry_pending,
    'evidence':'source condition evaluation only; no Android runtime execution'})

out = {'baseline':'v0.42.140+384 / runtime 20dba209',
    'method':'shipped QQ DDL + synthetic SQLite state transitions; pure parser reproduction; native condition evaluation',
    'full_dart_native_tests_run':False,
    'schema_sha256':hashlib.sha256(SCHEMA.encode()).hexdigest(),'results':results}
target = Path(__file__).with_name("qq_v042140_probe_results.json")
target.write_text(json.dumps(out, ensure_ascii=False, indent=2))
print(json.dumps(out, ensure_ascii=False, indent=2))
