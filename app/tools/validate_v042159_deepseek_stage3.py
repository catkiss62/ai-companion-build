"""Stage 3 wiring plus strict domain boundaries; behavior runs in JVM, Flutter and Android."""
from pathlib import Path
app=Path(__file__).resolve().parents[1]
read=lambda p:(app/p).read_text()
java='android/app/src/main/java/com/catkiss/senlive2dcompanion/'
model=read(java+'DeepseekAvatarModel.java')
for token in ('DeepseekIdleMotion','DeepseekBlink','DeepseekHeadPat','DeepseekHitTransform',
              'idle.applyAttention','pat.apply','idle.grassDue','if(!manualPreview) idle.update',
              'readClip("脱捕",DeepseekGestures.IDLE_CHANNELS)', 'hit=DeepseekHitTransform.INVALID'):
    assert token in model,token
assert model.count('physics.evaluate(model,delta)')==1
assert model.index('pat.apply')<model.index('physics.evaluate(model,delta)')<model.rindex('if(speaking) ownMouth();')
gestures=read(java+'DeepseekGestures.java')
allowed=gestures.split('IDLE_CHANNELS=',1)[1].split(')));',1)[0]
for illegal in ('ParamEye','ParamMouth','key3','key8','Param55','AngleY','Movement2','Clothes'):
    assert illegal not in allowed,illegal
native=read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt')
for token in ('"deepseekHeadPat", "deepseekHeadPatRare"','interactionSequence','interactionCurrent',
              'loadIdentity==asset','profileGeneration==Live2DProfiles.generation','cancelDeepseekInteractions()',
              'companion.releaseDeepseekPat','allowHidden:Boolean=false'):
    assert token in native,token
renderer=read(java+'SenRenderer.java')
assert 'return deepseek.screenToModel(screenX,screenY,result)' in renderer
assert 'deepseek.tune(motionGain,motionSpeed)' in renderer
planner=read('lib/core/ai/deepseek_motion_planner.dart')
assert planner.count('gateway.chooseMany(')==1
assert "'狗尾草':" in planner and "'扶胸':" in planner and "'竖食指':" in planner
for file in ('DeepseekIdleMotion.java','DeepseekBlink.java','DeepseekHeadPat.java'):
    text=read(java+file)
    assert 'http' not in text and 'Clothes' not in text and 'ParamAngleX3' not in text
page=read('lib/features/chat/live2d_settings_page.dart')
assert "if(!_deepseek) ActionChip(label: const Text('调整摸头区域')" not in page
for workflow in ('build-apk.yml','system-logic-validation.yml'):
    assert 'deepseek_stage3_v042159_test.dart' in (app.parent/'.github/workflows'/workflow).read_text()
print('DeepSeek stage 3 local idle, blink, independent pats, transform and lifecycle guards wired')
