"""Notebook target IDs, fair pending reads and dispatch dependency wiring."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
read=lambda p:(root/p).read_text()
store=read('lib/core/mcp/cedar_game_arrangements.dart')
activity=read('lib/core/mcp/cedar_toy_activity.dart')
engine=read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
extract=read('lib/core/ai/memory_extractor.dart')
assert 'referencePrompt' in store and 'referencePrompt' in extract
assert "target.isNotEmpty||same.length==1" in store
assert "items.where((m)=>m.persistent)" in store
assert "pending[(start+n)%pending.length]" in store
assert 'planningRevisionKey' in store
assert store.count('_advancePlanningRevision(txn)') == 3
assert 'planningFence: arrangements.fence' in engine
assert "arrangements.fence==null" in engine
admit=activity.split('Future<bool> admitRemoteDispatch(')[1].split('Future<void> resolveRemoteDispatch(')[0]
assert admit.index('planningFence.matches(txn)') < admit.index('isReadOnlyCall') < admit.index("txn.insert('settings'")
assert 'executionFenceSettingKey' in admit
assert any(f'version: {v}' in read('pubspec.yaml') for v in ('0.42.112+356','0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362', '0.42.119+363', '0.42.120+364', '0.42.121+365', '0.42.122+366', '0.42.123+367'))
print('notebook target IDs, independent pending rotation and atomic dispatch fence wired')
