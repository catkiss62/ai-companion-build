"""Source wiring for existing-request, source-bound game arrangement memory."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
read=lambda p:(root/p).read_text()
store=read('lib/core/mcp/cedar_game_arrangements.dart')
extract=read('lib/core/ai/memory_extractor.dart')
activity=read('lib/core/mcp/cedar_toy_activity.dart')
planner=read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
for token in ('QualifiedConversationSource.fromJson', 'fence.matches(txn)', 'MemoryRevisionSnapshot.capture(item).matches(current)',
              'formed_at','scope.matchesSession','origin_sources','transaction:txn','verified_game_result'):
    assert token in store,token
assert "result['_local_game_arrangements_v1'] = gameArrangements?.toJson()" in extract
assert 'CedarGameArrangementStore.instruction' in extract
assert 'applyExtraction' in extract
assert 'arrangement_save_epochs' in activity
assert 'arrangementStore.captureReview(session)' in planner
assert 'await arrangementStore.completeReviewed(arrangements, decision.arrangementReviews)' in planner
assert '_parseArrangementReviews(call.arguments)' in planner
assert "..remove('arrangement_reviews_json')" in planner
assert '<DeepSeekToolCall>[executableCall]' in planner
assert "usageLane: 'cedar_background_plan'" in planner
assert 'cedar_game_arrangements_v042110_test.dart' in (root.parent/'.github/workflows/system-logic-validation.yml').read_text()
assert 'game_arrangement' not in read('lib/core/database/app_database.dart') # generic source isolation, no game-specific table
assert 'isolateSourceIdentity:true' in store
assert 'source_bound_identity_v1' in read('lib/core/database/app_database.dart')
assert "'lifecycle_source':'game_arrangement_source_v1'" in store
print('game arrangements: original sources, captured game/save, late real result and existing-request wiring passed')
