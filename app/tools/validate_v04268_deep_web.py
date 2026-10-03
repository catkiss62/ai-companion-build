from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
assert '\nversion: 0.42.68+312\n' in read('pubspec.yaml')
w = (r.parent / '.github/workflows/build-apk.yml').read_text()
assert "grep -Fqx 'version: 0.42.68+312' app/pubspec.yaml" in w
assert 'agent/v04268-deep-web' in w
assert 'onOpen: _ensureDeepWebColumns' in read('lib/core/database/app_database.dart')
assert 'deepThinking: turnDeepThinking' in read('lib/features/chat/chat_controller.dart')
assert 'webCancellationToken: effectiveCancellation' in read('lib/core/ai/durable_generation_runner.dart')
assert 'PublicWebReadService(db).refreshIds' in read('lib/core/ai/prompt_builder.dart')
assert 'WebPageEvidence.render(body: item.pageBody' in read('lib/core/ai/prompt_builder.dart')
assert "'provider_truncated'" in read('lib/core/autonomy/web_page_evidence.dart')
assert 'deep_web_v04268_test.dart' in (r.parent / '.github/workflows/stability-checks.yml').read_text()
print('v04268: mode snapshots, shared reading boundary, source evidence, cancellation and build version wired')
