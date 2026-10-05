from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ['0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322'])
store = read('lib/core/desire/daily_wake_store.dart')
assert 'db.transaction' in store and 'nextInt(61)' in store and 'sampledAt' in store
budget = read('lib/core/desire/proactive_delivery_budget.dart')
assert 'wake.wakeAt.millisecondsSinceEpoch' in budget
assert "NOT GLOB 'game_share:immediate:*'" in budget
assert 'gameShare && gameDayUsed >= 6' in budget
engine = read('lib/core/desire/proactive_engine.dart')
assert 'wakeAt: budget.wakeAt' in engine and 'cedarShareThoughtId:' in engine
assert 'enforceProactiveBudget: !forceForDebug' in engine
commit = read('lib/core/database/app_database.dart').split('Future<String?> commitProactiveMessageIfCurrent', 1)[1]
assert commit.index("return 'cedar_share_before_wake'") < commit.index("await txn.insert(\n        'messages',")
assert 'DailyWakeStore.keyFor(sentAt) != DailyWakeStore.keyFor(evaluationStartedAt)' in commit
assert 'CedarWakePolicy.delay' in read('lib/core/mcp/cedar_live_share_policy.dart')
assert 'localNow.hour < 7' not in read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
assert 'wake.promptSection(instant)' in read('lib/core/ai/prompt_builder.dart')
assert 'DailyWakeSchedule.settlingDuration.inMinutes' in read('lib/core/desire/desire_core_policy.dart')
assert "'dailyWake': wake.toJson(now)" in read('lib/core/diagnostics/preflight_diagnostics.dart')
assert 'test/daily_wake_v04275_test.dart' in (r.parent / '.github/workflows/stability-checks.yml').read_text()
print('v04275 shared atomic wake, fatigue, prompt and autonomous boundaries: OK')
