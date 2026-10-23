from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.70+314', '0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338', '0.42.95+339', '0.42.96+340', '0.42.97+341', '0.42.98+342', '0.42.99+343', '0.42.100+344', '0.42.101+345', '0.42.102+346', '0.42.103+347', '0.42.104+348', '0.42.105+349', '0.42.106+350', '0.42.107+351', '0.42.108+352', '0.42.109+353', '0.42.110+354', '0.42.111+355', '0.42.112+356', '0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362', '0.42.119+363', '0.42.120+364', '0.42.121+365', '0.42.122+366', '0.42.123+367', '0.42.124+368', '0.42.125+369', '0.42.126+370', '0.42.127+371', '0.42.128+372', '0.42.129+373'))
engine=read('lib/core/wishes/wish_engine.dart')
store=read('lib/core/wishes/wish_store.dart')
repo=read('lib/core/phone/simulated_phone_repository.dart')
assert 'wishTextForThought' not in repo
assert 'lastSatisfiedAt' not in repo
for token in ['WishPolicy.apply', 'generationGap', 'reviewGap', 'game_result', 'user_photo',
              'same_target', 'observed', 'e.text.contains(quote)', 'captureBrainWorkFence', 'baseline']:
    assert token in engine or token in store, token
assert 'setSettingsAtomically' in store and 'expectedSettings' in store
assert 'WishEngine(db).maybeRefresh()' in read('lib/core/desire/proactive_engine.dart')
assert 'WishStore(db).prompt(gameId: session.gameId' in read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
assert 'wishContext.isNotEmpty' in read('lib/core/ai/prompt_builder.dart')
assert "Tab(text: '暂时放下')" in read('lib/features/phone/simulated_phone_page.dart')
assert 'companion_wish_review_lease_until' in read('lib/core/sync/snapshot_service.dart')
assert 'companion_wish_lifecycle_test.dart' in (r.parent/'.github/workflows/stability-checks.yml').read_text()
print('v04270 wish generation, evidence, routing, pause, restore and behavioral tests wired')
