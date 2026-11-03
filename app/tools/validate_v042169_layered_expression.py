"""Ownership wiring. Behavioral tests cover overlap, release and audio independently."""
from pathlib import Path
app=Path(__file__).resolve().parents[1]
java=app/'android/app/src/main/java/com/catkiss/senlive2dcompanion'
model=(java/'DeepseekAvatarModel.java').read_text()
assert model.count('physics.evaluate(model,delta)')==1
assert model.count('if(speaking) ownMouth();')==3
assert model.index('physics.evaluate')<model.rindex('if(speaking) ownMouth();')
assert 'DeepseekSpeechMouth.apply(amplitude,pose)' in model
assert 'model.getParameterDefaultValue(i));}\n        set("ParamMouthOpenY",amplitude)' not in model
for token in ('posture.apply(delta,pose)', 'posture.clear()', 'expressions.accessory(pose)',
              'expressions.reservedEyeMask() | plan.reservedEyeMask()', 'optJSONArray("effects")'):
    assert token in model,token
expression=(java/'DeepseekExpressions.java').read_text()
assert 'selected_effects=' in expression and 'effective_effects=' in expression
assert 'if(!special && !wink.isEmpty())' not in expression
assert 'effects.remove("兔牙")' in expression
assert 'getSharedPreferences' not in expression
planner=(app/'lib/core/ai/deepseek_motion_planner.dart').read_text()
assert planner.count('gateway.chooseMany(')==1
assert "'effects':selectedEffects" in planner
assert "'lean_at':leanStart*interval" in planner
assert "return 'lean';" not in planner
controller=(app/'lib/core/ai/deepseek_chat_motion.dart').read_text()
assert "'lean': animate && cue['lean'] == true" in controller
assert "if(cue['effects'] is List) 'effects': cue['effects']" in controller
for file in ('DeepseekPosture.java','DeepseekSpeechMouth.java'):
    text=(java/file).read_text()
    assert 'http' not in text and 'SharedPreferences' not in text
for workflow in ('build-apk.yml','system-logic-validation.yml'):
    assert 'deepseek_layered_v042169_test.dart' in (app.parent/'.github/workflows'/workflow).read_text()
print('v042169 composable expressions, independent posture, PCM opening and transient accessories wired')
