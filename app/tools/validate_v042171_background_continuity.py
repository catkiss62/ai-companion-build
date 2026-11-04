"""Production ownership wiring; timed behavior is covered by actual Service tests."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
native = app / 'android/app/src/main/kotlin/com/aicompanion/localfirst'
service = (native / 'OverlayBubbleService.kt').read_text()
assert 'mainHandler.postDelayed(timeout, 6_000L)' in service
assert 'request != brainWakeRequest' in service
assert 'backgroundCommands !== channel || backgroundEngine !== ownedEngine' in service
assert 'brainWakeInFlight || brainWakeRetryScheduled' in service
assert 'backgroundWakeRestarts < 2' in service
assert 'restartBackgroundEngineIfUnready(engine, "wake_timeout")' in service
assert 'OverlayPermissionProbe.Result.CONFIRMED' in service
assert 'permissionProbe.delayUntilNext' in service
assert service.count('destroyReason = "overlay_permission_lost"') == 1
access = (native / 'AccessibilityBridgeService.kt').read_text()
assert access.index('eventLoadShedder.shouldProbeRoot') < access.index('rootInActiveWindow')
assert access.index('eventLoadShedder.shouldProbeWindows') < access.index('refreshForegroundWindowTracker(sourcePackage)')
assert 'noteAccessibilityQueries' in access and 'root?.recycle()' in access
assert 'deferWindowProbe(sourcePackage)' in access and 'if (windowProbePending) return' in access
assert 'windowProbeHandler.removeCallbacks(deferredWindowProbe)' in access
assert 'activeService !== this@AccessibilityBridgeService' in access
diagnostics = (app / 'lib/core/diagnostics/preflight_diagnostics.dart').read_text()
for key in ('rootProbeProcessCount', 'windowProbeProcessCount', 'queryCoalescedProcessCount', 'queryMaxDurationMs'):
    assert key in diagnostics, key
workflow = (app.parent / '.github/workflows/build-apk.yml').read_text()
assert "--tests 'com.aicompanion.localfirst.Overlay*Test'" in workflow
assert "--tests 'com.aicompanion.localfirst.AccessibilityEventLoadShedderTest'" in workflow
assert 'wakeBackground' in (app / 'lib/core/platform/background_chat_command_server.dart').read_text()
print('v042171 bounded wake recovery, permission confirmation and pre-query load shedding wired')
