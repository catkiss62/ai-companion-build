from pathlib import Path
r=Path(__file__).resolve().parents[1]
read=lambda p:(r/p).read_text()
state=read('lib/core/personality/playful_form_state.dart')
runner=read('lib/core/ai/durable_generation_runner.dart')
db=read('lib/core/database/app_database.dart')
assert 'stimulusStreak >= 1' in state
assert 'PlayfulInteraction.strong' in state
assert 'if (!pendingTurn ||' in state
assert 'settleInTransaction(txn' in db and 'undoReplyInTransaction(txn' in db
assert 'PlayfulFormStore(db).onAssistantTurn' not in runner
assert 'assistantText: assistant.promptContent' in runner
assert 'latestUserText: user.promptContent' in runner
assert 'webSearchRequested: contextualWebSearch' in runner
assert 'PlayfulBreakthroughJudge(client).decide' not in runner
assert "data['locked'] = value" in state
assert 'resolvePlayfulGroup' in read('lib/core/ai/jev_decision_gateway.dart')
assert 'This level still cools the heat meter' not in read('lib/core/ai/nsfw_context_router.dart')
assert (r/'test/playful_integrity_v04265_test.dart').is_file()
print('v04265 grouped judgments, committed heat and contextual queries wired')
