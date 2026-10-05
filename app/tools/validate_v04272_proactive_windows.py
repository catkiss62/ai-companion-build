from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
budget = read('lib/core/desire/proactive_delivery_budget.dart')
engine = read('lib/core/desire/proactive_engine.dart')
db = read('lib/core/database/app_database.dart')
frequency = read('lib/core/models/proactive_frequency.dart')
night = read('lib/core/desire/proactive_dawn_gate_policy.dart')
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320'))
for token in ('quiet => 10', 'natural => 18', 'frequent => 24', 'nightLimit = 2',
              'now.hour < 14', 'now.hour < 19'):
    assert token in frequency, token
assert 'maxIdleBoost = 0.0' in night and 'suppressLongIdleRelief: true' in night
assert 'ProactiveDeliveryBudget.read' in engine and 'budget.blockReason' in engine
assert 'nightContactContract' in engine and '$nightContactContract' in engine
assert 'enforceProactiveBudget: !forceForDebug' in engine
commit = db.split('Future<String?> commitProactiveMessageIfCurrent', 1)[1].split('Future<ChatMessage?> messageById', 1)[0]
assert commit.index('ProactiveDeliveryBudget.read(txn, sentAt)') < commit.index("await txn.insert(\n        'messages',")
assert "txn.insert('proactive_history'" in commit and "'decision': 'sent'" in commit
assert 'proactive_window_changed' in commit and 'budget.blockReason' in commit
assert "'proactiveContact': proactiveBudget.toJson()" in db
assert "decision = 'sent'" in budget and "NOT GLOB 'game_share:immediate:*'" in budget
assert 'quotaIsTarget' in budget
assert 'test/proactive_windows_v04272_test.dart' in (r.parent / '.github/workflows/stability-checks.yml').read_text()
print('v04272 cumulative local windows, night motivation, atomic shared history and final eligibility: OK')
