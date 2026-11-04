"""Ownership/budget wiring; paid-effect and cancellation behavior is tested in Flutter/JVM."""
from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
sketch = read('lib/integrations/qq_private/qq_sketch.dart')
for token in ('attempt<=2', 'attempt==2)await _reserve', 'expired || !repairable',
              'deadline.cancel();cancellation.cancel()', 'requestProvider:ChatApiProvider.deepSeek',
              "usageLane:'qq_small_sketch'", 'if(count>=4)', 'requestTimeout=const Duration(seconds:90)',
              "stage='sketch_validation'", "stage:'sketch_render'"):
    assert token in sketch, token
failure = read('lib/integrations/qq_private/qq_failure.dart')
assert 'class QqSketchFailure extends QqOperationFailure' in failure
assert 'error is HttpException' in failure
voice = read('lib/integrations/qq_private/qq_voice.dart')
assert '普通开心或轻微俏皮也适合' in voice and '不要仅因角色活泼' in voice
store = read('lib/integrations/qq_private/qq_store.dart')
assert 'QqVoiceUsage.record(raw,seq:' in store
assert "phase:error is QqSketchFailure?error.stage:phase" in store
runtime = read('lib/integrations/qq_private/qq_runtime.dart')
assert 'onRepair:(failure)=>store.recordFailure' in runtime
assert "voiceProfile:voiceChoice?.voice??''" in runtime
worker = read('lib/core/creative/creative_worker.dart')
branch = worker.split("case 'work_visual_review':",1)[1].split("case 'work_finish':",1)[0]
assert branch.index('CreativeVisualBudget.prior') < branch.index('visualReview.review')
assert branch.index('await checkpoint') < branch.index('visualReview.review')
assert "'status':'unavailable'" in branch and 'if(!await current())throw const BrainWorkInvalidated()' in branch
assert 'CreativePreviewProof.errors' in worker and 'proofErrors.isNotEmpty' in worker
workspace = read('lib/core/creative/creative_workspace.dart')
assert "if (entry.key != 'cover')" in workspace  # No images in every work-model turn.
assert '视觉设计' in workspace and '普通作品无需额外识图' in workspace
review = read('lib/core/creative/creative_visual_review.dart')
assert 'RoutedVisionClient(db:db,current:current)' in review
assert 'Duration(seconds:45)' in review and "verification['hash']!=hash" in review
assert 'bytes.length>180000' in review and "'request_id':requestId" in review
diagnostics = read('lib/core/diagnostics/preflight_diagnostics.dart')
assert 'recentVoiceChoices' in diagnostics and 'QqFailureHistory.safeDetails(item)' in diagnostics
for name in ('build-apk.yml','system-logic-validation.yml'):
    workflow = (app.parent/'.github/workflows'/name).read_text()
    for test in ('qq_media_quality_v042173_test.dart','creative_visual_review_v042173_test.dart'):
        assert test in workflow, test
version = re.search(r'^version: (.+)$',read('pubspec.yaml'),re.M).group(1)
assert f"grep -Fqx 'version: {version}'" in (app.parent/'.github/workflows/build-apk.yml').read_text()
print('v042173 bounded QQ format repair, confirmed voice enums and durable optional visual review wired')
