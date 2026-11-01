"""Production wiring gate; behavioral coverage lives in JVM/Flutter tests."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
model = read('android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekAvatarModel.java')
assert model.count('physics.evaluate(model,delta)') == 1
assert model.count('if(speaking) ownMouth();') == 2
assert model.index('physics.evaluate(model,delta)') < model.rindex('if(speaking) ownMouth();')
for token in ('DeepseekExpressions', 'DeepseekGestures', 'DeepseekParameterPlan', 'speechDeadline',
              'loadPerformanceClips', 'MouthPressLipOpen', 'model.getParameterMinimumValue'):
    assert token in model, token
assert '脱捕.motion3.json' not in model  # Stage 3 random idle is still deferred.
native = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt')
for token in ('claimDeepseekMotion', 'deepseekMotionPlan', 'deepseekSpeechCue', 'previewDeepseekPerformance',
              'scoped["asset"]!=loadIdentity', 'scoped["catalog"]!="deepseek-v2"',
              'deepseekSpeechSequence==seq', 'PlaybackSessionRegistry.current(lease)'):
    assert token in native, token
planner = read('lib/core/ai/deepseek_motion_planner.dart')
assert planner.count('gateway.chooseMany(') == 1
assert "usageLane: 'deepseek_avatar_speaking_motion'" in planner
for unsupported in ('ParamAngleX3', '2比耶', '2奶茶', 'ParamMouthOpenY'):
    assert unsupported not in planner, unsupported
controller = read('lib/core/ai/deepseek_chat_motion.dart')
for token in ('claimDeepseekMotion', 'deepseekSpeechCue', 'getDeepseekJev',
              "state['spoken_fingerprint'] == _fingerprint", 'revision.value', "state['audible'] == true"):
    assert token in controller, token
assert 'DeepseekMotionPlanner.speechFrames' in controller
assert 'Live2dChatMotion()' in read('lib/features/chat/chat_page.dart')
assert 'deepseek_motion' in read('android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt')
workflow = (app.parent / '.github/workflows/build-apk.yml').read_text()
assert "--tests 'com.catkiss.senlive2dcompanion.Deepseek*Test'" in workflow
assert 'deepseek_presentation_owner_v042157_test.dart' in workflow
print('DeepSeek stage 2 isolated planner, authored gestures, PCM ownership and generation guards wired')
