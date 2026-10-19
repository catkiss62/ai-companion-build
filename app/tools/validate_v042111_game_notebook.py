"""Independent notebook and ordinary Thought source boundary wiring."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
read=lambda p:(root/p).read_text()
store=read('lib/core/mcp/cedar_game_arrangements.dart')
extract=read('lib/core/ai/memory_extractor.dart')
db=read('lib/core/database/app_database.dart')
for token in ('migrateLegacy()', 'deleteNote(String id)', "'state':'deleted'", "'lifetime':'once'",
              'item.persistent', 'current.snapshot!=item.snapshot', 'verified_game_result',
              "'state':'completed'", 'scope.matchesSession', 'origin_sources', 'fence.matches(txn)', 'deletionRevisionKey'):
    assert token in store, token
assert 'actual_progress_before_reply' not in store
assert 'db.insertMemory(' not in store
assert 'gameArrangements?.prompt' not in extract
assert 'db.postTurnThoughtCandidates(limit: 8)' in extract
assert 'source NOT LIKE \'mcp/%\' AND source NOT LIKE \'public_web_candidate:%\'' in db
atomic=db.split('Future<bool> applyPostTurnThoughtEvidenceAtomic(')[1].split('Future<void> addThoughtLifecycleEvent')[0]
assert atomic.count('$postTurnThoughtSourceWhere')==2
for path in ('lib/main.dart', 'lib/background_main.dart'):
    assert '.migrateLegacy()' in read(path)
assert '游戏记事本' in read('lib/features/settings/cedar_toy_settings_page.dart')
workflow=(root.parent/'.github/workflows/system-logic-validation.yml').read_text()
assert 'post_turn_thought_source_v042111_test.dart' in workflow
assert any(f'version: {v}' in read('pubspec.yaml') for v in ('0.42.111+355','0.42.112+356', '0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362'))
print('independent game notebook, archived migration, read/completion separation and ordinary source boundary wired')
