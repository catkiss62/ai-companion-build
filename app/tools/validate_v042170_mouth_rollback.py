"""Verify PCM centering is wired on both sides of physics and in static mode."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
java = app / 'android/app/src/main/java/com/catkiss/senlive2dcompanion'
model = (java / 'DeepseekAvatarModel.java').read_text()
mouth = (java / 'DeepseekSpeechMouth.java').read_text()
owner = model.split('private void ownMouth()', 1)[1].split('void update(', 1)[0]
assert 'model.getParameterDefaultValue(mouthX)' in owner
assert 'speechMouth.applyFrame(amplitude,pose,neutralX)' in owner
assert model.count('if(speaking) ownMouth();') == 3
static = model.split('if(staticMode)', 1)[1].split('model.loadParameters()', 1)[0]
assert 'applyBase();if(speaking) ownMouth();' in static
assert model.index('speechMouth.capture(pose)') < model.index('physics.evaluate')
assert model.index('physics.evaluate') < model.index('speechMouth.restore(pose)') < model.rindex('if(speaking) ownMouth();')
shapes = mouth.split('SHAPES=', 1)[1].split(';', 1)[0]
assert '"MouthX"' not in shapes
assert 'pose.write("MouthX",Float.isFinite(neutralX)?neutralX:0)' in mouth
assert 'amplitude*1.2f' in mouth
for workflow in ('build-apk.yml',):
    assert "--tests 'com.catkiss.senlive2dcompanion.Deepseek*Test'" in (app.parent / '.github/workflows' / workflow).read_text()
print('v042170 rig-default mouth centering: static mode, pre/post physics and expressive shape ownership wired')
