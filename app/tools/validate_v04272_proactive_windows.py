from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
budget = read('lib/core/desire/proactive_delivery_budget.dart')
engine = read('lib/core/desire/proactive_engine.dart')
db = read('lib/core/database/app_database.dart')
frequency = read('lib/core/models/proactive_frequency.dart')
night = read('lib/core/desire/proactive_dawn_gate_policy.dart')
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338', '0.42.95+339', '0.42.96+340', '0.42.97+341', '0.42.98+342', '0.42.99+343', '0.42.100+344', '0.42.101+345', '0.42.102+346', '0.42.103+347', '0.42.104+348', '0.42.105+349', '0.42.106+350', '0.42.107+351', '0.42.108+352', '0.42.109+353', '0.42.110+354', '0.42.111+355'))
for token in ('quiet => 10', 'natural => 18', 'frequent => 24', 'nightLimit = 2',
              'now.hour < 14', 'now.hour < 19'):
    assert token in frequency, token
assert 'maxIdleBoost = 0.0' in night and 'suppressLongIdleRelief: true' in night
assert 'ProactiveDeliveryBudget.read' in engine and 'budget.blockReason' in engine
assert 'nightContactContract' in engine and '$nightContactContract' in engine
assert 'enforceProactiveBudget: !forceForDebug' in engine
commit = db.split('Future<String?> commitProactiveMessageIfCurrent', 1)[1].split('Future<ChatMessage?> messageById', 1)[0]
assert commit.index('ProactiveDeliveryBudget.read(txn, sentAt)') < commit.index('await ConversationSourceStore.insertMessage(')
assert 'txn,' in commit.split('await ConversationSourceStore.insertMessage(', 1)[1].split(');', 1)[0]
assert "txn.insert('proactive_history'" in commit and "'decision': 'sent'" in commit
assert 'proactive_window_changed' in commit and 'budget.blockReason' in commit
assert "'proactiveContact': proactiveBudget.toJson()" in db
assert "decision = 'sent'" in budget and "NOT GLOB 'game_share:immediate:*'" in budget
assert 'quotaIsTarget' in budget
assert 'test/proactive_windows_v04272_test.dart' in (r.parent / '.github/workflows/stability-checks.yml').read_text()
print('v04272 cumulative local windows, night motivation, atomic shared history and final eligibility: OK')
