from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338', '0.42.95+339', '0.42.96+340', '0.42.97+341', '0.42.98+342', '0.42.99+343', '0.42.100+344', '0.42.101+345', '0.42.102+346', '0.42.103+347', '0.42.104+348', '0.42.105+349', '0.42.106+350', '0.42.107+351', '0.42.108+352', '0.42.109+353', '0.42.110+354', '0.42.111+355', '0.42.112+356', '0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362', '0.42.119+363', '0.42.120+364', '0.42.121+365', '0.42.122+366', '0.42.123+367', '0.42.124+368', '0.42.125+369', '0.42.126+370', '0.42.127+371', '0.42.128+372', '0.42.129+373', '0.42.130+374', '0.42.131+375', '0.42.132+376', '0.42.133+377'))
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
