"""Wiring guard; Dart channel and Android renderer behavior run separately in CI."""
from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
read = lambda path: (app / path).read_text()
storage = read('lib/core/storage/portable_companion_storage.dart')
assert 'if (restoreModels) _reloadAfterFinish.add(snapshot.token);' in storage
native = read('android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt')
assert 'if (restoreModels) releaseModel()' in native
assert 'if (applied && !modelsTouched) refreshPreferences()' in native
assert native.index('if (applied && !modelsTouched) refreshPreferences()') > native.index('if (modelsTouched && commit)')
assert 'failure.addSuppressed(error)' in native
bridge = read('android/app/src/main/kotlin/com/aicompanion/localfirst/CaicaiLive2DBridge.kt')
assert 'refreshPreferences = { CaicaiRuntime.refreshPreferences() }' in bridge
host = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt')
refresh = host.split('fun refreshPreferences() {', 1)[1].split('fun speechAmplitude', 1)[0]
for token in ('if (disposed) return', 'CaicaiStagePreferences.read(viewPrefs)',
              'headBox = restored.headBox()', 'restored.applyTo(companion, previous)', 'editSnapshot = floatArrayOf'):
    assert token in refresh, token
for forbidden in ('dispose()', 'loadModels(', 'loadCurrentModel(', 'onHostPause(', 'onHostResume('):
    assert forbidden not in refresh, forbidden
assert 'fun refreshPreferences() = active.get()?.refreshPreferences()' in host
prefs = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiStagePreferences.kt')
for key in ('motionGain', 'motionSpeed', 'legPivot', 'scale', 'x', 'y', 'headLeft', 'headTop', 'headRight', 'headBottom'):
    assert f'getFloat("{key}"' in prefs
assert 'tuneCaicaiMotion' in prefs and 'setStageTransform' in prefs
assert 'edit()' not in prefs and 'loadModels' not in prefs
assert re.search(r'^version: 0.42.(?:60\+304|61\+305|62\+306|63\+307|64\+308|65\+309|66\+310|67\+311|68\+312)$', read('pubspec.yaml'), re.M)
smoke = read('tools/caicai_smoke/src/androidTest/java/com/catkiss/senlive2dcompanion/smoke/NativeSmokeTest.kt')
for name in ('settingsRestoreHotAppliesToTheSameRendererAndRestoresMissingKeyDefaults',
             'settingsRefreshFailureKeepsErrorAndReleasesSnapshotLease',
             'legacyModelRestoreStillReleasesAndRestoresIndexWithoutHotRefresh'):
    assert name in smoke
print('v0.42.60 settings restore keeps the view, syncs final preferences and retains legacy model reload')
