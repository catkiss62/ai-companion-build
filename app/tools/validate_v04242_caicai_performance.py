#!/usr/bin/env python3
"""Protect final composite transform, resize synchronization and pat ownership wiring.
Geometry and animation behavior are exercised by Java/Dart tests, not these checks.
"""
from pathlib import Path
app=Path(__file__).resolve().parents[1]
base=app/'android/app/src/main/java/com/catkiss/senlive2dcompanion'
model=(base/'SenLive2DModel.java').read_text()
renderer=(base/'SenRenderer.java').read_text()
host=(app/'android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt').read_text()
assert 'getRenderer().setRenderTargetSize(width,height)' in model
assert 'model.resizeRenderTarget(width,height)' in renderer
assert 'overlayModel.resizeRenderTarget(width,height)' in renderer
assert 'resizeCaicaiTargets(width,height); // AI_COMPANION_HOST_PLAN_HOOK' in renderer
assert 'model.setRootDrawTransform(matrix)' in renderer and 'overlayModel.setRootDrawTransform(matrix)' in renderer
assert model.count('applyRootDrawTransform(); // AI_COMPANION_HOST_PLAN_HOOK')==1
assert 'caicaiRoot.inverse' in renderer
assert 'System.nanoTime() >= patDeadlineNanos' in model
assert 'companion.startCaicaiPat' in host and 'trackHeadStroke' in host
assert "'stageTouch'" in (app/'lib/widgets/caicai_live2d_stage.dart').read_text()
assert 'root' in (app/'lib/core/ai/caicai_motion_planner.dart').read_text()
assert (app/'test/caicai_stage_viewport_test.dart').is_file()
print('Caicai resize, final composite transform, inverse hit and pat ownership wired')
