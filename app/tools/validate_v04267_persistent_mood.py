from pathlib import Path

r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert '\nversion: 0.42.67+311\n' in read('pubspec.yaml')
workflow = (r.parent / '.github/workflows/build-apk.yml').read_text()
assert "grep -Fqx 'version: 0.42.67+311' app/pubspec.yaml" in workflow
store = read('lib/core/mood/mood_store.dart')
assert 'DatabaseExecutor' in store and 'events.take(96)' in store
db = read('lib/core/database/app_database.dart')
assert 'MoodStore.commitTurn(txn' in db
assert 'MoodStore.removeTurn(txn, replyId: assistantMessageId)' in db
assert 'MoodStore.removeTurn(txn, userId: userMessageId)' in db
router = read('lib/core/ai/nsfw_context_router.dart')
assert '...MoodAppraisal.questions' in router
assert router.count('jevGateway.chooseMany(') == 1
assert router.count('client.streamChat(') == 1
gateway = read('lib/core/ai/jev_decision_gateway.dart')
assert 'optional_missing' in gateway and 'optional_invalid_probability' in gateway
service = read('lib/core/mood/mood_service.dart')
assert 'WeatherContext.maxAge' in service
assert 'WeatherContext.refresh' not in service
assert 'http.' not in service
assert 'persistentMood' in read('lib/core/diagnostics/preflight_diagnostics.dart')
assert (r / 'test/persistent_mood_v04267_test.dart').is_file()
print('v04267 mood module, existing batch, commit lifecycle and cached weather boundaries wired')
