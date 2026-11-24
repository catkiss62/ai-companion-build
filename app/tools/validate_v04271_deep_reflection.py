from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338', '0.42.95+339', '0.42.96+340', '0.42.97+341', '0.42.98+342', '0.42.99+343', '0.42.100+344', '0.42.101+345', '0.42.102+346', '0.42.103+347', '0.42.104+348', '0.42.105+349', '0.42.106+350', '0.42.107+351', '0.42.108+352', '0.42.109+353', '0.42.110+354', '0.42.111+355', '0.42.112+356', '0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362', '0.42.119+363', '0.42.120+364', '0.42.121+365', '0.42.122+366', '0.42.123+367', '0.42.124+368', '0.42.125+369', '0.42.126+370', '0.42.127+371', '0.42.128+372', '0.42.129+373', '0.42.130+374', '0.42.131+375', '0.42.132+376', '0.42.133+377', '0.42.134+378', '0.42.135+379', '0.42.136+380', '0.42.137+381', '0.42.138+382', '0.42.139+383', '0.42.140+384', '0.42.141+385', '0.42.142+386', '0.42.143+387', '0.42.144+388', '0.42.145+389', '0.42.146+390', '0.42.147+391', '0.42.148+392', '0.42.149+393', '0.42.150+394', '0.42.151+395', '0.42.152+396', '0.42.153+397', '0.42.154+398', '0.42.155+399', '0.42.156+400', '0.42.157+401', '0.42.158+402', '0.42.159+403', '0.42.160+404', '0.42.161+405', '0.42.162+406', '0.42.163+407', '0.42.164+408', '0.42.165+409', '0.42.166+410', '0.42.167+411', '0.42.168+412', '0.42.169+413', '0.42.170+414', '0.42.171+415', '0.42.172+416', '0.42.173+417', '0.42.174+418', '0.42.175+419', '0.42.176+420', '0.42.177+421', '0.42.178+422', '0.42.179+423', '0.42.180+424', '0.42.181+425', '0.42.182+426', '0.42.183+427', '0.42.184+428', '0.42.185+429', '0.42.186+430', '0.42.187+431', '0.42.188+432', '0.42.189+433', '0.42.190+434', '0.42.191+435', '0.42.192+436', '0.42.193+437', '0.42.194+438', '0.42.195+439', '0.42.196+440', '0.42.197+441', '0.42.198+442', '0.42.199+443', '0.42.200+444', '0.42.201+445', '0.42.202+446', '0.42.203+447', '0.42.204+448', '0.42.205+449', '0.42.206+450', '0.42.207+451', '0.42.208+452', '0.42.209+453', '0.42.210+454', '0.42.211+455', '0.42.212+456', '0.42.213+457', '0.42.214+458', '0.42.215+459', '0.42.216+460', '0.42.217+461', '0.42.218+462', '0.42.219+463', '0.42.220+464', '0.42.221+465', '0.42.222+466', '0.42.223+467', '0.42.224+468', '0.42.225+469', '0.42.226+470', '0.42.227+471', '0.42.228+472', '0.42.229+473', '0.42.230+474', '0.42.231+475', '0.42.232+476', '0.42.233+477'))
engine = read('lib/core/reflection/deep_reflection_engine.dart')
store = read('lib/core/reflection/deep_reflection_store.dart')
runner = read('lib/core/ai/durable_generation_runner.dart')
db = read('lib/core/database/app_database.dart')
assert engine.count('.jsonCompletion(') == 1
assert 'DeepReflectionEngine' not in runner
assert 'DeepReflectionStore.commit(txn' in db
assert 'DeepReflectionStore.undo(txn' in db
assert 'reflectionUpdate: DeepReflectionUpdate.parse(generated.content)' in runner
envelope = read('lib/core/emotion/emotion_contract.dart')
assert (
    'DeepReflectionUpdate.visible(raw)' in envelope
    or 'DeepReflectionUpdate.visible(IllustrationCue.visible(raw))' in envelope
)
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
