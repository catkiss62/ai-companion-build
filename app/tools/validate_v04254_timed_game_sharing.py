from pathlib import Path

app = Path(__file__).resolve().parents[1]
def read(name):
    return (app / name).read_text()

task = read('lib/core/mcp/cedar_timed_play_task.dart')
for token in ('activateCommitted', 'messageById(assistantId)',
              'setSettingsAtomically', 'runtime_interrupted', 'changed_game',
              'budget_complete', 'pendingReports', 'cedar-share:',
              "lifecycleState: 'task_report'", 'contentIncluded',
              'CedarToyAutonomyEngine.continueDue'):
    assert token in task, token
assert 'Timer.periodic' not in task and 'client.play(' not in task
registry = read('lib/core/agent/agent_tool_registry.dart')
entry = registry.split('static const cedarToyTimedPlay', 1)[1].split(');', 1)[0]
assert 'autonomousAvailable: false' in entry
runner = read('lib/core/agent/agent_tool_runner.dart')
assert 'durationMinutes(' in runner and 'userMessageId.isEmpty' in runner
generation = read('lib/core/ai/durable_generation_runner.dart')
assert generation.index('activateCommitted(turnId: user.id') > generation.index('if (!committed)')
engine = read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
for token in ('share_previous_outcome', 'planningContext(session, now)',
              'share: decision.sharePreviousOutcome', 'timed_task_complete',
              'directForProgress: true', 'episode.antiAddictionPresent && sustained'):
    assert token in engine, token
share = read('lib/core/mcp/cedar_live_share_policy.dart')
for token in ('isResultSnapshot', 'isReadOnly', "state['evaluated']",
              "state['pending']", 'sharedThrough', 'queueDirectShare'):
    assert token in share, token
assert 'completeJson(' not in share and 'streamChat(' not in share
proactive = read('lib/core/desire/proactive_engine.dart')
assert 'queueReport()' in proactive and 'tasks.acknowledge' in proactive
assert "'cedar-share:${intentThought!.id}'" in proactive
assert 'queuedCedarShares.contains(thought.id)' in proactive
# Older unsolicited memories retain the original limits. The direct queue
# intentionally uses the existing forced delivery, preserving runtime gates.
assert 'Duration(minutes: 45)' in read('lib/core/desire/proactive_delivery_budget.dart')
assert 'budget.blockReason(gameShare: isCedarGameShare)' in proactive and 'forceForDebug: true' in proactive
assert 'isImmersiveChatPageVisible' in proactive and 'commitProactiveMessageIfCurrent' in proactive
assert read('lib/core/sync/snapshot_service.dart').count("'cedar_timed_play_pending_v1': ''") == 2
assert (app / 'test/cedar_timed_live_share_v04254_test.dart').is_file()
assert any('version: ' + version in read('pubspec.yaml')
           for version in ('0.42.54+298', '0.42.55+299', '0.42.56+300'))
print('v0.42.54 explicit timed task, durable report and native progress sharing wired')
