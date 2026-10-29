"""Synthetic SQLite counterexamples, not a Flutter/Dart behavior test.

Audited production clauses are checked before use. No backup, network, model,
credentials, actual messages or QQ accounts are read or modified.
"""
from pathlib import Path
import json
import re
import sqlite3

APP = Path(__file__).resolve().parents[2]
SQL = (APP / 'lib/core/database/app_database.dart').read_text()
ENGINE = (APP / 'lib/core/desire/proactive_engine.dart').read_text()
CORE = (APP / 'lib/core/desire/desire_core_policy.dart').read_text()
THOUGHT = (APP / 'lib/core/models/thought.dart').read_text()
QQ = (APP / 'lib/integrations/qq_private/qq_share_store.dart').read_text()
WORKER = (APP / 'lib/core/creative/creative_worker.dart').read_text()
STORE = (APP / 'lib/core/creative/creative_store.dart').read_text()


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


ready = section(SQL, 'Future<PublicWebShareCandidate?> activeReadyPublicWebShareCandidate(',
                'Future<void> beginPublicWebShareTest(')
ready_where = re.search(r'where: "([^"]+)"', ready).group(1)
claim = section(SQL, 'Future<PublicWebShareStageLease?> claimNextPublicWebCandidateForSharing(',
                'Future<PublicWebShareCandidate?> nextPublicWebCandidateForSharing(')
block_where = re.search(r'where: "([^"]+)"', claim).group(1)
pending_where = re.findall(r'where: "([^"]+)"', claim)[1]
preview = section(SQL, 'Future<PublicWebShareCandidate?> nextPublicWebCandidateForSharing(',
                  'Future<PublicWebCandidateDraft?> publicWebCandidateForRefresh(')
assert 'if (ready != null) return null;' in preview
assert 'if (ready.isNotEmpty) return null;' in claim
assert 't.canDriveIntentAt(now)' in CORE
assert "(lifecycleState == 'active' || lifecycleState == 'fixation')" in THOUGHT
assert 'if (readyThought != null)' in ENGINE
remove = section(SQL, 'Future<void> deleteThought(String id)',
                 'Future<CompanionThought?> thoughtById(')
assert 'public_web_candidates' not in remove
# All exits, including WAIT, leave no QQ claim settlement in this writer.
assert ENGINE.count('qqShare.') == 1  # only prompt construction
assert 'releaseProactiveLease' in ENGINE
assert "{'state':'claimed','destination':destination,'updated_at':now.millisecondsSinceEpoch}" in QQ
cooldown_sql = re.search(r'rawQuery\("(SELECT 1 FROM qq_shares[^"\n]+)"', QQ).group(1)
assert "s.state='pending'" in QQ

now = 2_000_000_000_000
results = []
for mode in ('missing', 'dormant', 'snoozed', 'active', 'expired'):
    db = sqlite3.connect(':memory:')
    db.execute('CREATE TABLE public_web_candidates(id TEXT, lifecycle_state TEXT, read_state TEXT, semantic_state TEXT, expires_at INTEGER, share_score REAL, share_retry_at INTEGER, discovered_at INTEGER)')
    db.execute('CREATE TABLE thoughts(id TEXT, source TEXT, lifecycle_state TEXT, snoozed_until INTEGER)')
    db.execute('INSERT INTO public_web_candidates VALUES(?,?,?,?,?,?,?,?)',
               ('old-ready', 'share_ready', 'verified', 'valid', now-1 if mode=='expired' else now+86400000, .9, 0, now-1000))
    db.execute('INSERT INTO public_web_candidates VALUES(?,?,?,?,?,?,?,?)',
               ('fresh-unread', 'unread', 'verified', 'valid', now+86400000, .9, 0, now))
    if mode != 'missing':
        db.execute('INSERT INTO thoughts VALUES(?,?,?,?)',
                   ('bound', 'public_web_candidate:old-ready', 'dormant' if mode=='dormant' else 'active', now+3600000 if mode=='snoozed' else 0))
    active_ready = db.execute('SELECT id FROM public_web_candidates WHERE '+ready_where+' LIMIT 1', [now]).fetchone()
    stage_block = db.execute('SELECT id FROM public_web_candidates WHERE '+block_where+' LIMIT 1', [now]).fetchone()
    bound = db.execute('SELECT lifecycle_state,snoozed_until FROM thoughts WHERE source=?', ['public_web_candidate:old-ready']).fetchone()
    thought_eligible = bool(bound and bound[0] in ('active','fixation') and bound[1] <= now)
    unread = db.execute('SELECT id FROM public_web_candidates WHERE '+pending_where+' LIMIT 1', [now,now]).fetchone()
    new_candidate_reachable = active_ready is None and stage_block is None and unread is not None
    if mode in ('missing','dormant','snoozed'):
        assert not thought_eligible and active_ready and stage_block and not new_candidate_reachable
    elif mode == 'active':
        assert thought_eligible and active_ready and not new_candidate_reachable
    else:
        assert new_candidate_reachable
    results.append({'case':'web_'+mode,'old_ready_exists':bool(active_ready),
                    'old_thought_can_drive':thought_eligible,
                    'fresh_unread_reachable':new_candidate_reachable,
                    'finding':mode in ('missing','dormant','snoozed')})
    db.close()

for ending in ('WAIT','preempted','sent'):
    db=sqlite3.connect(':memory:')
    db.execute('CREATE TABLE qq_shares(id TEXT, state TEXT, destination TEXT, updated_at INTEGER)')
    db.executemany('INSERT INTO qq_shares VALUES(?,?,?,?)',
                   [('selected','pending','',now),('later','pending','',now)])
    db.execute("UPDATE qq_shares SET state='claimed',destination='app',updated_at=? WHERE id=? AND state=?",[now,'selected','pending'])
    if ending=='sent':
        db.execute("UPDATE qq_shares SET state='sent',destination='app:message' WHERE id='selected'")
    # WAIT/preemption has no matching production state transition.
    state=db.execute("SELECT state FROM qq_shares WHERE id='selected'").fetchone()[0]
    blocks_now=db.execute(cooldown_sql,[now-6*3600000]).fetchone() is not None
    blocks_after_7h=db.execute(cooldown_sql,[now+3600000]).fetchone() is not None
    selected_can_return=db.execute("SELECT id FROM qq_shares WHERE id='selected' AND state='pending'").fetchone() is not None
    assert blocks_now and not blocks_after_7h and not selected_can_return
    assert state==('sent' if ending=='sent' else 'claimed')
    results.append({'case':'qq_app_'+ending,'state':state,'blocks_other_shares_for_6h':blocks_now,
                    'selected_returns_after_7h':selected_can_return,'finding':ending!='sent'})
    db.close()

assert 'final candidates = (await store.list(pendingOnly: true' in WORKER
assert "static const active = {'queued', 'building', 'checking'};" in (APP/'lib/core/creative/creative_contract.dart').read_text()
assert "'status': 'queued', 'attempts': 0, 'retry_at': 0" in STORE
assert "if (attempts >= maxModelTurns)" in WORKER
results.append({'case':'creative_resume_contract','paused_polled':False,
                'queued_polled':True,'manual_resume_resets_attempt_budget':True,
                'finding':False,'verification':'source contracts, not Dart execution'})
print(json.dumps(results,indent=2))
