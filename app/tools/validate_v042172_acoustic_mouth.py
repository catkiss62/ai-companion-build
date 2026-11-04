"""Playback/ownership wiring; acoustic, release and layering behavior has JVM/Android tests."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
java = app / 'android/app/src/main/java/com/catkiss/senlive2dcompanion'
read = lambda path: (app / path).read_text()
pcm = read('android/app/src/main/kotlin/com/aicompanion/localfirst/CaicaiPcmLipSync.kt')
for token in ('val shape: DeepseekAudioMouth.Shape', 'playbackHeadPosition.toLong()',
              'blocks.first().end <= head', 'head >= it.start && playing',
              'offset + frame * frameBytes, end - frame',
              'CaicaiRuntime.speechAmplitude(block?.value ?: 0f, shape.width, shape.opening)',
              '(rms * 6f).coerceIn(0f, 1f)', 'CaicaiRuntime.speechPlayback(false)',
              'handler.removeCallbacks(tick)', 'if (stopped || !valid()) return'):
    assert token in pcm, token
assert 'deepseek.speechShape(width,opening)' in (java / 'SenRenderer.java').read_text()
renderer = (java / 'SenRenderer.java').read_text()
dispatch = renderer.split('void setSpeechMouth(', 1)[1].split('void playAction(', 1)[0]
assert 'setLipSyncValue(amplitude)' in dispatch and 'if(deepseek!=null)' in dispatch
bridge = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt')
assert 'companion.setSpeechMouth(value, width, opening)' in bridge
assert 'queueRenderer(() -> renderer.setSpeechMouth(amplitude,width,opening))' in (java / 'CaicaiCompanionView.java').read_text()
model = (java / 'DeepseekAvatarModel.java').read_text()
assert model.count('speechMouth.advance(delta,speaking,System.nanoTime())') == 1
assert model.index('speechMouth.advance(') < model.index('for(int i=0;i<frozenParameters.length;i++) model.setParameterValue')
assert model.count('if(speaking) ownMouth();') == 3
assert model.index('speechMouth.capture(pose)') < model.index('physics.evaluate') < model.index('speechMouth.restore(pose)')
assert 'if(!playing) speechMouth.resetSignal()' in model
mouth = (java / 'DeepseekSpeechMouth.java').read_text()
assert 'apply(amplitude,pose,neutralX);' in mouth  # Original centered RMS ownership retained.
assert 'now-signalAt>200_000_000L' in mouth
assert 'if(!playing) {resetSignal();return;}' in mouth
assert 'pose.current("TongueOut")>.1f' in mouth
assert 'pose.write("MouthPressLipOpen"' not in mouth
assert 'pose.write("ParamMouthForm"' not in mouth
analyzer = (java / 'DeepseekAudioMouth.java').read_text()
assert 'LIMIT=512' in analyzer and 'return NEUTRAL' in analyzer
for source in (analyzer, mouth):
    assert 'android.' not in source and 'SharedPreferences' not in source and 'http' not in source
for workflow in ('build-apk.yml',):
    assert "--tests 'com.catkiss.senlive2dcompanion.Deepseek*Test'" in (app.parent / '.github/workflows' / workflow).read_text()
assert 'acousticMouthUsesActualPcm' in read('tools/caicai_smoke/src/androidTest/java/com/catkiss/senlive2dcompanion/DeepseekStage3SmokeTest.java')
print('v042172 read-only PCM shape, actual playback head, isolated model dispatch and bounded release wired')
