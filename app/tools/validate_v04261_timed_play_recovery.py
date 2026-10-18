"""Protect recovery ownership and preserve manual Stop and reply contracts."""
from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
read = lambda path: (app / path).read_text()
task = read('lib/core/mcp/cedar_timed_play_task.dart')
for token in ('_reconcileLocked', "'cedar_toy_action_lease_until'", 'onlyIfActive: true',
              'snapshot_clock_rebuilt', 'runtime_clock_rebuilt', 'expectedRaw: raw',
              "session.pauseSource != 'remote_wait_unroutable'", "'game_finished'",
              'period.tick(now, pause: waiting)', "'finished_or_waiting_user'"):
    assert token in task, token
assert 'Timer.periodic' not in task and 'client.play(' not in task
assert "reason = 'runtime_interrupted'" not in task
clock = read('lib/core/mcp/cedar_play_session_policy.dart')
for token in ('checkpointGap = Duration(seconds: 30)', 'observedTaskGap', 'clockId',
              "task?['id'] != state.taskId", 'recorded?.clockId != state.clockId',
              'expectedSettings:', 'processEpoch'):
    assert token in clock, token
engine = read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
assert 'if (period?.taskId.isNotEmpty == true && await playPeriods.load() == null)' not in engine
assert 'if (period?.taskId.isNotEmpty == true)' in engine
assert 'CedarTimedPlayTaskStore(db).reconcile(DateTime.now())' in engine
assert 'if (tick.usedMs >= tick.limitMs)' in engine
assert 'CedarPlaySession.checkpointGap' in read('lib/core/maintenance/recovery_orchestrator.dart')
snapshot = read('lib/core/sync/snapshot_service.dart')
assert snapshot.count("'cedar_toy_play_session_v1': ''") == 2
assert snapshot.count("'cedar_timed_play_task_lease_v1': '0'") == 2
assert 'await CedarPlaySessionStore(db).pause(DateTime.now());' in snapshot
log = read('lib/core/mcp/cedar_play_transition_log.dart')
assert 'entries.length > 32' in log and "'contentIncluded': false" in log
assert 'timedTaskTransitions' in read('lib/core/diagnostics/preflight_diagnostics.dart')
# Manual control now changes the activity, clock, pending registration and
# ended report in one transaction. It must not perform several independent
# runner writes, which could let an old registration restart after Stop.
runner = read('lib/core/agent/agent_tool_runner.dart')
assert 'CedarToyActivityStore(db).applyControl(' in runner
activity = read('lib/core/mcp/cedar_toy_activity.dart')
control = activity.split('Future<LocalEffectAdmission> applyControl(', 1)[1].split('Future<void>', 1)[0]
for token in ('handle.transaction', 'fence.matches(txn)',
              'originalUserControlRevisionInTransaction',
              'CedarTimedPlayTaskStore.cancelPendingInTransaction(txn,',
              'CedarTimedPlayTaskStore.finishInTransaction(txn,',
              'requireTurnNotCancelled(isCancelled)', 'userControlRevisionKey: _uuid.v4()'):
    assert token in control, token
assert 'userControlRevision' in task and "'cancelledReason'" in task
assert "await CedarPlaySessionStore(db).end('user_pause')" in clock
assert 'CedarPlayTransitionLog' not in read('lib/core/desire/proactive_engine.dart')
assert re.search(r'^version: 0.42.(?:61\+305|62\+306|63\+307|64\+308|65\+309|66\+310|67\+311|68\+312|69\+313|70\+314|71\+315|72\+316|73\+317|74\+318|75\+319|76\+320|77\+321|78\+322|79\+323|80\+324|81\+325|82\+326|83\+327|84\+328|85\+329|86\+330|87\+331|88\+332|89\+333|90\+334|91\+335|92\+336|93\+337|94\+338|95\+339|96\+340|97\+341|98\+342|99\+343|100\+344|101\+345|102\+346|103\+347|104\+348|105\+349|106\+350|107\+351|108\+352|109\+353|110\+354|111\+355|112\+356|113\+357|114\+358|115\+359|116\+360|117\+361)$', read('pubspec.yaml'), re.M)
assert (app / 'test/cedar_timed_recovery_v04261_test.dart').is_file()
print('v0.42.61 timed recovery, task clock, writer fencing and neutral manual Stop wired')
