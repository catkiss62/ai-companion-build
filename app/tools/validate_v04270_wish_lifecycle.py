from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert '\nversion: 0.42.70+314\n' in read('pubspec.yaml')
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
