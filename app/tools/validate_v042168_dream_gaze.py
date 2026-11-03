"""Ownership and persistence wiring only; functional evidence is in Dart/JVM tests."""
from pathlib import Path
app = Path(__file__).resolve().parents[1]
read = lambda path: (app / path).read_text()
java = 'android/app/src/main/java/com/catkiss/senlive2dcompanion/'
focus = read(java + 'DeepseekViewerFocus.java')
assert 'ParamEyeBallX' in focus and 'ParamEyeBallY' in focus
assert 'write("Angle' not in focus and 'write("Position' not in focus
model = read(java + 'DeepseekAvatarModel.java')
assert model.index('physics.evaluate') < model.index('viewerFocus.apply') < model.index('leanFocus.apply')
assert 'set("key6",0)' in model and 'expressions.overlay(pose,speaking)' in model
assert 'reservesEyes(speaking)' in model and 'viewerFocus.reset()' in model
engine = read('lib/core/self/dream_engine.dart')
assert 'catchup_read' in engine and 'catchup_integrate' in engine
assert 'paid >= 24' in engine and 'sameFailures >= 3' in engine
assert 'completed: phase !=' in engine and 'expectedSettings: {DreamStore.stateKey: raw}' in engine
assert 'upperCursor' in read('lib/core/self/dream_material.dart')
assert 'before_insights' in engine and 'baseline_insights' in read('lib/core/self/dream_catchup.dart')
assert 'dream_catchup_v042168_test.dart' in (app.parent / '.github/workflows/system-logic-validation.yml').read_text()
print('v042168 eye-only focus, speech mouth and resumable private-draft wiring passed')
