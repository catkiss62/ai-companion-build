from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ('0.42.68+312', '0.42.69+313', '0.42.70+314', '0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338'))
w = (r.parent / '.github/workflows/build-apk.yml').read_text()
assert any(f"grep -Fqx 'version: {v}' app/pubspec.yaml" in w for v in ("0.42.68+312", "0.42.69+313", "0.42.70+314", "0.42.71+315", "0.42.72+316", "0.42.73+317", "0.42.74+318", "0.42.75+319", "0.42.76+320", "0.42.77+321", "0.42.78+322", "0.42.79+323", "0.42.80+324", "0.42.81+325", "0.42.82+326", "0.42.83+327", "0.42.84+328", "0.42.85+329", "0.42.86+330", "0.42.87+331", "0.42.88+332", "0.42.89+333", "0.42.90+334", "0.42.91+335", "0.42.92+336", "0.42.93+337", "0.42.94+338"))
assert 'agent/v04268-deep-web' in w
assert 'onOpen: _ensureDeepWebColumns' in read('lib/core/database/app_database.dart')
assert 'deepThinking: turnDeepThinking' in read('lib/features/chat/chat_controller.dart')
assert 'webCancellationToken: effectiveCancellation' in read('lib/core/ai/durable_generation_runner.dart')
assert 'PublicWebReadService(db).refreshIds' in read('lib/core/ai/prompt_builder.dart')
assert 'WebPageEvidence.render(body: item.pageBody' in read('lib/core/ai/prompt_builder.dart')
assert "'provider_truncated'" in read('lib/core/autonomy/web_page_evidence.dart')
assert 'deep_web_v04268_test.dart' in (r.parent / '.github/workflows/stability-checks.yml').read_text()
print('v04268: mode snapshots, shared reading boundary, source evidence, cancellation and build version wired')
