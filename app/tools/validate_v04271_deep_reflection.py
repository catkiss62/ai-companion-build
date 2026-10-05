from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321'))
engine = read('lib/core/reflection/deep_reflection_engine.dart')
store = read('lib/core/reflection/deep_reflection_store.dart')
runner = read('lib/core/ai/durable_generation_runner.dart')
db = read('lib/core/database/app_database.dart')
assert engine.count('.jsonCompletion(') == 1
assert 'DeepReflectionEngine' not in runner
assert 'DeepReflectionStore.commit(txn' in db
assert 'DeepReflectionStore.undo(txn' in db
assert 'reflectionUpdate: DeepReflectionUpdate.parse(generated.content)' in runner
assert 'DeepReflectionUpdate.visible(raw)' in read('lib/core/emotion/emotion_contract.dart')
assert 'EmotionEnvelope.streamingVisible(content)' in runner
assert "topic['phase'] = 'paused'" in store
assert 'source_quote' in engine and 'fingerprint' in engine
assert 'reviewGap' in engine and 'generationGap' in engine and 'invitationGap' in store
assert 'captureBrainWorkFence' in engine and 'expectedSettings' in engine
assert 'DeepReflectionEngine(db).maybePrepare()' in read('lib/core/desire/proactive_engine.dart')
for path in ['lib/core/sync/snapshot_service.dart', 'lib/features/transfer/transfer_page.dart', 'lib/core/diagnostics/preflight_diagnostics.dart']:
    assert 'deep_reflection_prepare_lease_until' in read(path)
assert 'Icons.lightbulb_outline' in read('lib/widgets/thinking_icon.dart')
assert 'Color(0xFFB388FF)' in read('lib/widgets/thinking_icon.dart')
w = (r.parent / '.github/workflows/stability-checks.yml').read_text()
assert 'test/deep_reflection_test.dart' in w and 'test/deep_reflection_pipeline_test.dart' in w
print('v04271 bounded reflection, single final writer, atomic state, hidden sidecar and lightbulb: OK')
