#!/usr/bin/env python3
"""Source-guarded SQLite/control-flow models for review, NOT Dart/App tests.
No real backups, QQ identities, model keys, network or personal text are used.
Run from a complete checkout: python app/docs/review_probes/qq_v042141_followup_probe.py
"""
from pathlib import Path
import hashlib,json,re,sqlite3,subprocess
APP=Path(__file__).resolve().parents[2]
QQ=APP/'lib/integrations/qq_private'
runtime=(QQ/'qq_runtime.dart').read_text();store=(QQ/'qq_store.dart').read_text();learning=(QQ/'qq_group_learning.dart').read_text();queue=(QQ/'qq_work_queue.dart').read_text()
# Frozen evidence: stop after implementation changes instead of asserting an old model.
EXPECTED = {'qq_runtime.dart': '17deba61edde6baaf284f3661f17f0950896b4d2c23344014522d1668c288073', 'qq_store.dart': 'd8e95f8123be8cb3d887a8cdb7c13c065c9adeaf1dfe56d2d2763a7a93153407', 'qq_group_learning.dart': '785cae7980bdf01875f96d757103879272ad2debea386d451962e3b22507b312', 'qq_work_queue.dart': '0d0b9328ee25adc26226b1a8504299e3869747bd24baa5b8a55c2bf2756793f2'}
for name,expected in EXPECTED.items():
 assert hashlib.sha256((QQ/name).read_text().rstrip("\n").encode()).hexdigest()==expected, "Reviewed source changed: "+name
assert "final content=result['memory'] is String?result['memory'] as String:'';" in runtime
assert "if(content.trim().isNotEmpty)" in store and 'QqWorkQueue.complete(txn,workId,runToken,now)' in store
assert "if((await store.pending(cid)).isNotEmpty)" in runtime
assert "finally {await _scheduleMaintenance(cid);}" in runtime
assert "finally {_enqueued.remove(cid);if(!_stopped && recheck) await _schedule(cid);}" in runtime
assert "WHERE conversation_id=? AND kind='style' AND state IN ('pending','running')" in learning
assert "[cursorKey(cid),'${included.last}']" in learning
schema=(APP/'lib/core/database/qq_archive_schema.dart').read_text().split('static Future<void> upgradeWork')[0]
def db():
 c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON');c.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)')
 for sql in re.findall(r"sql.execute\('''([\s\S]*?)'''\)",schema):c.execute(sql)
 c.execute("INSERT INTO qq_conversations(id,scope,kind,target) VALUES('fixture-cid','fixture-scope','group','fixture-target')")
 return c
def raw(c,n):
 c.execute("INSERT INTO qq_archive(seq,id,conversation_id,platform_id,sender,role,content,observed_at,received_at) VALUES(?,?,'fixture-cid',?,'fixture-member','user','synthetic',1,1)",(n,f'fixture-{n}',f'platform-{n}'))
def job(c,id,sources,kind='summary',state='running'):
 c.execute("INSERT INTO qq_work_items(id,conversation_id,kind,sources,identity,permit,state,attempts,run_token,created_at,updated_at) VALUES(?,'fixture-cid',?,?, '{}','{}',?,1,?,1,1)",(id,kind,json.dumps(sources),state,'fixture-token' if state=='running' else ''))
results={}
# F1: the host currently maps an invalid business object to the same successful
# empty output as an intentional memory:"". SQL follows saveNote/complete order.
outputs=[]
for payload in [{},{'memory':None},{'memory':7},{'memory':[]},{'memory':''}]:
 c=db();raw(c,1);job(c,'fixture-summary',[1]);content=payload.get('memory') if isinstance(payload.get('memory'),str) else ''
 if content.strip():raise AssertionError('fixture must follow empty branch')
 c.execute("UPDATE qq_conversations SET summary_seq=MAX(summary_seq,1),summary_checked_seq=1 WHERE id='fixture-cid'")
 c.execute("UPDATE qq_work_items SET state='complete',run_token='',updated_at=2 WHERE id='fixture-summary' AND state='running' AND run_token='fixture-token'")
 outputs.append({'input':payload,'notes':c.execute('SELECT COUNT(*) FROM qq_notes').fetchone()[0],'work':c.execute('SELECT state FROM qq_work_items').fetchone()[0],'summary_seq':c.execute('SELECT summary_seq FROM qq_conversations').fetchone()[0]});c.close()
assert all(r['notes']==0 and r['work']=='complete' and r['summary_seq']==1 for r in outputs)
results['F1_invalid_result_marked_complete']=outputs
# F2: exact success-only then/finally placement, modeled with standard Promise
# semantics shared by Dart Future.then. The injected failure is maintenance's
# pre-try pending read; no claim is made that an actual phone hit this fault.
js=r'''const enqueued=new Set(),processed=[];let tail=Promise.resolve().then(()=>{throw Error('injected pending-read failure')});
function enqueue(cid){if(enqueued.has(cid))return false;enqueued.add(cid);tail=tail.then(async()=>{try{processed.push(cid)}finally{enqueued.delete(cid)}}).catch(()=>{});return true;}
enqueue('conversation-A');await tail;const second=enqueue('conversation-A');enqueue('conversation-B');await tail;
console.log(JSON.stringify({blocked:[...enqueued],processed,secondAccepted:second}));'''
r=subprocess.run(['node','--input-type=module','-e',js],check=True,text=True,capture_output=True);poison=json.loads(r.stdout)
assert poison=={'blocked':['conversation-A'],'processed':['conversation-B'],'secondAccepted':False}
results['F2_rejected_tail_leaks_conversation_flag']=poison
# F3: editing one OLD observation cancels all pending/running style work,
# including a disjoint NEW human batch, without rewinding its consumed cursor.
c=db()
for n in range(1,14):raw(c,n)
c.execute("INSERT INTO qq_styles(id,conversation_id,content,sources,source_stamp,created_at) VALUES('old-profile','fixture-cid','old synthetic observation','[1]','[]',1)")
job(c,'new-unrelated-batch',list(range(2,14)),kind='style',state='pending')
c.execute("INSERT INTO settings(key,value) VALUES('qq_style_cursor_v1:fixture-cid','13')")
c.execute("UPDATE qq_styles SET content='edited synthetic observation',revision=revision+1,edited_at=2 WHERE id='old-profile'")
c.execute("UPDATE qq_work_items SET state='cancelled',run_token='' WHERE conversation_id=? AND kind='style' AND state IN ('pending','running')",['fixture-cid'])
state=c.execute("SELECT state FROM qq_work_items WHERE id='new-unrelated-batch'").fetchone()[0]
remaining=c.execute("SELECT COUNT(*) FROM qq_archive WHERE conversation_id='fixture-cid' AND role='user' AND seq>13").fetchone()[0]
assert state=='cancelled' and remaining==0
results['F3_unrelated_style_batch_consumed']={'new_batch_state':state,'new_batch_sources':12,'eligible_sources_after_edit':remaining};c.close()
# O1: shared work tail waits for an in-flight drawing before another private
# reply can run. This is an observed design coupling, not a crash reproduction.
js=r'''let finish;let ownerReplied=false;const gate=new Promise(resolve=>finish=resolve);let tail=Promise.resolve().then(()=>gate);tail=tail.then(()=>ownerReplied=true);await Promise.resolve();const during=ownerReplied;finish();await tail;console.log(JSON.stringify({duringDrawing: during,afterDrawing:ownerReplied}));'''
r=subprocess.run(['node','--input-type=module','-e',js],check=True,text=True,capture_output=True);serial=json.loads(r.stdout);assert serial=={'duringDrawing':False,'afterDrawing':True}
results['O1_cross_conversation_queue_coupling']=serial
results['source_guards_sha256_normalized']={p.name:hashlib.sha256(p.read_text().rstrip('\n').encode()).hexdigest() for p in [QQ/'qq_runtime.dart',QQ/'qq_store.dart',QQ/'qq_group_learning.dart',QQ/'qq_work_queue.dart']}
results['limits']='SQLite and async control-flow models only. Not a Flutter, Android or live QQ test; no evidence a particular phone experienced these injected faults.'
print(json.dumps(results,ensure_ascii=False,indent=2))
