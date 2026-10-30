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
# Switching avatar is a real resource identity change; same-profile restore stays hot.
switch_guard = 'if (profile != Live2DProfiles.selected(app)) { dispose(); return }'
assert switch_guard in refresh
refresh = refresh.replace(switch_guard, '')
for forbidden in ('dispose()', 'loadModels(', 'loadCurrentModel(', 'onHostPause(', 'onHostResume('):
    assert forbidden not in refresh, forbidden
assert 'fun refreshPreferences() = active.get()?.refreshPreferences()' in host
prefs = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiStagePreferences.kt')
for key in ('motionGain', 'motionSpeed', 'legPivot', 'scale', 'x', 'y', 'headLeft', 'headTop', 'headRight', 'headBottom'):
    assert f'getFloat("{key}"' in prefs
assert 'tuneCaicaiMotion' in prefs and 'setStageTransform' in prefs
assert 'edit()' not in prefs and 'loadModels' not in prefs
assert re.search(r'^version: 0.42.(?:60\+304|61\+305|62\+306|63\+307|64\+308|65\+309|66\+310|67\+311|68\+312|69\+313|70\+314|71\+315|72\+316|73\+317|74\+318|75\+319|76\+320|77\+321|78\+322|79\+323|80\+324|81\+325|82\+326|83\+327|84\+328|85\+329|86\+330|87\+331|88\+332|89\+333|90\+334|91\+335|92\+336|93\+337|94\+338|95\+339|96\+340|97\+341|98\+342|99\+343|100\+344|101\+345|102\+346|103\+347|104\+348|105\+349|106\+350|107\+351|108\+352|109\+353|110\+354|111\+355|112\+356|113\+357|114\+358|115\+359|116\+360|117\+361|118\+362|119\+363|120\+364|121\+365|122\+366|123\+367|124\+368|125\+369|126\+370|127\+371|128\+372|129\+373|130\+374|131\+375|132\+376|133\+377|134\+378|135\+379|136\+380|137\+381|138\+382|139\+383|140\+384|141\+385|142\+386|143\+387|144\+388|145\+389|146\+390|147\+391|148\+392|149\+393|(?:150\+394|151\+395|152\+396|(?:153\+397|154\+398)))$', read('pubspec.yaml'), re.M)
smoke = read('tools/caicai_smoke/src/androidTest/java/com/catkiss/senlive2dcompanion/smoke/NativeSmokeTest.kt')
for name in ('settingsRestoreHotAppliesToTheSameRendererAndRestoresMissingKeyDefaults',
             'settingsRefreshFailureKeepsErrorAndReleasesSnapshotLease',
             'legacyModelRestoreStillReleasesAndRestoresIndexWithoutHotRefresh'):
    assert name in smoke
print('v0.42.60 settings restore keeps the view, syncs final preferences and retains legacy model reload')
