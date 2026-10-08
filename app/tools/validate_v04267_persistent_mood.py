from pathlib import Path

r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.67+311', '0.42.68+312', '0.42.69+313', '0.42.70+314', '0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332'))
workflow = (r.parent / '.github/workflows/build-apk.yml').read_text()
assert any(f"grep -Fqx 'version: {v}' app/pubspec.yaml" in workflow for v in ('0.42.67+311', '0.42.68+312', '0.42.69+313', '0.42.70+314', '0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332'))
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
