#!/usr/bin/env python3
"""Owner wiring checks; numerical behavior lives in CaicaiInteractionTest."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
b=root/'android/app/src/main/java/com/catkiss/senlive2dcompanion'
m=(b/'SenLive2DModel.java').read_text();r=(b/'SenRenderer.java').read_text()
assert m.index('updateScheduler.onLateUpdate(model, frameDelta);',m.index('void update(float')) < m.index('finishCaicaiHead();',m.index('void update(float')) < m.index('applyCompositeTestMotion(frameDelta);',m.index('void update(float'))
assert 'headIntent.record' in m and 'headIntent.finish(caicaiTarget())' in m
assert 'caicaiRoot.matrix(),caicaiCamera.crop' in r
assert '(1-sy*2-crop[13])/crop[5]' in r
assert 'cropCaicaiScene(target,destination)' not in r # calibration remains in full-scene coordinates
stage=(root/'lib/widgets/caicai_live2d_stage.dart').read_text()
assert "'setEmotion'" not in stage and "'setSceneSize'" in stage
motion=(root/'lib/core/ai/caicai_chat_motion.dart').read_text()
assert motion.count("'event':id")==2
assert motion.index("'setEmotion'") < motion.index("'caicai_jev_motion'")
host=(root/'android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt').read_text()
assert 'patCandidate && !patTriggered' in host and 'Math.random()<.10' in host
assert 'exportLive2DDiagnostics' in host
ui=(root/'lib/features/chat/live2d_settings_page.dart').read_text()
assert "name == '1白袜' ? '丝袜'" in ui
assert "'head_x_sweep'" in ui and "'head_y_sweep'" in ui
assert '16_666_667L' in (b/'CaicaiCompanionView.java').read_text()
assert 'HIGH_PRECISION_MASK_SIZE = 512' in (b/'SenRenderOptions.java').read_text()
print('Caicai full-scene crop, post-physics head ownership, event leases, held pat, diagnostics and 60/512 wired')
